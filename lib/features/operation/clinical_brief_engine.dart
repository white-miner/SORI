import 'models/clinical_environment_brief.dart';
import 'models/skin_stress_index.dart';

/// PRD v4.2 — 환경 임계 → 임상 디테일 + calmTargetC + device cap.
class ClinicalBriefEngine {
  ClinicalBriefEngine._();

  static ClinicalEnvironmentBrief build({
    required double tempC,
    required int humidityPct,
    required int uvIndex,
    required int pm25UgM3,
    required SkinStressIndex ssi,
    int hotDaysLast7 = 0,
  }) {
    var calm = 22.0;
    if (humidityPct < 45) calm += 0.5;
    if (uvIndex >= 6) calm += 0.3;
    if (tempC > 28) calm -= (tempC - 28) * 0.1;
    calm = calm.clamp(20.0, 24.0);

    final alerts = <ClinicalAlert>[];

    if (tempC >= 33 || hotDaysLast7 >= 3) {
      alerts.add(
        ClinicalAlert(
          key: 'heat_wave',
          priority: 100,
          headline: '폭염·고온 지속',
          narrative:
              '오늘 낮 동안 많이 덥고 고온이 지속되니, 피부 온도를 높이는 자극적 필링·레이저·고출력 HIFU는 강도를 낮추거나 저녁 슬롯으로 옮기세요.',
        ),
      );
    } else if (tempC >= 30) {
      alerts.add(
        ClinicalAlert(
          key: 'high_temp',
          priority: 70,
          headline: '고온 주의',
          narrative:
              '외기 ${tempC.toStringAsFixed(0)}°C로 열감이 빨리 올라갑니다. 냉각·보습으로 장벽을 먼저 안정시키세요.',
        ),
      );
    }

    if (pm25UgM3 >= 76) {
      alerts.add(
        ClinicalAlert(
          key: 'pm25_bad',
          priority: 90,
          headline: '미세먼지 고농도',
          narrative:
              'PM2.5 ${pm25UgM3}μg/m³로 피부 표면 오염·염증 리스크가 높습니다. 클렌징·진정을 강화하고 각질 제거는 보류하세요.',
        ),
      );
    } else if (pm25UgM3 >= 36) {
      alerts.add(
        ClinicalAlert(
          key: 'pm25_mod',
          priority: 50,
          headline: '미세먼지 보통',
          narrative: '미세먼지 농도가 올라갔습니다. 시술 전 이중 세안·진정 토너를 권장합니다.',
        ),
      );
    }

    if (uvIndex >= 8) {
      alerts.add(
        ClinicalAlert(
          key: 'uv_extreme',
          priority: 85,
          headline: '강한 자외선',
          narrative:
              '자외선 지수 $uvIndex로 광열·색소 반응 위험이 큽니다. 레이저·필링 출력을 1단계 낮추세요.',
        ),
      );
    } else if (uvIndex >= 6) {
      alerts.add(
        ClinicalAlert(
          key: 'uv_high',
          priority: 55,
          headline: '자외선 주의',
          narrative: 'SPF 재도포 후 상담을 시작하고, 시술 후 자외선 차단을 강조하세요.',
        ),
      );
    }

    if (humidityPct < 35) {
      alerts.add(
        ClinicalAlert(
          key: 'dry_air',
          priority: 45,
          headline: '건조 공기',
          narrative:
              '습도 ${humidityPct}%로 TEWL이 빨라집니다. 시술 전 수분·유분막 코팅을 우선하세요.',
        ),
      );
    }

    if (tempC >= 30 && uvIndex >= 6) {
      alerts.add(
        ClinicalAlert(
          key: 'heat_uv_combo',
          priority: 95,
          headline: '열·광 복합 스트레스',
          narrative:
              '고온과 강한 UV가 동시에 작용합니다. 열·광 케어는 최소화하고 냉각 진정만 우선하세요.',
        ),
      );
    }

    alerts.sort((a, b) => b.priority.compareTo(a.priority));

    final calmStr = calm.toStringAsFixed(1);
    String headline;
    String narrative;

    if (alerts.isNotEmpty) {
      final top = alerts.first;
      headline = top.headline;
      narrative = '${top.narrative} 웰컴 티·패드 온도는 **${calmStr}°C**로 맞추세요.'
          .replaceAll('**', '');
    } else if (ssi.band == SsiBand.low) {
      headline = '피부 스트레스 양호';
      narrative =
          '오늘 환경은 표준 프로토콜에 적합합니다. 웰컴 온도 ${calmStr}°C를 유지하세요.';
    } else {
      headline = '피부 스트레스 ${ssi.band.label}';
      narrative =
          '환경 스트레스 지수 ${ssi.score}입니다. 표준 프로토콜을 유지하되 체감 온도 ${calmStr}°C를 확인하세요.';
    }

    final deviceCap = switch (ssi.band) {
      SsiBand.critical => 1,
      SsiBand.high => 2,
      SsiBand.moderate => 3,
      SsiBand.low => 4,
    };

    return ClinicalEnvironmentBrief(
      headline: headline,
      narrative: narrative,
      calmTargetC: calm,
      deviceIntensityCap: deviceCap,
      alerts: alerts,
    );
  }
}
