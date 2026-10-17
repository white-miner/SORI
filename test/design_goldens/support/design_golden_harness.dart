// D0-1 디자인 골든 하네스 — 화면을 결정적으로 그리기 위한 도구 모음.
//
// - 글꼴: 운영 웹이 Google Fonts에서 받는 Work Sans / Noto Sans KR /
//   Instrument Serif / Noto Serif KR 를 test/design_goldens/fonts 의
//   서브셋 TTF(KS X 1001 한글 2350자 + 코드에 쓰인 한글 + 라틴)로 등록한다.
//   google_fonts 가 만드는 패밀리 이름(WorkSans_regular, WorkSans_700 …)에
//   그대로 등록하므로 앱 코드는 바뀌지 않는다.
// - 시계: 앱은 DateTime.now() 를 직접 쓴다(lib 432곳)라서 테스트에서 고정할 수
//   없다(libfaketime 은 flutter_tester 를 수십 배 느리게 만들어 포기). 그래서
//   '오늘'이 보이는 화면(DESK, 고객 목록 주간 띠 등)은 기준선 날짜
//   (goldenBaselineDate)가 아닌 날에는 달라진다. 디자인 PR 에서는
//   tool/design_goldens.sh --compare 로 main 과 브랜치를 같은 날 같이 그려 비교한다.
//   시계 주입(clock 패키지)은 앱 코드 변경이라 별도 PR(D0-1b)로 제안.
// - 네트워크 사진: 모든 http(s) 이미지 요청에 fixtures/before.png ·
//   after.png 를 돌려준다(URL 에 'after' 가 있으면 after).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/tolerant_golden_comparator.dart';

/// 기준선을 만든 날(KST). 날짜가 보이는 화면은 이 날 기준이다.
const goldenBaselineDate = '2026-10-17';

/// 골든은 SORI_DESIGN_GOLDENS=1 일 때만 돈다(일반 flutter test 에서는 skip).
bool get designGoldensEnabled =>
    Platform.environment['SORI_DESIGN_GOLDENS'] == '1';

const _dir = 'test/design_goldens';

// 골든 전용 합본 글꼴: Work Sans(라틴) + Noto Sans KR(한글) 을 한 파일로 합쳤다.
// 운영 웹은 Work Sans 에 없는 한글을 CanvasKit 이 Noto Sans KR 로 폴백해
// 그리는데, flutter_tester 에는 그 자동 폴백이 없어서 합본으로 같은 결과를 낸다.
// (세리프도 Instrument Serif + Noto Serif KR 합본.) 생성 방법은 README 참고.
const _sans = <String>[
  'SoriGoldenSans-Regular.ttf',
  'SoriGoldenSans-Medium.ttf',
  'SoriGoldenSans-SemiBold.ttf',
  'SoriGoldenSans-Bold.ttf',
  'SoriGoldenSans-ExtraBold.ttf',
];
const _serif = <String>['SoriGoldenSerif-Regular.ttf'];
const Map<String, List<String>> _fontFiles = {
  'WorkSans': _sans,
  'NotoSansKR': _sans,
  'Roboto': _sans,
  'InstrumentSerif': _serif,
  'NotoSerifKR': _serif,
};

const _variants = [
  'regular',
  'italic',
  '100',
  '200',
  '300',
  '500',
  '600',
  '700',
  '800',
  '900',
];

bool _fontsLoaded = false;

Future<void> loadDesignGoldenFonts() async {
  if (_fontsLoaded) return;
  for (final entry in _fontFiles.entries) {
    final bytes = [
      for (final f in entry.value)
        ByteData.sublistView(File('$_dir/fonts/$f').readAsBytesSync()),
    ];
    for (final name in [
      entry.key,
      for (final v in _variants) '${entry.key}_$v',
    ]) {
      final loader = FontLoader(name);
      for (final b in bytes) {
        loader.addFont(Future.value(b));
      }
      await loader.load();
    }
  }
  // 플러터 SDK 에 들어 있는 아이콘 글꼴.
  final icons = FontLoader('MaterialIcons');
  icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
  try {
    final cupertino = FontLoader('packages/cupertino_icons/CupertinoIcons');
    cupertino.addFont(
      rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
    );
    await cupertino.load();
  } catch (_) {}
  _fontsLoaded = true;
}

// ---- google_fonts 가 테스트에서도 "번들 글꼴"을 찾게 하는 자산 채널 목 ----
//
// google_fonts 는 AssetManifest 에 `<Family>-<Variant>.ttf` 가 있으면 그 파일을
// 쓴다. 테스트에서만 flutter/assets 채널에 서브셋 글꼴을 끼워 넣어
// 네트워크 없이 운영과 같은 글꼴로 그린다(앱 pubspec 은 그대로).
const _variantFile = {
  'Thin': 400,
  'ExtraLight': 400,
  'Light': 400,
  'Regular': 400,
  'Medium': 500,
  'SemiBold': 600,
  'Bold': 700,
  'ExtraBold': 800,
  'Black': 800,
};
const _weightName = {
  400: 'Regular',
  500: 'Medium',
  600: 'SemiBold',
  700: 'Bold',
  800: 'ExtraBold',
};

String? _localFontFor(String family, String variant) {
  final files = _fontFiles[family];
  if (files == null) return null;
  final base = variant.replaceAll('Italic', '');
  final want = _variantFile[base.isEmpty ? 'Regular' : base] ?? 400;
  // 가장 가까운 굵기 파일.
  String? best;
  var bestDiff = 1 << 20;
  for (final f in files) {
    final name = f.split('-').last.replaceAll('.ttf', '');
    if (files.length == 1) return f;
    final w = _weightName.entries
        .firstWhere(
          (e) => e.value == name,
          orElse: () => const MapEntry(400, 'Regular'),
        )
        .key;
    final d = (w - want).abs();
    if (d < bestDiff) {
      bestDiff = d;
      best = f;
    }
  }
  return best;
}

void installGoldenFontAssets() {
  final messenger = TestWidgetsFlutterBinding.instance.defaultBinaryMessenger;
  // CachedNetworkImage(flutter_cache_manager) 가 쓰는 path_provider 목.
  final tmp = Directory.systemTemp.createTempSync('sori_golden_cache_');
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => tmp.path,
  );
  final fontAssets = <String, String>{};
  for (final fam in _fontFiles.keys) {
    for (final v in _variantFile.keys) {
      for (final it in ['', 'Italic']) {
        final variant = v == 'Regular' && it.isNotEmpty ? 'Italic' : '$v$it';
        fontAssets['google_fonts/$fam-$variant.ttf'] = _localFontFor(
          fam,
          variant,
        )!;
      }
    }
  }
  messenger.setMockMessageHandler('flutter/assets', (ByteData? message) async {
    final key = utf8.decode(
      message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes),
    );
    final decodedKey = Uri.decodeFull(key);
    if (decodedKey == 'AssetManifest.bin') {
      final orig = File('build/unit_test_assets/AssetManifest.bin');
      final Map<Object?, Object?> map = orig.existsSync()
          ? (const StandardMessageCodec().decodeMessage(
                  ByteData.sublistView(orig.readAsBytesSync()),
                )
                as Map<Object?, Object?>)
          : <Object?, Object?>{};
      final merged = Map<Object?, Object?>.of(map);
      for (final a in fontAssets.keys) {
        merged[a] = [
          {'asset': a},
        ];
      }
      return const StandardMessageCodec().encodeMessage(merged);
    }
    final local = fontAssets[decodedKey];
    if (local != null) {
      return ByteData.sublistView(File('$_dir/fonts/$local').readAsBytesSync());
    }
    final f = File('build/unit_test_assets/$decodedKey');
    if (f.existsSync()) return ByteData.sublistView(f.readAsBytesSync());
    return null;
  });
}

/// 골든 비교기 설치(OS 간 안티앨리어싱 차이 허용 0.5%).
void useDesignGoldens(String testFile) {
  useTolerantGoldens(testFile, maxDiffPercent: 0.5);
}

// ---- 가짜 네트워크 이미지 ----------------------------------------------

class GoldenImageHttpOverrides extends HttpOverrides {
  GoldenImageHttpOverrides()
    : _before = File('$_dir/fixtures/before.png').readAsBytesSync(),
      _after = File('$_dir/fixtures/after.png').readAsBytesSync();
  final Uint8List _before;
  final Uint8List _after;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _FakeClient(_before, _after);
}

class _FakeClient implements HttpClient {
  _FakeClient(this._before, this._after);
  final Uint8List _before;
  final Uint8List _after;

  @override
  bool autoUncompress = true;

  Future<HttpClientRequest> _req(Uri url) async {
    // Google Fonts 요청은 flutter_test 기본값처럼 400, 나머지는 모두 사진으로 본다
    // (시드 데이터의 picsum.photos 아바타 포함).
    final isImage =
        url.host != 'fonts.gstatic.com' && url.host != 'fonts.googleapis.com';
    if (!isImage) return _FakeRequest(url, Uint8List(0), status: 400);
    final isAfter = url.toString().toLowerCase().contains('after');
    return _FakeRequest(url, isAfter ? _after : _before);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _req(url);
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => _req(url);
  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      _req(Uri(scheme: 'https', host: host, port: port, path: path));
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.uri, this._bytes, {this.status = 200});
  @override
  final Uri uri;
  final Uint8List _bytes;
  final int status;
  @override
  final HttpHeaders headers = _FakeHeaders();
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = -1;
  @override
  bool persistentConnection = true;
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();
  @override
  void add(List<int> data) {}
  @override
  void write(Object? object) {}
  @override
  Future<void> flush() async {}
  @override
  Future<HttpClientResponse> get done async => _FakeResponse(_bytes, status);
  @override
  Future<HttpClientResponse> close() async => _FakeResponse(_bytes, status);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(this._bytes, [this._status = 200]);
  final Uint8List _bytes;
  final int _status;
  @override
  int get statusCode => _status;
  @override
  String get reasonPhrase => _status == 200 ? 'OK' : 'Bad Request';
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  int get contentLength => _bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  final HttpHeaders headers = _FakeHeaders();
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_bytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHeaders implements HttpHeaders {
  @override
  ContentType? contentType = ContentType('image', 'png');
  @override
  void forEach(void Function(String name, List<String> values) action) {}
  @override
  String? value(String name) => null;
  @override
  List<String>? operator [](String name) => null;
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// 정해진 프레임 수만큼 진행(무한 애니메이션 화면도 멈추지 않게).
Future<void> settleFrames(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 이미지 디코딩은 실제 비동기라 runAsync 로 기다렸다가 다시 그린다.
Future<void> waitForImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      final img = e.widget as Image;
      final completer = Completer<void>();
      final stream = img.image.resolve(ImageConfiguration.empty);
      late final ImageStreamListener l;
      l = ImageStreamListener(
        (_, _) {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (_, _) {
          if (!completer.isCompleted) completer.complete();
        },
      );
      stream.addListener(l);
      await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
      stream.removeListener(l);
    }
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

@visibleForTesting
const designGoldenWidths = <double>[360, 1280];
