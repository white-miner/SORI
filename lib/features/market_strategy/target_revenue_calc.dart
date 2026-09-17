import 'dart:math' as math;

/// 목표 매출 계산 입력. 금액은 원 단위.
class TargetRevenueInput {
  const TargetRevenueInput({
    this.targetRevenueKrw = 0,
    required this.fixedCostKrw,
    required this.targetProfitKrw,
    required this.averageTicketKrw,
    this.variableCostPerVisitKrw,
    this.variableRate,
    required this.openDaysPerMonth,
    required this.trade,
  });

  final int targetRevenueKrw;
  final int fixedCostKrw;
  final int targetProfitKrw;
  final int averageTicketKrw;
  final int? variableCostPerVisitKrw;
  final double? variableRate;
  final int openDaysPerMonth;
  final String trade;

  int get resolvedVariableCost {
    if (variableCostPerVisitKrw != null) return variableCostPerVisitKrw!;
    final rate = variableRate ?? 0;
    return (averageTicketKrw * rate).round();
  }
}

class TargetRevenueError implements Exception {
  TargetRevenueError(this.code, this.message, {String? requestId})
      : requestId = requestId ?? 'local-${DateTime.now().millisecondsSinceEpoch}';

  final String code;
  final String message;
  final String requestId;

  Map<String, String> toJson() => {
        'code': code,
        'message': message,
        'requestId': requestId,
      };

  @override
  String toString() => '$code: $message';
}

class TargetRevenueResult {
  const TargetRevenueResult({
    required this.contributionKrw,
    required this.contributionRate,
    required this.requiredRevenueKrw,
    required this.monthlyVisits,
    required this.dailyVisits,
    required this.variableCostKrw,
    required this.input,
  });

  final int contributionKrw;
  final double contributionRate;
  final int requiredRevenueKrw;
  final int monthlyVisits;
  final int dailyVisits;
  final int variableCostKrw;
  final TargetRevenueInput input;

  Map<String, dynamic> toJson() => {
        'contributionKrw': contributionKrw,
        'contributionRate': contributionRate,
        'requiredRevenueKrw': requiredRevenueKrw,
        'monthlyVisits': monthlyVisits,
        'dailyVisits': dailyVisits,
        'variableCostKrw': variableCostKrw,
        'input': {
          'targetRevenueKrw': input.targetRevenueKrw,
          'fixedCostKrw': input.fixedCostKrw,
          'targetProfitKrw': input.targetProfitKrw,
          'averageTicketKrw': input.averageTicketKrw,
          'variableCostPerVisitKrw': input.variableCostPerVisitKrw,
          'variableRate': input.variableRate,
          'openDaysPerMonth': input.openDaysPerMonth,
          'trade': input.trade,
        },
      };

  factory TargetRevenueResult.fromJson(Map<String, dynamic> map) {
    final inputMap = (map['input'] as Map?)?.cast<String, dynamic>() ?? const {};
    return TargetRevenueResult(
      contributionKrw: _asInt(map['contributionKrw']),
      contributionRate: _asDouble(map['contributionRate']),
      requiredRevenueKrw: _asInt(map['requiredRevenueKrw']),
      monthlyVisits: _asInt(map['monthlyVisits']),
      dailyVisits: _asInt(map['dailyVisits']),
      variableCostKrw: _asInt(map['variableCostKrw']),
      input: TargetRevenueInput(
        targetRevenueKrw: _asInt(inputMap['targetRevenueKrw']),
        fixedCostKrw: _asInt(inputMap['fixedCostKrw']),
        targetProfitKrw: _asInt(inputMap['targetProfitKrw']),
        averageTicketKrw: _asInt(inputMap['averageTicketKrw']),
        variableCostPerVisitKrw: inputMap['variableCostPerVisitKrw'] == null
            ? null
            : _asInt(inputMap['variableCostPerVisitKrw']),
        variableRate: inputMap['variableRate'] == null
            ? null
            : _asDouble(inputMap['variableRate']),
        openDaysPerMonth: _asInt(inputMap['openDaysPerMonth'], 25),
        trade: '${inputMap['trade'] ?? ''}',
      ),
    );
  }

  static int _asInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse('$v') ?? fallback;
  }

  static double _asDouble(dynamic v, [double fallback = 0]) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? fallback;
  }
}

/// 목표 매출·필요 방문 순수 계산. UI/DB 의존 없음.
abstract final class TargetRevenueCalc {
  static TargetRevenueResult compute(TargetRevenueInput input) {
    validate(input);
    final ticket = input.averageTicketKrw;
    final variable = input.resolvedVariableCost;
    final contribution = ticket - variable;
    final rate = contribution / ticket;
    final need = input.fixedCostKrw + input.targetProfitKrw;
    final requiredRevenue = (need / rate).ceil();
    final monthly = (need / contribution).ceil();
    final daily = math.max(1, (monthly / input.openDaysPerMonth).ceil());
    return TargetRevenueResult(
      contributionKrw: contribution,
      contributionRate: rate,
      requiredRevenueKrw: requiredRevenue,
      monthlyVisits: monthly,
      dailyVisits: daily,
      variableCostKrw: variable,
      input: input,
    );
  }

  static void validate(TargetRevenueInput input) {
    if (input.fixedCostKrw < 0 ||
        input.targetProfitKrw < 0 ||
        input.targetRevenueKrw < 0 ||
        (input.variableCostPerVisitKrw ?? 0) < 0 ||
        (input.variableRate ?? 0) < 0) {
      throw TargetRevenueError('NEGATIVE_AMOUNT', '금액은 0원 이상이어야 합니다.');
    }
    if (input.averageTicketKrw <= 0) {
      throw TargetRevenueError('ZERO_TICKET', '평균 객단가는 0원일 수 없습니다.');
    }
    if (input.variableCostPerVisitKrw == null && input.variableRate == null) {
      throw TargetRevenueError(
        'MISSING_VARIABLE',
        '방문당 변동비 또는 변동비율을 입력해 주세요.',
      );
    }
    if ((input.variableRate ?? 0) >= 1 && input.variableCostPerVisitKrw == null) {
      throw TargetRevenueError(
        'VARIABLE_RATE_INVALID',
        '변동비율은 1 미만이어야 합니다.',
      );
    }
    final variable = input.resolvedVariableCost;
    if (variable >= input.averageTicketKrw) {
      throw TargetRevenueError(
        'VARIABLE_GE_TICKET',
        '변동비가 객단가 이상이면 공헌이익이 없습니다. 비용 구조를 다시 확인해 주세요.',
      );
    }
    if (input.openDaysPerMonth < 1 || input.openDaysPerMonth > 31) {
      throw TargetRevenueError('OPEN_DAYS_RANGE', '월 영업일은 1~31일만 가능합니다.');
    }
    if (input.trade.trim().isEmpty) {
      throw TargetRevenueError('TRADE_REQUIRED', '업종을 선택해 주세요.');
    }
  }

  /// 목표 방문 − 실제 방문. 음수는 0으로 본다.
  static int additionalMonthlyVisits({
    required int requiredMonthlyVisits,
    required int actualMonthlyVisits,
  }) {
    if (actualMonthlyVisits < 0) {
      throw TargetRevenueError('NEGATIVE_AMOUNT', '실제 방문은 0회 이상이어야 합니다.');
    }
    final gap = requiredMonthlyVisits - actualMonthlyVisits;
    return gap < 0 ? 0 : gap;
  }

  /// 일 필요 방문 대비 실제 일평균. 방문 데이터가 없으면 null (0과 구분).
  static int? extraDailyVisitsNeeded({
    required int targetDailyVisits,
    required int monthVisitCount,
    required int openDays,
  }) {
    if (targetDailyVisits <= 0 || monthVisitCount <= 0 || openDays <= 0) {
      return null;
    }
    final actualDaily = math.max(1, (monthVisitCount / openDays).ceil());
    return targetDailyVisits - actualDaily;
  }
}
