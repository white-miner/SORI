/// PRD v4.0 — 생체 리듬 퀵 터치 (0=양호, 1=주의, 2=해당).
enum BiometricTouchState {
  ok,
  caution,
  active;

  int get value => index;

  static BiometricTouchState fromValue(int? raw) {
    if (raw == null || raw < 0) return BiometricTouchState.ok;
    if (raw >= 2) return BiometricTouchState.active;
    if (raw >= 1) return BiometricTouchState.caution;
    return BiometricTouchState.ok;
  }

  BiometricTouchState next() {
    return switch (this) {
      BiometricTouchState.ok => BiometricTouchState.caution,
      BiometricTouchState.caution => BiometricTouchState.active,
      BiometricTouchState.active => BiometricTouchState.ok,
    };
  }

  String get label => switch (this) {
        BiometricTouchState.ok => '양호',
        BiometricTouchState.caution => '주의',
        BiometricTouchState.active => '해당',
      };
}

class VisitBiometrics {
  const VisitBiometrics({
    this.sleep = BiometricTouchState.ok,
    this.cycle = BiometricTouchState.ok,
    this.alcohol = BiometricTouchState.ok,
    this.capturedAt,
  });

  final BiometricTouchState sleep;
  final BiometricTouchState cycle;
  final BiometricTouchState alcohol;
  final DateTime? capturedAt;

  bool get hasAnyCaution =>
      sleep != BiometricTouchState.ok ||
      cycle != BiometricTouchState.ok ||
      alcohol != BiometricTouchState.ok;

  factory VisitBiometrics.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const VisitBiometrics();
    final capturedRaw = map['captured_at']?.toString() ?? '';
    return VisitBiometrics(
      sleep: BiometricTouchState.fromValue(
        (map['sleep_state'] as num?)?.toInt(),
      ),
      cycle: BiometricTouchState.fromValue(
        (map['cycle_state'] as num?)?.toInt(),
      ),
      alcohol: BiometricTouchState.fromValue(
        (map['alcohol_state'] as num?)?.toInt(),
      ),
      capturedAt: DateTime.tryParse(capturedRaw)?.toLocal(),
    );
  }

  Map<String, dynamic> toMap() => {
        'sleep_state': sleep.value,
        'cycle_state': cycle.value,
        'alcohol_state': alcohol.value,
        'captured_at': (capturedAt ?? DateTime.now()).toUtc().toIso8601String(),
      };

  VisitBiometrics copyWith({
    BiometricTouchState? sleep,
    BiometricTouchState? cycle,
    BiometricTouchState? alcohol,
    DateTime? capturedAt,
  }) {
    return VisitBiometrics(
      sleep: sleep ?? this.sleep,
      cycle: cycle ?? this.cycle,
      alcohol: alcohol ?? this.alcohol,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }

  /// Consult Phase 상단 힌트 — 서술형 개조식.
  List<BiometricHint> get hints {
    final out = <BiometricHint>[];
    if (alcohol == BiometricTouchState.active) {
      out.add(
        const BiometricHint(
          headline: '술 후 24시간',
          narrative:
              '혈관 확장으로 멍·붉은기 위험이 높습니다. 타격 심도 1단계 낮추세요.',
        ),
      );
    } else if (alcohol == BiometricTouchState.caution) {
      out.add(
        const BiometricHint(
          headline: '음주 다음 날',
          narrative: '피부 재생이 느려질 수 있습니다. 열·마찰 자극을 줄이세요.',
        ),
      );
    }
    if (cycle == BiometricTouchState.active) {
      out.add(
        const BiometricHint(
          headline: '생리 주기',
          narrative:
              '프로게스테론 하강으로 장벽이 얇아집니다. 마찰력 스캐너를 반드시 실행하세요.',
        ),
      );
    }
    if (sleep == BiometricTouchState.caution ||
        sleep == BiometricTouchState.active) {
      out.add(
        const BiometricHint(
          headline: '수면 부족',
          narrative:
              '피부 재생 리듬이 느려집니다. 턴오버 로드맵에 휴식 간격을 넓히세요.',
        ),
      );
    }
    return out;
  }
}

class BiometricHint {
  const BiometricHint({
    required this.headline,
    required this.narrative,
  });

  final String headline;
  final String narrative;
}
