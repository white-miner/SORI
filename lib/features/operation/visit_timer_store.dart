import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/sori_repository.dart';
import '../../services/sori_store.dart';
import '../../utils/sori_uuid.dart';
import '../../visit_kernel/models/care_program_template.dart';
import '../../visit_kernel/models/preset_slot_tint.dart';
import '../../visit_kernel/models/visit_operation_timer.dart';
import 'visit_timer_local_cache.dart';

/// PRD v4.5 — 3-button timer engine (total / chart / care tracks).
class VisitTimerStore extends ChangeNotifier {
  VisitTimerStore._();
  static final VisitTimerStore instance = VisitTimerStore._();

  SoriStore? _store;
  SoriRepository? _repository;
  Timer? _tickTimer;

  List<CareProgramTemplate> presets = const [];
  List<PresetSlotTint> slotTints =
      List.generate(5, (i) => PresetSlotTint.defaultForSlot(i));
  VisitOperationTimer? active;
  int selectedPresetSlot = 0;

  void bind(SoriStore store, SoriRepository repository) {
    _store = store;
    _repository = repository;
  }

  String? get _shopId => _store?.shop.id.trim();

  VisitTimerLiveSnapshot? get liveSnapshot =>
      active == null ? null : VisitTimerLiveSnapshot.compute(active!);

  CareProgramTemplate presetAt(int slot) {
    if (slot >= 0 && slot < presets.length && !presets[slot].isEmpty) {
      return presets[slot];
    }
    final sid = _shopId ?? '';
    return CareProgramTemplate.empty(shopId: sid, slotIndex: slot);
  }

  PresetSlotTint tintAt(int slot) {
    final idx = slot.clamp(0, 4);
    if (idx < presets.length && !presets[idx].isEmpty) {
      return presets[idx].slotTint;
    }
    if (idx < slotTints.length) return slotTints[idx];
    return PresetSlotTint.defaultForSlot(idx);
  }

  Future<void> setSlotTint(int slot, PresetSlotTint tint) async {
    final idx = slot.clamp(0, 4);
    while (slotTints.length < 5) {
      slotTints = [...slotTints, PresetSlotTint.defaultForSlot(slotTints.length)];
    }
    slotTints = List<PresetSlotTint>.from(slotTints);
    slotTints[idx] = tint;

    final sid = _shopId;
    if (sid != null && sid.isNotEmpty) {
      await VisitTimerLocalCache.saveSlotTints(sid, slotTints);
    }

    if (idx < presets.length && !presets[idx].isEmpty) {
      await savePreset(presets[idx].copyWith(slotTint: tint));
    } else {
      notifyListeners();
    }
  }

  Future<void> hydrate() async {
    final sid = _shopId;
    if (sid == null || sid.isEmpty) return;

    final cachedPresets = await VisitTimerLocalCache.loadPresets(sid);
    final cachedActive = await VisitTimerLocalCache.loadActiveTimer(sid);
    slotTints = await VisitTimerLocalCache.loadSlotTints(sid);

    try {
      final remote =
          await _repository?.loadCareProgramTemplates(sid) ?? const [];
      presets = _mergePresetSlots(sid, remote, cachedPresets);
    } catch (_) {
      presets = _mergePresetSlots(sid, const [], cachedPresets);
    }

    if (cachedActive != null && cachedActive.status != VisitTimerStatus.done) {
      active = cachedActive;
      _ensureTicking();
      await _advanceStepsIfNeeded();
    } else {
      final session = _store?.activeVisitSession;
      if (session != null) {
        try {
          final remote =
              await _repository?.loadVisitOperationTimer(session.id);
          if (remote != null && remote.status != VisitTimerStatus.done) {
            active = remote;
            _ensureTicking();
          }
        } catch (_) {}
      }
    }

    notifyListeners();
  }

  List<CareProgramTemplate> _mergePresetSlots(
    String shopId,
    List<CareProgramTemplate> remote,
    List<CareProgramTemplate> cached,
  ) {
    final slots = List<CareProgramTemplate>.generate(
      5,
      (i) => CareProgramTemplate.empty(shopId: shopId, slotIndex: i),
    );
    for (final p in [...cached, ...remote]) {
      if (p.slotIndex >= 0 && p.slotIndex < 5 && !p.isEmpty) {
        slots[p.slotIndex] = p;
      }
    }
    return slots;
  }

  Future<void> savePreset(CareProgramTemplate template) async {
    final sid = _shopId;
    if (sid == null || sid.isEmpty || _repository == null) return;
    final steps = template.steps.take(5).toList();
    if (steps.isEmpty) return;

    final saved = await _repository!.upsertCareProgramTemplate(
      template.copyWith(
        id: template.id.isEmpty ? newUuidV4() : template.id,
        shopId: sid,
        steps: steps,
        slotTint: template.slotTint,
        updatedAt: DateTime.now(),
      ),
    );

    final next = List<CareProgramTemplate>.from(presets);
    while (next.length < 5) {
      next.add(CareProgramTemplate.empty(shopId: sid, slotIndex: next.length));
    }
    next[saved.slotIndex] = saved;
    presets = next;

    while (slotTints.length < 5) {
      slotTints = [...slotTints, PresetSlotTint.defaultForSlot(slotTints.length)];
    }
    slotTints = List<PresetSlotTint>.from(slotTints);
    slotTints[saved.slotIndex] = saved.slotTint;

    await VisitTimerLocalCache.savePresets(sid, presets);
    await VisitTimerLocalCache.saveSlotTints(sid, slotTints);
    notifyListeners();
  }

  Future<void> startConsultation({
    required String visitSessionId,
    required String shopId,
  }) async {
    final now = DateTime.now();
    active = VisitOperationTimer(
      id: newUuidV4(),
      visitSessionId: visitSessionId,
      shopId: shopId,
      consultationStartedAt: now,
      chartOpenedAt: now,
      status: VisitTimerStatus.consulting,
      updatedAt: now,
    );
    await _persist(active!);
    await _logEvent('consultation_started', {});
    _ensureTicking();
    notifyListeners();
  }

  Future<void> onChartOpened(String sessionId) async {
    if (active == null || active!.visitSessionId != sessionId) return;
    active = active!.copyWith(
      chartOpenedAt: DateTime.now(),
      status: VisitTimerStatus.consulting,
      updatedAt: DateTime.now(),
    );
    await _persist(active!);
    notifyListeners();
  }

  Future<void> onChartClosed(String sessionId) async {
    if (active == null || active!.visitSessionId != sessionId) return;
    var chartSeconds = active!.chartActiveSeconds;
    if (active!.chartOpenedAt != null) {
      chartSeconds +=
          DateTime.now().difference(active!.chartOpenedAt!).inSeconds;
    }
    active = active!.copyWith(
      chartActiveSeconds: chartSeconds,
      clearChartOpenedAt: true,
      status: VisitTimerStatus.prep,
      updatedAt: DateTime.now(),
    );
    await _persist(active!);
    await _logEvent('chart_closed', {'chart_seconds': chartSeconds});
    notifyListeners();
  }

  Future<void> startCare({int? presetSlot}) async {
    if (active == null) return;
    final slot = presetSlot ?? selectedPresetSlot;
    final preset = presetAt(slot);
    if (preset.steps.isEmpty) return;

    final now = DateTime.now();
    active = active!.copyWith(
      templateId: preset.id.isEmpty ? null : preset.id,
      templateSnapshot: preset.steps,
      careStartedAt: now,
      clearCareEndedAt: true,
      currentStepIndex: 0,
      currentStepStartedAt: now,
      stepResults: const [],
      status: VisitTimerStatus.care,
      updatedAt: now,
    );
    await _persist(active!);
    await _logEvent('care_started', {'preset': preset.name});
    _ensureTicking();
    notifyListeners();
  }

  Future<void> endCare() async {
    if (active == null || !active!.canEndCare) return;
    final now = DateTime.now();
    await _finalizeCurrentStep(now);
    active = active!.copyWith(
      careEndedAt: now,
      status: VisitTimerStatus.postCare,
      updatedAt: now,
    );
    await _persist(active!);
    await _logEvent('care_ended', {});
    notifyListeners();
  }

  Future<void> markAfterPhotoCaptured() async {
    if (active == null) return;
    active = active!.copyWith(
      afterPhotoCaptured: true,
      updatedAt: DateTime.now(),
    );
    await _persist(active!);
    notifyListeners();
  }

  Future<String> buildReportBlock() async {
    final snap = liveSnapshot;
    if (snap == null || active == null) return '';
    final buf = StringBuffer(snap.buildReportBlock());
    for (final r in active!.stepResults) {
      buf.writeln(
        '· ${r.label}: ${snap.formatDuration(r.actualSeconds)} '
        '(예정 ${r.plannedMinutes}분)',
      );
    }
    if (snap.isOvertime) buf.writeln('· 정성 오버타임 포함');
    if (!active!.afterPhotoCaptured) buf.writeln('애프터: 미촬영');
    return buf.toString();
  }

  Future<void> endVisit() async {
    if (active == null) return;
    final now = DateTime.now();
    active = active!.copyWith(
      visitEndedAt: now,
      status: VisitTimerStatus.done,
      updatedAt: now,
    );
    await _persist(active!);
    await _logEvent('visit_ended', {});
    _stopTicking();
    notifyListeners();
  }

  void selectPresetSlot(int slot) {
    selectedPresetSlot = slot.clamp(0, 4);
    notifyListeners();
  }

  void _ensureTicking() {
    _tickTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick);
  }

  void _stopTicking() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  Future<void> _onTick() async {
    if (active == null ||
        active!.status == VisitTimerStatus.done ||
        active!.status == VisitTimerStatus.idle) {
      return;
    }
    await _advanceStepsIfNeeded();
    notifyListeners();
  }

  Future<void> _advanceStepsIfNeeded() async {
    final timer = active;
    if (timer == null || timer.status != VisitTimerStatus.care) return;
    if (timer.currentStepIndex >= timer.templateSnapshot.length) {
      if (timer.status != VisitTimerStatus.careOvertime) {
        active = timer.copyWith(
          status: VisitTimerStatus.careOvertime,
          updatedAt: DateTime.now(),
        );
        await _persist(active!);
        await _logEvent('care_plan_complete', {});
      }
      return;
    }

    final stepStart = timer.currentStepStartedAt ?? timer.careStartedAt;
    if (stepStart == null) return;
    final step = timer.templateSnapshot[timer.currentStepIndex];
    final elapsed = DateTime.now().difference(stepStart).inSeconds;
    if (elapsed < step.seconds) return;

    await _finalizeCurrentStep(DateTime.now());
    final nextIndex = timer.currentStepIndex + 1;
    if (nextIndex >= timer.templateSnapshot.length) {
      active = active!.copyWith(
        currentStepIndex: nextIndex,
        status: VisitTimerStatus.careOvertime,
        clearCurrentStepStartedAt: true,
        updatedAt: DateTime.now(),
      );
      await _persist(active!);
      await _logEvent('care_plan_complete', {});
    } else {
      active = active!.copyWith(
        currentStepIndex: nextIndex,
        currentStepStartedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _persist(active!);
      await _logEvent('step_completed', {'index': timer.currentStepIndex});
    }
  }

  Future<void> _finalizeCurrentStep(DateTime endedAt) async {
    final timer = active;
    if (timer == null) return;
    if (timer.currentStepIndex >= timer.templateSnapshot.length) return;
    final step = timer.templateSnapshot[timer.currentStepIndex];
    final stepStart = timer.currentStepStartedAt ?? timer.careStartedAt;
    if (stepStart == null) return;

    final actual = endedAt.difference(stepStart).inSeconds.clamp(0, 86400);
    active = timer.copyWith(
      stepResults: [
        ...timer.stepResults,
        VisitTimerStepResult(
          label: step.label,
          plannedMinutes: step.minutes,
          actualSeconds: actual,
          startedAt: stepStart,
          endedAt: endedAt,
        ),
      ],
      updatedAt: endedAt,
    );
  }

  Future<void> _persist(VisitOperationTimer timer) async {
    final sid = _shopId;
    if (sid == null || sid.isEmpty) return;
    await VisitTimerLocalCache.saveActiveTimer(sid, timer);
    try {
      final saved = await _repository?.upsertVisitOperationTimer(timer);
      if (saved != null) {
        active = saved.copyWith(
          chartOpenedAt: timer.chartOpenedAt,
          currentStepStartedAt: timer.currentStepStartedAt,
        );
      }
    } catch (e) {
      debugPrint('VisitTimerStore persist failed: $e');
    }
  }

  Future<void> _logEvent(String type, Map<String, dynamic> payload) async {
    if (active == null || _repository == null) return;
    try {
      await _repository!.appendVisitOperationEvent(
        visitSessionId: active!.visitSessionId,
        shopId: active!.shopId,
        eventType: type,
        payload: payload,
      );
    } catch (e) {
      debugPrint('VisitTimerStore event log failed: $e');
    }
  }

  @override
  void dispose() {
    _stopTicking();
    super.dispose();
  }
}
