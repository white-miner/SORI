import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

/// B/A 갤러리 워크스페이스. 헤더·독 사이 풀폭 사진, 하단은 스냅 다이얼.
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

  /// 태블릿·PC 가로. 폰 가로(높이 짧음)와 나눈다.
  static const double wideLandscapeMinWidth = 900;
  static const double shortLandscapeMaxHeight = 520;

  @override
  State<BeforeAfterComparePage> createState() => _BeforeAfterComparePageState();
}

class _BeforeAfterComparePageState extends State<BeforeAfterComparePage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _customerName = widget.customerName;
    _customerId = widget.customerId;
    _charts = List<CustomerChart>.from(widget.charts);
    _reseed(
      initialChartId: widget.initialChartId,
      initialCareName: widget.initialCareName,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // 회전 직후 한 프레임 더 그려 히트 영역이 옛 세로 좌표에 남지 않게 한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }
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
        if (_right?.key == slot.key) _right = null;
      } else if (_left?.key != slot.key) {
        _right = slot;
      }
    });
  }

  void _setBindSide(BaCompareBindSide side) {
    setState(() => _bindSide = side);
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

  bool get _shortLandscape {
    final size = MediaQuery.sizeOf(context);
    return MediaQuery.orientationOf(context) == Orientation.landscape &&
        size.height < BeforeAfterComparePage.shortLandscapeMaxHeight;
  }

  bool get _wideLandscape {
    final size = MediaQuery.sizeOf(context);
    return MediaQuery.orientationOf(context) == Orientation.landscape &&
        size.width >= BeforeAfterComparePage.wideLandscapeMinWidth &&
        size.height >= BeforeAfterComparePage.shortLandscapeMaxHeight;
  }

  @override
  Widget build(BuildContext context) {
    final empty = _slots.isEmpty;
    final short = !empty && _shortLandscape;
    final wide = !empty && _wideLandscape;

    final landscape = short || wide;
    final topChrome = Padding(
      padding: EdgeInsets.fromLTRB(8, short ? 2 : 4, 8, short ? 2 : 8),
      child: _TopChrome(
        careLabel: _careLabel,
        careOpen: _careOpen,
        programs: _programs,
        programKey: _programKey,
        compact: short,
        onBack: () => Navigator.of(context).maybePop(),
        onToggleCare: () => setState(() => _careOpen = !_careOpen),
        onSelectCare: _selectProgram,
        onMore: _openMore,
      ),
    );

    final column = Column(
      children: [
        // 가로는 세로 공간이 짧다. 크롬이 한 줄을 더 먹으면 사진이 그만큼 잘린다.
        if (!landscape) topChrome,
        Expanded(
          child: _buildPhotoStage(
            landscape: landscape,
            overlayChrome: landscape ? topChrome : null,
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
          compact: short,
        ),
      ],
    );

    Widget body = column;
    if (wide) {
      body = ColoredBox(
        color: const Color(0xFF0A0A0B),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            key: const Key('ba-compare-wide-frame'),
            constraints: const BoxConstraints(maxWidth: 1100),
            child: column,
          ),
        ),
      );
    } else if (short) {
      body = KeyedSubtree(
        key: const Key('ba-compare-layout-short'),
        child: column,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      body: empty
          ? SafeArea(child: _EmptyState(customerName: _customerName))
          : SafeArea(child: body),
    );
  }

  Widget _buildPhotoStage({
    required bool landscape,
    Widget? overlayChrome,
  }) {
    final hasPhoto = _left != null || _right != null;
    // 크롬이 사진 위에 뜨면 라벨은 그 아래로 내려야 겹치지 않는다.
    final labelTop = overlayChrome == null ? 16.0 : 64.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        Screenshot(
          controller: _shot,
          child: hasPhoto
              ? _ComparePhotoBody(
                  key: const Key('ba-compare-photo-stage'),
                  left: _left,
                  right: _right,
                  useSlider: _useSlider && _left != null && _right != null,
                  zoom: _zoom,
                  panY: _panY,
                  landscape: landscape,
                  onPanDelta: _nudgeY,
                )
              : const ColoredBox(color: Color(0xFF0A0A0B)),
        ),
        if (hasPhoto) ...[
          Positioned(
            top: labelTop,
            left: 16,
            child: const IgnorePointer(
              child: _ViewportCornerTag(
                key: Key('ba-compare-label-before'),
                text: 'Before',
              ),
            ),
          ),
          Positioned(
            top: labelTop,
            right: 16,
            child: const IgnorePointer(
              child: _ViewportCornerTag(
                key: Key('ba-compare-label-after'),
                text: 'After',
              ),
            ),
          ),
        ],
        Positioned(
          left: 8,
          top: 0,
          bottom: 0,
          child: Center(
            child: _YStepper(
              enabled: _zoom > 1,
              onUp: () => _nudgeY(28),
              onDown: () => _nudgeY(-28),
            ),
          ),
        ),
        Positioned(
          right: 8,
          top: 0,
          bottom: 0,
          child: Center(
            child: _ZoomStepper(
              zoom: _zoom,
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
            ),
          ),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: _ProfileCluster(
            name: _customerName,
            customer: _customer,
            charts: _charts,
            onProfile: _pickCustomer,
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: _ModeToggleButton(
            useSlider: _useSlider,
            onToggle: () => setState(() => _useSlider = !_useSlider),
          ),
        ),
        if (overlayChrome != null)
          Positioned(
            key: const Key('ba-compare-chrome-overlay'),
            top: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              // 크롬 위 가로 드래그가 아래 비교 슬라이더를 끌고 가면 안 된다.
              behavior: HitTestBehavior.deferToChild,
              onHorizontalDragStart: (_) {},
              onHorizontalDragUpdate: (_) {},
              child: SafeArea(bottom: false, child: overlayChrome),
            ),
          ),
      ],
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
    required this.landscape,
    required this.onPanDelta,
  });

  /// 인물 사진 한 장이 차지해야 할 가로:세로. 가로모드 필러박스 기준이다.
  static const double portraitAspect = 3 / 4;

  final VisitPhotoSlot? left;
  final VisitPhotoSlot? right;
  final bool useSlider;
  final double zoom;
  final double panY;
  final bool landscape;
  final ValueChanged<double> onPanDelta;

  Widget _pane(VisitPhotoSlot slot) {
    return ChartImagePane(
      url: slot.url,
      fallbackLabel: slot.shortLabel,
      tone: SoriTokens.textSecondary,
      fit: BoxFit.cover,
    );
  }

  Widget _sidePane(VisitPhotoSlot? slot, {required String missing}) {
    if (slot == null) {
      return ColoredBox(
        color: const Color(0xFF141416),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              missing,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }
    return _pane(slot);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final slider = useSlider && left != null && right != null;
        // 가로는 박스가 넓고 낮다. cover로 채우면 인물의 위아래가 잘려 나간다.
        // 사진이 쓸 폭을 세로 길이에 맞춰 묶고 남는 좌우는 여백으로 둔다.
        final photoWidth = landscape
            ? (h *
                    _ComparePhotoBody.portraitAspect *
                    (slider ? 1 : 2))
                .clamp(0.0, constraints.maxWidth)
            : constraints.maxWidth;
        final photo = slider
            ? BeforeAfterSlider(
                height: h,
                maxHeight: h,
                borderRadius: BorderRadius.zero,
                showCornerTags: false,
                before: _pane(left!),
                after: _pane(right!),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _sidePane(left, missing: 'Before 사진을 등록하세요')),
                  const ColoredBox(
                    color: Color(0xFF0A0A0B),
                    child: SizedBox(width: 2),
                  ),
                  Expanded(child: _sidePane(right, missing: 'After 사진을 등록하세요')),
                ],
              );

        final sized = SizedBox(
          key: const Key('ba-compare-photo-frame'),
          width: photoWidth,
          height: h,
          child: photo,
        );

        final framed = ClipRect(
          child: Transform.translate(
            offset: Offset(0, panY),
            child: AnimatedScale(
              key: const Key('ba-compare-photo-scale'),
              scale: zoom,
              alignment: Alignment.center,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Center(child: sized),
            ),
          ),
        );
        if (zoom <= 1) return framed;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragUpdate: (d) => onPanDelta(d.delta.dy),
          child: framed,
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
    required this.compact,
    required this.onBack,
    required this.onToggleCare,
    required this.onSelectCare,
    required this.onMore,
  });

  final String careLabel;
  final bool careOpen;
  final List<CareProgramGroup> programs;
  final String programKey;
  final bool compact;
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
                visualDensity: compact
                    ? VisualDensity.compact
                    : VisualDensity.standard,
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
                    padding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: compact ? 6 : 12,
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
                visualDensity: compact
                    ? VisualDensity.compact
                    : VisualDensity.standard,
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

class _ProfileCluster extends StatelessWidget {
  const _ProfileCluster({
    required this.name,
    required this.customer,
    required this.charts,
    required this.onProfile,
  });

  final String name;
  final Customer? customer;
  final List<CustomerChart> charts;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final visual = customer == null
        ? null
        : CustomerCrmStatusResolver.resolve(customer!, charts);
    return InkWell(
      key: const Key('ba-compare-profile'),
      onTap: onProfile,
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
    );
  }
}

class _ModeToggleButton extends StatelessWidget {
  const _ModeToggleButton({required this.useSlider, required this.onToggle});

  final bool useSlider;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return _ChromePlate(
      radius: 12,
      child: IconButton(
        key: const Key('ba-compare-mode'),
        onPressed: onToggle,
        icon: Icon(
          useSlider ? Icons.compare : Icons.view_column_outlined,
          color: Colors.white,
        ),
        tooltip: useSlider ? '나란히' : '슬라이더',
      ),
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
