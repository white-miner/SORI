import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:screenshot/screenshot.dart';

import '../features/visit/visit_customer_picker_sheet.dart';
import '../features/visit/widgets/ba_story_strip.dart';
import '../features/visit/widgets/ba_workspace_dock.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../routing/sori_router.dart';
import '../services/customer_crm_status_resolver.dart';
import '../services/instagram_quick_post.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../views/smart_guide_camera_page.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/sori_crm_status_avatar.dart';
import 'before_after_compare_sheet.dart';

/// B/A 갤러리 워크스페이스. 사진은 contain, 조작은 검은 매트(헤더·레일·독).
class BeforeAfterComparePage extends StatefulWidget {
  const BeforeAfterComparePage({
    super.key,
    required this.customerName,
    required this.charts,
    this.initialChartId,
    this.initialCareName,
    this.customerId,
    this.store,
  });

  final String customerName;
  final List<CustomerChart> charts;
  final String? initialChartId;
  final String? initialCareName;
  final String? customerId;
  final SoriStore? store;

  static const List<double> zoomSteps = [0.5, 1.0, 1.5, 2.0];
  static const int defaultZoomIndex = 1;

  @override
  State<BeforeAfterComparePage> createState() => _BeforeAfterComparePageState();
}

class _BeforeAfterComparePageState extends State<BeforeAfterComparePage> {
  final _shot = ScreenshotController();
  late String _customerName;
  late String? _customerId;
  late List<CustomerChart> _charts;
  late List<VisitPhotoSlot> _slots;
  late List<CareProgramGroup> _programs;
  late String _programKey;
  VisitPhotoSlot? _left;
  VisitPhotoSlot? _right;
  bool _useSlider = true;
  BaCompareBindSide _bindSide = BaCompareBindSide.right;
  int _zoomIndex = BeforeAfterComparePage.defaultZoomIndex;
  double _panY = 0;
  bool _careOpen = false;
  VisitPhotoSlot? _dragging;
  bool _dropAccepted = false;

  @override
  void initState() {
    super.initState();
    _customerName = widget.customerName;
    _customerId = widget.customerId;
    _charts = List<CustomerChart>.from(widget.charts);
    _reseed(
      initialChartId: widget.initialChartId,
      initialCareName: widget.initialCareName,
    );
  }

  void _reseed({String? initialChartId, String? initialCareName}) {
    _slots = buildVisitPhotoSlots(_charts);
    _programs = groupVisitPhotoSlotsByProgram(_slots);
    final seed = resolveCompareViewerSeed(
      slots: _slots,
      initialChartId: initialChartId,
      initialCareName: initialCareName,
    );
    _programKey = seed.programKey;
    _left = seed.left;
    _right = seed.right;
    _zoomIndex = BeforeAfterComparePage.defaultZoomIndex;
    _panY = 0;
  }

  List<VisitPhotoSlot> get _scopedSlots =>
      slotsForProgram(slots: _slots, programKey: _programKey);

  double get _zoom => BeforeAfterComparePage.zoomSteps[_zoomIndex];

  Customer? get _customer {
    final id = _customerId;
    final store = widget.store;
    if (id == null || store == null) return null;
    return store.findCustomer(id);
  }

  String get _careLabel {
    for (final p in _programs) {
      if (p.key == _programKey) return p.label;
    }
    return _programs.isEmpty ? '케어 선택' : _programs.first.label;
  }

  void _selectProgram(String key) {
    if (key == _programKey) return;
    final seed = resolveCompareViewerSeed(slots: _slots, initialCareName: key);
    setState(() {
      _programKey = seed.programKey;
      _left = seed.left;
      _right = seed.right;
      _zoomIndex = BeforeAfterComparePage.defaultZoomIndex;
      _panY = 0;
      _careOpen = false;
    });
  }

  void _bind(VisitPhotoSlot slot) {
    setState(() {
      if (_bindSide == BaCompareBindSide.left) {
        _left = slot;
      } else {
        _right = slot;
      }
    });
    HapticFeedback.lightImpact();
  }

  void _setBindSide(BaCompareBindSide side) {
    setState(() => _bindSide = side);
  }

  void _acceptTo(BaCompareBindSide side, VisitPhotoSlot slot) {
    _dropAccepted = true;
    setState(() {
      _bindSide = side;
      if (side == BaCompareBindSide.left) {
        _left = slot;
      } else {
        _right = slot;
      }
      _dragging = null;
    });
    HapticFeedback.lightImpact();
  }

  void _onDragStarted(VisitPhotoSlot slot) {
    _dropAccepted = false;
    setState(() => _dragging = slot);
  }

  void _onDragEnded() {
    final slot = _dragging;
    final accepted = _dropAccepted;
    _dropAccepted = false;
    setState(() => _dragging = null);
    if (!accepted && slot != null) _bind(slot);
  }

  void _zoomIn() {
    if (_zoomIndex >= BeforeAfterComparePage.zoomSteps.length - 1) return;
    setState(() => _zoomIndex++);
  }

  void _zoomOut() {
    if (_zoomIndex <= 0) return;
    setState(() {
      _zoomIndex--;
      if (_zoom <= 1) _panY = 0;
    });
  }

  void _nudgeY(double delta) {
    if (_zoom <= 1) {
      if (_panY != 0) setState(() => _panY = 0);
      return;
    }
    final h = MediaQuery.sizeOf(context).height;
    final max = (_zoom - 1) * h / 2;
    setState(() => _panY = (_panY + delta).clamp(-max, max));
  }

  Future<void> _pickCustomer() async {
    final store = widget.store;
    if (store == null) return;
    final picked = await showVisitCustomerPickerSheet(context, store: store);
    if (!mounted || picked == null) return;
    setState(() {
      _customerId = picked.id;
      _customerName = picked.name;
      _charts = store.chartsForCustomer(picked.id);
      _reseed();
    });
  }

  Future<void> _openMore() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetTile(ctx, 'save', Icons.download_outlined, '저장하기'),
              _sheetTile(ctx, 'feed', Icons.dynamic_feed_outlined, '피드에 추가'),
              _sheetTile(ctx, 'share', Icons.ios_share_outlined, '공유하기'),
              _sheetTile(ctx, 'camera', Icons.photo_camera_outlined, '촬영하기'),
              _sheetTile(ctx, 'exit', Icons.logout_rounded, '나가기'),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'save':
        await _saveFrame();
      case 'feed':
        _toast(_feedHint());
      case 'share':
        await _shareFrame();
      case 'camera':
        await _openCamera();
      case 'exit':
        if (context.canPop()) {
          context.go(AppPaths.appHome);
        } else {
          Navigator.of(context).maybePop();
        }
    }
  }

  ListTile _sheetTile(
    BuildContext ctx,
    String id,
    IconData icon,
    String label,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () => Navigator.pop(ctx, id),
    );
  }

  String _feedHint() {
    if (_left != null && _right != null && _left!.chartId == _right!.chartId) {
      return '이 회차는 이미 홈 피드 관리 케이스에 있습니다.';
    }
    return '피드에는 같은 회차의 Before/After만 올라갑니다.';
  }

  Future<Uint8List?> _captureFrame() {
    return _shot.capture(
      pixelRatio: 2,
      delay: const Duration(milliseconds: 16),
    );
  }

  Future<void> _saveFrame() async {
    if (kIsWeb) {
      _toast('웹에서는 공유하기로 저장하세요.');
      return;
    }
    final bytes = await _captureFrame();
    if (bytes == null || !mounted) {
      _toast('저장할 화면을 담지 못했습니다.');
      return;
    }
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.isAuth && !perm.hasAccess) {
      _toast('사진 보관함 권한이 필요합니다.');
      return;
    }
    await PhotoManager.editor.saveImage(
      bytes,
      filename: 'sori_ba_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    if (mounted) _toast('갤러리에 저장했습니다.');
  }

  Future<void> _shareFrame() async {
    final bytes = await _captureFrame();
    if (bytes == null || !mounted) {
      _toast('공유할 화면을 담지 못했습니다.');
      return;
    }
    await InstagramQuickPost.shareCapturedImage(bytes, fileName: 'sori_ba.png');
  }

  Future<void> _openCamera() async {
    final store = widget.store;
    final id = _customerId;
    if (store == null || id == null) {
      _toast('고객을 선택한 뒤 촬영할 수 있습니다.');
      return;
    }
    await SmartGuideCameraPage.open(
      context,
      shopId: store.shop.id,
      customerId: id,
      kind: GuideCameraKind.after,
      ghostBeforeUrl: _left?.url,
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final empty = _slots.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      body: empty
          ? SafeArea(child: _EmptyState(customerName: _customerName))
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: _TopChrome(
                      careLabel: _careLabel,
                      careOpen: _careOpen,
                      programs: _programs,
                      programKey: _programKey,
                      onBack: () => Navigator.of(context).maybePop(),
                      onToggleCare: () =>
                          setState(() => _careOpen = !_careOpen),
                      onSelectCare: _selectProgram,
                      onMore: _openMore,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 52,
                          child: Center(
                            child: _YStepper(
                              enabled: _zoom > 1,
                              onUp: () => _nudgeY(28),
                              onDown: () => _nudgeY(-28),
                            ),
                          ),
                        ),
                        Expanded(child: _buildPhotoDropZone()),
                        SizedBox(
                          width: 84,
                          child: _RightRail(
                            name: _customerName,
                            customer: _customer,
                            charts: _charts,
                            useSlider: _useSlider,
                            zoom: _zoom,
                            onProfile: _pickCustomer,
                            onToggleMode: () =>
                                setState(() => _useSlider = !_useSlider),
                            onZoomIn: _zoomIn,
                            onZoomOut: _zoomOut,
                          ),
                        ),
                      ],
                    ),
                  ),
                  BaWorkspaceDock(
                    key: const Key('ba-compare-story-strip'),
                    slots: _scopedSlots,
                    left: _left,
                    right: _right,
                    bindSide: _bindSide,
                    onBind: _bind,
                    onBindSide: _setBindSide,
                    onAcceptTo: _acceptTo,
                    onDragStarted: _onDragStarted,
                    onDragEnded: _onDragEnded,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPhotoDropZone() {
    return DragTarget<VisitPhotoSlot>(
      key: const Key('ba-compare-drop-zone'),
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => _acceptTo(_bindSide, d.data),
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0B),
            border: hovering
                ? Border.all(
                    color: _bindSide == BaCompareBindSide.left
                        ? BaWorkspaceColors.before
                        : BaWorkspaceColors.after,
                    width: 2,
                  )
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Screenshot(
                controller: _shot,
                child: _left != null && _right != null
                    ? _ComparePhotoBody(
                        key: const Key('ba-compare-photo-stage'),
                        left: _left!,
                        right: _right!,
                        useSlider: _useSlider,
                        zoom: _zoom,
                        panY: _panY,
                        onPanDelta: _nudgeY,
                      )
                    : const ColoredBox(color: Color(0xFF0A0A0B)),
              ),
              if (_left != null && _right != null) ...[
                const Positioned(
                  top: 16,
                  left: 16,
                  child: IgnorePointer(
                    child: _ViewportCornerTag(
                      key: Key('ba-compare-label-before'),
                      text: 'Before',
                    ),
                  ),
                ),
                const Positioned(
                  top: 16,
                  right: 16,
                  child: IgnorePointer(
                    child: _ViewportCornerTag(
                      key: Key('ba-compare-label-after'),
                      text: 'After',
                    ),
                  ),
                ),
              ],
              if (_dragging != null || hovering)
                IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(
                      alpha: hovering ? 0.28 : 0.10,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> openBeforeAfterComparePage({
  required BuildContext context,
  required String customerName,
  required List<CustomerChart> charts,
  String? initialChartId,
  String? initialCareName,
  String? customerId,
  SoriStore? store,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => BeforeAfterComparePage(
        customerName: customerName,
        charts: charts,
        initialChartId: initialChartId,
        initialCareName: initialCareName,
        customerId: customerId,
        store: store,
      ),
    ),
  );
}

class _ComparePhotoBody extends StatelessWidget {
  const _ComparePhotoBody({
    super.key,
    required this.left,
    required this.right,
    required this.useSlider,
    required this.zoom,
    required this.panY,
    required this.onPanDelta,
  });

  final VisitPhotoSlot left;
  final VisitPhotoSlot right;
  final bool useSlider;
  final double zoom;
  final double panY;
  final ValueChanged<double> onPanDelta;

  Widget _pane(VisitPhotoSlot slot) {
    return ChartImagePane(
      url: slot.url,
      fallbackLabel: slot.shortLabel,
      tone: SoriTokens.textSecondary,
      fit: BoxFit.contain,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final photo = useSlider
            ? BeforeAfterSlider(
                height: h,
                maxHeight: h,
                borderRadius: BorderRadius.zero,
                showCornerTags: false,
                before: _pane(left),
                after: _pane(right),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _pane(left)),
                  const ColoredBox(
                    color: Color(0xFF0A0A0B),
                    child: SizedBox(width: 2),
                  ),
                  Expanded(child: _pane(right)),
                ],
              );

        return ClipRect(
          child: Transform.translate(
            offset: Offset(0, panY),
            child: AnimatedScale(
              key: const Key('ba-compare-photo-scale'),
              scale: zoom,
              alignment: Alignment.center,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: GestureDetector(
                onVerticalDragUpdate: zoom > 1
                    ? (d) => onPanDelta(d.delta.dy)
                    : null,
                child: photo,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ViewportCornerTag extends StatelessWidget {
  const _ViewportCornerTag({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Colors.black.withValues(alpha: 0.45),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChromePlate extends StatelessWidget {
  const _ChromePlate({required this.child, this.radius = 12});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );
  }
}

class _YStepper extends StatelessWidget {
  const _YStepper({
    required this.enabled,
    required this.onUp,
    required this.onDown,
  });

  final bool enabled;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    return _ChromePlate(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('ba-compare-pan-up'),
            onPressed: enabled ? onUp : null,
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 22),
            color: Colors.white,
            disabledColor: Colors.white24,
            tooltip: '위로',
          ),
          IconButton(
            key: const Key('ba-compare-pan-down'),
            onPressed: enabled ? onDown : null,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
            color: Colors.white,
            disabledColor: Colors.white24,
            tooltip: '아래로',
          ),
        ],
      ),
    );
  }
}

class _ZoomStepper extends StatelessWidget {
  const _ZoomStepper({
    required this.zoom,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final double zoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  String get _label {
    if (zoom == zoom.roundToDouble()) return '${zoom.toInt()}x';
    return '${zoom}x';
  }

  @override
  Widget build(BuildContext context) {
    final steps = BeforeAfterComparePage.zoomSteps;
    return _ChromePlate(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const Key('ba-compare-zoom-in'),
              onPressed: zoom >= steps.last ? null : onZoomIn,
              icon: const Icon(Icons.add, size: 18),
              color: Colors.white,
              disabledColor: Colors.white24,
              tooltip: '확대',
              visualDensity: VisualDensity.compact,
            ),
            Text(
              _label,
              key: const Key('ba-compare-zoom-label'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            IconButton(
              key: const Key('ba-compare-zoom-out'),
              onPressed: zoom <= steps.first ? null : onZoomOut,
              icon: const Icon(Icons.remove, size: 18),
              color: Colors.white,
              disabledColor: Colors.white24,
              tooltip: '축소',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.careLabel,
    required this.careOpen,
    required this.programs,
    required this.programKey,
    required this.onBack,
    required this.onToggleCare,
    required this.onSelectCare,
    required this.onMore,
  });

  final String careLabel;
  final bool careOpen;
  final List<CareProgramGroup> programs;
  final String programKey;
  final VoidCallback onBack;
  final VoidCallback onToggleCare;
  final ValueChanged<String> onSelectCare;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _ChromePlate(
              radius: 12,
              child: IconButton(
                key: const Key('ba-compare-back'),
                onPressed: onBack,
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white,
                ),
                tooltip: '돌아가기',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ChromePlate(
                radius: 22,
                child: InkWell(
                  key: const Key('ba-compare-care-pill'),
                  onTap: onToggleCare,
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            careLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(
                          careOpen
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ChromePlate(
              radius: 12,
              child: IconButton(
                key: const Key('ba-compare-more'),
                onPressed: onMore,
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                tooltip: '더 보기',
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: careOpen
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _ChromePlate(
                    radius: 16,
                    child: Column(
                      children: [
                        for (final p in programs)
                          ListTile(
                            dense: true,
                            title: Text(
                              p.label,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: p.key == programKey
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                            onTap: () => onSelectCare(p.key),
                          ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _RightRail extends StatelessWidget {
  const _RightRail({
    required this.name,
    required this.customer,
    required this.charts,
    required this.useSlider,
    required this.zoom,
    required this.onProfile,
    required this.onToggleMode,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final String name;
  final Customer? customer;
  final List<CustomerChart> charts;
  final bool useSlider;
  final double zoom;
  final VoidCallback onProfile;
  final VoidCallback onToggleMode;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProfileCluster(
          name: name,
          customer: customer,
          charts: charts,
          useSlider: useSlider,
          onProfile: onProfile,
          onToggleMode: onToggleMode,
        ),
        const Spacer(),
        _ZoomStepper(
          zoom: zoom,
          onZoomIn: onZoomIn,
          onZoomOut: onZoomOut,
        ),
      ],
    );
  }
}

class _ProfileCluster extends StatelessWidget {
  const _ProfileCluster({
    required this.name,
    required this.customer,
    required this.charts,
    required this.useSlider,
    required this.onProfile,
    required this.onToggleMode,
  });

  final String name;
  final Customer? customer;
  final List<CustomerChart> charts;
  final bool useSlider;
  final VoidCallback onProfile;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    final visual = customer == null
        ? null
        : CustomerCrmStatusResolver.resolve(customer!, charts);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          key: const Key('ba-compare-profile'),
          onTap: onProfile,
          customBorder: const CircleBorder(),
          child: Column(
            children: [
              if (visual != null)
                SoriCrmStatusAvatar(
                  name: name,
                  visual: visual,
                  radius: 26,
                  animateWhenVisible: false,
                )
              else
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF1C1C1E),
                  child: Text(
                    name.isEmpty ? '?' : name.characters.first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              SizedBox(
                width: 72,
                child: Text(
                  '$name 님',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _ChromePlate(
          radius: 12,
          child: IconButton(
            key: const Key('ba-compare-mode'),
            onPressed: onToggleMode,
            icon: Icon(
              useSlider ? Icons.compare : Icons.view_column_outlined,
              color: Colors.white,
            ),
            tooltip: useSlider ? '나란히' : '슬라이더',
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.customerName});

  final String customerName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                '$customerName님의 비교할 회차 사진이 아직 없습니다.\n'
                '차트에 Before/After를 첨부하면 회차별로 비교할 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
