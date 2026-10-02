// S3-0 특성 테스트: 예약(희망 일정) 요청 화면 /care-request/:shopId.
//
// 지금은 ① 화면 제목에 링크의 shopId 가 아니라 스토어의 현재 샵(store.shop) 이름을 쓰고
// ② care_schedule_entries 에 upsert 하며 ③ 이어서 store.shop 기준으로 알림톡(mock)을
// 보내 그 샵의 포인트를 깎는다.
// 보안 S3 PR 3-5에서 submit_care_request RPC + shopId 샵 카드 + anon 알림톡 제거로
// 바뀌면 ①③ 기대값을 그 PR에서 고친다. ②의 입력값(이름·연락처·일정·케어·메모)은 유지한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/features/crm_today/care_schedule_lead_page.dart';
import 'package:sori/models/kakao_alimtalk.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/visit_kernel/messaging/sori_platform_alimtalk.dart';
import 'package:sori/visit_kernel/models/care_schedule_entry.dart';

class _AlimtalkCall {
  _AlimtalkCall(
    this.shopId,
    this.customerPhone,
    this.templateCode,
    this.content,
  );
  final String shopId;
  final String customerPhone;
  final String templateCode;
  final String content;
}

class _SpyRepository extends MemorySoriRepository {
  final List<CareScheduleEntry> upserts = [];
  final List<_AlimtalkCall> alimtalks = [];

  @override
  bool get isRemote => true;

  @override
  Future<CareScheduleEntry> upsertCareScheduleEntry(
    CareScheduleEntry entry,
  ) async {
    upserts.add(entry);
    return entry;
  }

  @override
  Future<KakaoAlimtalkSendResult> sendKakaoAlimtalkMock({
    required String shopId,
    required String customerPhone,
    required String templateCode,
    required String content,
    int cost = KakaoAlimtalkPricing.sendCostPoint,
    int marginAmount = KakaoAlimtalkPricing.defaultMarginAmount,
  }) async {
    alimtalks.add(_AlimtalkCall(shopId, customerPhone, templateCode, content));
    return KakaoAlimtalkSendResult.success(logId: 'spy', remainingPoints: -1);
  }
}

const _linkShopId = '00000000-0000-4000-8000-0000000000f2';

Future<void> _pumpPage(WidgetTester tester, SoriStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CareScheduleLeadPage(store: store, shopId: _linkShopId),
    ),
  );
  await tester.pump();
}

void main() {
  group('S3-0 예약 요청 화면 특성', () {
    testWidgets('제목은 링크 shopId 가 아니라 store.shop 이름이다', (tester) async {
      final store = SoriStore(repository: _SpyRepository());
      expect(store.shop.id, isNot(_linkShopId));

      await _pumpPage(tester, store);

      expect(find.text('희망 일정 요청'), findsOneWidget);
      expect(find.text(store.shop.name), findsOneWidget);
    });

    testWidgets('이름이나 연락처가 비면 저장하지 않고 안내만 한다', (tester) async {
      final repo = _SpyRepository();
      final store = SoriStore(repository: repo);
      await _pumpPage(tester, store);

      await tester.enterText(find.widgetWithText(TextField, '이름'), '홍길동');
      await tester.tap(find.text('희망 일정 보내기'));
      await tester.pump();

      expect(find.text('이름과 연락처를 입력해 주세요.'), findsOneWidget);
      expect(repo.upserts, isEmpty);
      expect(repo.alimtalks, isEmpty);
    });

    testWidgets('제출: shopId 로 리드를 upsert 하고 store.shop 으로 알림톡을 보내 포인트를 깎는다', (
      tester,
    ) async {
      final repo = _SpyRepository();
      final store = SoriStore(repository: repo);
      final ownShopId = store.shop.id;
      final pointsBefore = store.shop.kakaoPoint;
      await _pumpPage(tester, store);

      await tester.enterText(find.widgetWithText(TextField, '이름'), ' 홍길동 ');
      await tester.enterText(
        find.widgetWithText(TextField, '연락처'),
        '010-5555-6666',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '희망 케어 (선택)'),
        '수분케어',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '메모 (선택)'),
        '오후 희망',
      );
      await tester.tap(find.text('희망 일정 보내기'));
      await tester.pumpAndSettle();

      // ② 리드 저장
      expect(repo.upserts, hasLength(1));
      final entry = repo.upserts.single;
      expect(entry.shopId, _linkShopId);
      expect(entry.customerName, '홍길동');
      expect(entry.customerPhone, '010-5555-6666');
      expect(entry.careLabel, '수분케어');
      expect(entry.note, '오후 희망');
      expect(entry.source, CareScheduleSource.customerLead);
      expect(entry.status, CareScheduleStatus.scheduled);
      expect(entry.scheduledAt.hour, 14);
      expect(entry.scheduledAt.minute, 0);

      // ③ 알림톡은 링크의 샵이 아니라 store.shop 기준으로 나가고 그 샵 포인트가 줄어든다.
      expect(repo.alimtalks, hasLength(1));
      final sent = repo.alimtalks.single;
      expect(sent.shopId, ownShopId);
      expect(sent.shopId, isNot(_linkShopId));
      expect(sent.customerPhone, '01055556666');
      expect(sent.templateCode, SoriPlatformAlimtalk.templates.scheduleLeadAck);
      expect(sent.content, startsWith('[${SoriPlatformAlimtalk.channelName}]'));
      expect(sent.content, contains('customer=홍길동'));
      expect(
        store.shop.kakaoPoint,
        pointsBefore - KakaoAlimtalkPricing.sendCostPoint,
      );

      // 다른 샵 리드라 현재 샵 일정 목록에는 넣지 않는다.
      expect(store.careScheduleEntries.where((e) => e.id == entry.id), isEmpty);
      expect(find.text('희망 일정이 전달되었어요'), findsOneWidget);
    });
  });
}
