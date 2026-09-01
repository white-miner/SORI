/// PRD v6.0 — structured visit care report snapshot.
class VisitCareReport {
  const VisitCareReport({
    required this.visitSessionId,
    required this.chartId,
    required this.customerId,
    required this.customerName,
    required this.shopName,
    required this.presetName,
    required this.visitDate,
    required this.totalVisitSeconds,
    required this.consultationSeconds,
    required this.chartSeconds,
    required this.careSeconds,
    required this.plannedCareSeconds,
    required this.overtimeSeconds,
    required this.steps,
    required this.hadOvertime,
    required this.afterPhotoCaptured,
    required this.publicReportUrl,
    required this.kakaoShortMessage,
    required this.kakaoLongMessage,
    required this.internalAuditBlock,
    this.visitNumber = 0,
  });

  final String visitSessionId;
  final String chartId;
  final String customerId;
  final String customerName;
  final String shopName;
  final String presetName;
  final DateTime visitDate;
  final int visitNumber;

  final int totalVisitSeconds;
  final int consultationSeconds;
  final int chartSeconds;
  final int careSeconds;
  final int plannedCareSeconds;
  final int overtimeSeconds;

  final List<VisitCareStepLine> steps;
  final bool hadOvertime;
  final bool afterPhotoCaptured;
  final String publicReportUrl;

  final String kakaoShortMessage;
  final String kakaoLongMessage;
  final String internalAuditBlock;

  int get totalVisitMinutes => _ceilMinutes(totalVisitSeconds);
  int get careMinutes => _ceilMinutes(careSeconds);
  int get overtimeMinutes => _ceilMinutes(overtimeSeconds);

  static int _ceilMinutes(int seconds) {
    if (seconds <= 0) return 0;
    return (seconds + 59) ~/ 60;
  }

  Map<String, dynamic> toJson() => {
        'visit_session_id': visitSessionId,
        'chart_id': chartId,
        'customer_id': customerId,
        'customer_name': customerName,
        'shop_name': shopName,
        'preset_name': presetName,
        'visit_date': visitDate.toUtc().toIso8601String(),
        'visit_number': visitNumber,
        'total_visit_seconds': totalVisitSeconds,
        'consultation_seconds': consultationSeconds,
        'chart_seconds': chartSeconds,
        'care_seconds': careSeconds,
        'planned_care_seconds': plannedCareSeconds,
        'overtime_seconds': overtimeSeconds,
        'steps': steps.map((s) => s.toJson()).toList(),
        'had_overtime': hadOvertime,
        'after_photo_captured': afterPhotoCaptured,
        'public_report_url': publicReportUrl,
        'kakao_short_message': kakaoShortMessage,
        'kakao_long_message': kakaoLongMessage,
        'internal_audit_block': internalAuditBlock,
        'schema_version': 1,
      };

  factory VisitCareReport.fromJson(Map<String, dynamic> json) {
    final stepsRaw = json['steps'];
    final steps = <VisitCareStepLine>[];
    if (stepsRaw is List) {
      for (final item in stepsRaw) {
        if (item is Map) {
          steps.add(
            VisitCareStepLine.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    final visitDateRaw = json['visit_date']?.toString() ?? '';
    return VisitCareReport(
      visitSessionId: json['visit_session_id']?.toString() ?? '',
      chartId: json['chart_id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      shopName: json['shop_name']?.toString() ?? '',
      presetName: json['preset_name']?.toString() ?? '',
      visitDate: DateTime.tryParse(visitDateRaw)?.toLocal() ?? DateTime.now(),
      visitNumber: (json['visit_number'] as num?)?.toInt() ?? 0,
      totalVisitSeconds: (json['total_visit_seconds'] as num?)?.toInt() ?? 0,
      consultationSeconds: (json['consultation_seconds'] as num?)?.toInt() ?? 0,
      chartSeconds: (json['chart_seconds'] as num?)?.toInt() ?? 0,
      careSeconds: (json['care_seconds'] as num?)?.toInt() ?? 0,
      plannedCareSeconds: (json['planned_care_seconds'] as num?)?.toInt() ?? 0,
      overtimeSeconds: (json['overtime_seconds'] as num?)?.toInt() ?? 0,
      steps: steps,
      hadOvertime: json['had_overtime'] == true,
      afterPhotoCaptured: json['after_photo_captured'] == true,
      publicReportUrl: json['public_report_url']?.toString() ?? '',
      kakaoShortMessage: json['kakao_short_message']?.toString() ?? '',
      kakaoLongMessage: json['kakao_long_message']?.toString() ?? '',
      internalAuditBlock: json['internal_audit_block']?.toString() ?? '',
    );
  }
}

class VisitCareStepLine {
  const VisitCareStepLine({
    required this.label,
    required this.plannedMinutes,
    required this.actualSeconds,
    required this.deltaSeconds,
  });

  final String label;
  final int plannedMinutes;
  final int actualSeconds;
  final int deltaSeconds;

  Map<String, dynamic> toJson() => {
        'label': label,
        'planned_minutes': plannedMinutes,
        'actual_seconds': actualSeconds,
        'delta_seconds': deltaSeconds,
      };

  factory VisitCareStepLine.fromJson(Map<String, dynamic> json) {
    return VisitCareStepLine(
      label: json['label']?.toString() ?? '',
      plannedMinutes: (json['planned_minutes'] as num?)?.toInt() ?? 0,
      actualSeconds: (json['actual_seconds'] as num?)?.toInt() ?? 0,
      deltaSeconds: (json['delta_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}
