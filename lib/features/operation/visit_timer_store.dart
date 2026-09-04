import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/sori_repository.dart';
import '../../services/sori_store.dart';
import '../../utils/sori_uuid.dart';
import '../../visit_kernel/models/care_program_template.dart';
import '../../visit_kernel/models/preset_slot_tint.dart';
import '../../visit_kernel/models/visit_operation_timer.dart';
import 'care_timer_tts_service.dart';
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

  /// PRD v5.2 — care playback paused (step tick + TTS frozen).
  bool carePaused = false;
  DateTime? _pauseAnchor;

  String? _ttsSessionId;
  int _ttsLastStepAnnounced = -1;
  bool _ttsPlanCompleteAnnounced = false;

  /// PRD v5.3 — timer field quick path (not home Path C).
  int? homeQuickCareSlot;

  /// PRD v5.4 — home list selected preset (Path C, persisted).
  int? homeSelectedPresetSlot;

  bool get isHomeQuickCareReady {
    if (homeQuickCareSlot == null) return false;
    final preset = presetAt(homeQuickCareSlot!);
    return !preset.isEmpty;
  }

  bool get isPathCEligible {
    if (homeSelectedPresetSlot == null) return false;
    return !presetAt(homeSelectedPresetSlot!).isEmpty;
  }

  bool get isStandaloneActive =>
      active != null &&
      active!.isStandalone &&
      active!.status != VisitTimerStatus.done;

  Future<void> ensureStandaloneTimer() async {
    if (isStandaloneActive) return;
    final sid = _shopId;
    if (sid == null || sid.isEmpty) return;
    final now = DateTime.now();
    active = VisitOperationTimer(
      id: newUuidV4(),
      visitSessionId: '',
      shopId: sid,
      status: VisitTimerStatus.idle,
      utilitySource: 'standalone_timer',
      updatedAt: now,
    );
    await _persist(active!);
    notifyListeners();
  }

  void armHomeQuickCare(int slot) {
    homeQuickCareSlot = slot.clamp(0, 4);
    notifyListeners();
  }

  void clearHomeQuickCare() {
    homeQuickCareSlot = null;
    notifyListeners();
  }

  Future<void> selectHomePresetSlot(int? slot) async {
    homeSelectedPresetSlot = slot;
    final sid = _shopId;
    if (sid != null && sid.isNotEmpty) {
      await VisitTimerLocalCache.saveHomeSelectedPresetSlot(sid, slot);
    }
    notifyListeners();
  }

  Future<void> toggleHomePresetSlot(int slot) async {
    if (homeSelectedPresetSlot == slot) {
      await selectHomePresetSlot(null);
    } else {
      await selectHomePresetSlot(slot.clamp(0, 4));
    }
  }

  Future<void> bindPresetStandalone({int? presetSlot}) async {
    await ensureStandaloneTimer();
    await bindPreset(presetSlot: presetSlot);
  }

  Future<void> finishStandaloneCare() async {
    if (active == null || !active!.isStandalone) return;
    if (active!.canEndCare) {
      await endCare();
    }
    final finished = (active ?? VisitOperationTimer(
      id: '',
      visitSessionId: '',
      shopId: _shopId ?? '',
    )).copyWith(
      status: VisitTimerStatus.done,
      updatedAt: DateTime.now(),
    );
    await _persist(finished);
    active = null;
    clearHomeQuickCare();
    _stopTicking();
    notifyListeners();
  }

  void bind(SoriStore store, SoriRepository repository) {
    _store = store;
    _repository = repository;
  }

  String? get _shopId => _store?.shop.id.trim();

  bool get isCareArmed =>
      active != null &&
      active!.status == VisitTimerStatus.prep &&
      active!.templateSnapshot.isNotEmpty &&
      active!.careStartedAt == null;

  bool get isCareRunning =>
      active != null &&
      (active!.status == VisitTimerStatus.care ||
          active!.status == VisitTimerStatus.careOvertime);

  bool get canTogglePlayback =>
      isCareRunning;

  bool get canSkipStep =>
      active != null &&
      active!.status == VisitTimerStatus.care &&
      active!.currentStepIndex < active!.templateSnapshot.length;

  bool get isOvertime =>
      active?.status == VisitTimerStatus.careOvertime;

  VisitTimerLiveSnapshot? get liveSnapshot =>
      active == null
          ? null
          : VisitTimerLiveSnapshot.compute(
              active!,
              now: carePaused ? _pauseAnchor : null,
            );

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
    homeSelectedPresetSlot =
        await VisitTimerLocalCache.loadHomeSelectedPresetSlot(sid);

    try {
      final remote =
          await _repository?.loadCareProgramTemplates(sid) ?? const [];
      presets = _mergePresetSlots(sid, remote, cachedPresets);
    } catch (_) {
      presets = _mergePresetSlots(sid, const [], cachedPresets);
    }

    if (cachedActive != null && cachedActive.status != VisitTimerStatus.done) {
      active = cachedActive;
    }

    final session = _store?.activeVisitSession;
    if (session != null) {
      try {
        final remote =
            await _repository?.loadVisitOperationTimer(session.id);
        if (remote != null && remote.status != VisitTimerStatus.done) {
          active = _pickNewer(active, remote);
        }
      } catch (_) {}
    }

    if (active != null && active!.status != VisitTimerStatus.done) {
      _restoreTtsMarkersFrom(active!);
      _ensureTicking();
      await _advanceStepsIfNeeded(silent: true);
    } else {
      active = null;
    }

    notifyListeners();
  }

  /// Background resume — merge local cache + Supabase, catch up steps.
  Future<void> syncOnResume() async {
    final sid = _shopId;
    if (sid == null || sid.isEmpty) return;

    final current = active;
    if (current == null ||
        current.status == VisitTimerStatus.done ||
        current.status == VisitTimerStatus.idle) {
      return;
    }

    VisitOperationTimer? cached;
    try {
      cached = await VisitTimerLocalCache.loadActiveTimer(sid);
    } catch (_) {}

    VisitOperationTimer? remote;
    try {
      remote =
          await _repository?.loadVisitOperationTimer(current.visitSessionId);
    } catch (_) {}

    final merged = _pickNewer(
      cached?.visitSessionId == current.visitSessionId ? cached : null,
      remote,
    );
    if (merged != null && merged.visitSessionId == current.visitSessionId) {
      active = merged;
      _restoreTtsMarkersFrom(active!);
    }

    await _advanceStepsIfNeeded(silent: true);
    notifyListeners();
  }

  VisitOperationTimer? _pickNewer(
    VisitOperationTimer? a,
    VisitOperationTimer? b,
  ) {
    if (a == null) return b;
    if (b == null) return a;
    final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return aTime.isAfter(bTime) ? a : b;
  }

  void _resetTtsMarkers(String sessionId) {
    _ttsSessionId = sessionId.trim().isEmpty ? (active?.id ?? sessionId) : sessionId;
    _ttsLastStepAnnounced = -1;
    _ttsPlanCompleteAnnounced = false;
  }

  void _restoreTtsMarkersFrom(VisitOperationTimer timer) {
    _ttsSessionId = timer.visitSessionId;
    _ttsLastStepAnnounced = timer.currentStepIndex.clamp(-1, 999);
    _ttsPlanCompleteAnnounced =
        timer.status == VisitTimerStatus.careOvertime ||
            timer.status == VisitTimerStatus.postCare ||
            timer.status == VisitTimerStatus.done;
  }

  void _announceCareStartIfNeeded() {
    if (active == null || carePaused || CareTimerTtsService.isMuted) return;
    if (_ttsSessionId != active!.visitSessionId) {
      _resetTtsMarkers(active!.visitSessionId);
    }
    if (_ttsLastStepAnnounced >= 0) return;
    _ttsLastStepAnnounced = 0;
    unawaited(CareTimerTtsService.announceCareStart());
  }

  void _announceNextStepIfNeeded(int stepIndex) {
    if (active == null || stepIndex <= 0) return;
    if (carePaused || CareTimerTtsService.isMuted) return;
    if (_ttsLastStepAnnounced >= stepIndex) return;
    _ttsLastStepAnnounced = stepIndex;
    unawaited(CareTimerTtsService.announceNextStep());
  }

  void _announcePlanCompleteIfNeeded() {
    if (_ttsPlanCompleteAnnounced) return;
    if (carePaused || CareTimerTtsService.isMuted) return;
    _ttsPlanCompleteAnnounced = true;
    unawaited(CareTimerTtsService.announceCarePlanComplete());
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

  Future<void> playCare() async {
    if (active == null) return;
    if (isCareArmed) {
      await startCare(presetSlot: selectedPresetSlot);
      return;
    }
    if (active!.status == VisitTimerStatus.care && carePaused) {
      await resumeCare();
    }
  }

  Future<void> pauseCare() async {
    if (active == null || !isCareRunning) return;
    if (carePaused) return;
    carePaused = true;
    _pauseAnchor = DateTime.now();
    notifyListeners();
  }

  Future<void> resumeCare() async {
    if (active == null || !carePaused || _pauseAnchor == null) return;
    final delta = DateTime.now().difference(_pauseAnchor!);
    final timer = active!;
    active = timer.copyWith(
      careStartedAt: timer.careStartedAt?.add(delta),
      currentStepStartedAt: timer.currentStepStartedAt?.add(delta),
      updatedAt: DateTime.now(),
    );
    carePaused = false;
    _pauseAnchor = null;
    await _persist(active!);
    notifyListeners();
  }

  Future<void> toggleCarePlayback() async {
    if (!isCareRunning) return;
    if (carePaused) {
      await resumeCare();
    } else {
      await pauseCare();
    }
  }

  /// 현재 스텝 잔여를 버리고 다음 컬러 블록으로 강제 전환.
  Future<void> skipToNextStep() async {
    if (!canSkipStep) return;
    await _completeCurrentStep(silent: false);
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
    carePaused = false;
    _pauseAnchor = null;
    _resetTtsMarkers(active!.visitSessionId);
    _announceCareStartIfNeeded();
    _ensureTicking();
    notifyListeners();
  }

  Future<void> endCare() async {
    if (active == null || !active!.canEndCare) return;
    final now = DateTime.now();
    if (active!.status == VisitTimerStatus.care) {
      await _finalizeCurrentStep(now);
    }
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
    await endVisitWithOvertime();
  }

  Future<void> endVisitWithOvertime({int? overtimeSeconds}) async {
    if (active == null) return;
    final now = DateTime.now();
    final overtime = overtimeSeconds ??
        _computeOvertimeSeconds(active!, now: now);
    active = active!.copyWith(
      visitEndedAt: now,
      status: VisitTimerStatus.done,
      overtimeSeconds: overtime,
      updatedAt: now,
    );
    await _persist(active!);
    await _logEvent('visit_ended', {'overtime_seconds': overtime});
    _stopTicking();
    notifyListeners();
  }

  int _computeOvertimeSeconds(VisitOperationTimer timer, {DateTime? now}) {
    final snap = VisitTimerLiveSnapshot.compute(timer, now: now);
    return snap.overtimeElapsedSeconds;
  }

  void selectPresetSlot(int slot) {
    selectedPresetSlot = slot.clamp(0, 4);
    notifyListeners();
  }

  /// PRD v5.2 — bind preset without starting care (armed / prep).
  Future<void> bindPreset({int? presetSlot}) async {
    if (active == null) return;
    final slot = (presetSlot ?? selectedPresetSlot).clamp(0, 4);
    final preset = presetAt(slot);
    if (preset.steps.isEmpty) return;

    selectedPresetSlot = slot;
    if (active!.isStandalone || active!.status == VisitTimerStatus.idle) {
      armHomeQuickCare(slot);
    }
    carePaused = false;
    _pauseAnchor = null;
    final now = DateTime.now();
    active = active!.copyWith(
      templateId: preset.id.isEmpty ? null : preset.id,
      templateSnapshot: preset.steps,
      clearCareStartedAt: true,
      clearCareEndedAt: true,
      currentStepIndex: 0,
      clearCurrentStepStartedAt: true,
      stepResults: const [],
      status: VisitTimerStatus.prep,
      updatedAt: now,
    );
    await _persist(active!);
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
    if (carePaused) return;
    await _advanceStepsIfNeeded();
    notifyListeners();
  }

  Future<void> _advanceStepsIfNeeded({bool silent = false}) async {
    final timer = active;
    if (timer == null || timer.status != VisitTimerStatus.care) return;
    if (timer.currentStepIndex >= timer.templateSnapshot.length) {
      await _enterOvertime(silent: silent);
      return;
    }

    final stepStart = timer.currentStepStartedAt ?? timer.careStartedAt;
    if (stepStart == null) return;
    final step = timer.templateSnapshot[timer.currentStepIndex];
    final elapsed = DateTime.now().difference(stepStart).inSeconds;
    if (elapsed < step.seconds) return;

    await _completeCurrentStep(silent: silent);
  }

  Future<void> _completeCurrentStep({required bool silent}) async {
    final timer = active;
    if (timer == null || timer.status != VisitTimerStatus.care) return;
    if (timer.currentStepIndex >= timer.templateSnapshot.length) {
      await _enterOvertime(silent: silent);
      return;
    }

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
      if (!silent) _announcePlanCompleteIfNeeded();
    } else {
      active = active!.copyWith(
        currentStepIndex: nextIndex,
        currentStepStartedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _persist(active!);
      await _logEvent('step_completed', {'index': timer.currentStepIndex});
      if (!silent) _announceNextStepIfNeeded(nextIndex);
    }
  }

  Future<void> _enterOvertime({required bool silent}) async {
    final timer = active;
    if (timer == null || timer.status == VisitTimerStatus.careOvertime) {
      return;
    }
    active = timer.copyWith(
      status: VisitTimerStatus.careOvertime,
      updatedAt: DateTime.now(),
    );
    await _persist(active!);
    await _logEvent('care_plan_complete', {});
    if (!silent) _announcePlanCompleteIfNeeded();
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
          chartOpenedAt: saved.chartOpenedAt ?? timer.chartOpenedAt,
          currentStepStartedAt:
              saved.currentStepStartedAt ?? timer.currentStepStartedAt,
          utilitySource: saved.utilitySource ?? timer.utilitySource,
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
        visitSessionId: active!.visitSessionId.trim().isEmpty
            ? null
            : active!.visitSessionId,
        shopId: active!.shopId,
        eventType: type,
        payload: payload,
        timerId: active!.id,
        utilitySource: active!.utilitySource,
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
