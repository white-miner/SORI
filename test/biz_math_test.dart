import 'package:flutter_test/flutter_test.dart';

import 'package:sori/views/biz_dashboard/biz_math.dart';

void main() {
  const profile = ShopBizProfile(
    category: '에스테틱',
    address: '서울',
    monthlyFixedCostKrw: 2000000,
    materialRatePct: 15,
    targetOwnerPayKrw: 3200000,
    openDaysPerWeek: 5,
    hoursPerDay: 8,
    cardFeeRatePct: 2.5,
  );

  test('incomplete profile → null', () {
    expect(
      BizMath.compute(
        profile: const ShopBizProfile(),
        monthRevenueKrw: 10_000_000,
      ),
      isNull,
    );
  });

  test('missing revenue → null', () {
    expect(
      BizMath.compute(profile: profile, monthRevenueKrw: null),
      isNull,
    );
  });

  test('ZONE1 hourly & economic profit (wire-style numbers)', () {
    // 매출 1024만, 재료 15%, 카드 2.5%, 고정 200만, 인건비 320만
    final snap = BizMath.compute(
      profile: profile,
      monthRevenueKrw: 10_240_000,
      now: DateTime(2026, 8, 15),
    )!;

    expect(snap.materialCostKrw, 1_536_000);
    expect(snap.cardFeeKrw, 256_000);
    // afterOps = 10240000 - 1536000 - 256000 - 2000000 = 6448000
    expect(snap.businessProfitKrw, 6448000 - 3200000);
    expect(snap.hourlyYieldKrw, greaterThan(0));
    expect(snap.stage, BizMaturityStage.expanding);
  });

  test('BEP includes owner pay', () {
    final snap = BizMath.compute(
      profile: profile,
      monthRevenueKrw: 10_240_000,
      now: DateTime(2026, 8, 1),
    )!;
    // CM = 1 - 0.175 = 0.825; BEP = (200+320)만 / 0.825
    final expected = ((2000000 + 3200000) / 0.825).ceil();
    expect(snap.bepRevenueKrw, expected);
    expect(snap.bepDayOfMonth, isNotNull);
  });

  test('survival when profit negative', () {
    final snap = BizMath.compute(
      profile: profile.copyWith(targetOwnerPayKrw: 9_000_000),
      monthRevenueKrw: 5_000_000,
    )!;
    expect(snap.businessProfitKrw, lessThan(0));
    expect(snap.stage, BizMaturityStage.survival);
  });
}
