import '../models/customer.dart';

class PendingMessage {
  const PendingMessage({
    required this.customerId,
    required this.customerName,
    required this.careType,
    required this.messagePreview,
    required this.scheduledTime,
  });

  final String customerId;
  final String customerName;
  final String careType;
  final String messagePreview;
  final String scheduledTime;
}

class MessageService {
  const MessageService._();

  static List<PendingMessage> generatePendingMessages(
    List<Customer> customers, {
    DateTime? referenceDate,
  }) {
    final today = _dateOnly(referenceDate ?? DateTime.now());

    return customers.asMap().entries.map((entry) {
      final index = entry.key;
      final customer = entry.value;
      return _generateForCustomer(customer, today, index);
    }).toList();
  }

  static PendingMessage _generateForCustomer(
    Customer customer,
    DateTime today,
    int index,
  ) {
    final daysSince = today
        .difference(_dateOnly(customer.lastTreatmentDate))
        .inDays;
    final honorificName = _honorificName(customer.name);
    final careType = _resolveCareType(daysSince, customer.treatmentType);
    final messagePreview = _buildMessage(
      honorificName: honorificName,
      daysSince: daysSince,
      treatmentType: customer.treatmentType,
      memo: customer.memo,
    );

    return PendingMessage(
      customerId: customer.id,
      customerName: customer.name,
      careType: careType,
      messagePreview: messagePreview,
      scheduledTime: _scheduledTime(index),
    );
  }

  static String _honorificName(String fullName) {
    if (fullName.length >= 3) {
      return '${fullName.substring(1)}님';
    }
    return '$fullName님';
  }

  static String _resolveCareType(int daysSince, String treatmentType) {
    if (daysSince <= 2) return '시술 후 케어';
    if (daysSince <= 6) return '안부 체크';
    if (daysSince <= 13) return '$treatmentType 리마인드';
    return '재방문 유도';
  }

  static String _buildMessage({
    required String honorificName,
    required int daysSince,
    required String treatmentType,
    required String memo,
  }) {
    if (daysSince <= 2) {
      return switch (treatmentType) {
        '수분케어' =>
          '$honorificName, ${_daysLabel(daysSince)} 받으신 수분케어 후 '
              '건조함이 느껴지지 않도록 보습 관리를 이어가 주세요. '
              '미지근한 물로 가볍게 두피를 씻어 주시면 좋습니다.',
        '재생케어' =>
          '$honorificName, ${_daysLabel(daysSince)} 받으신 재생케어 후 '
              '두피가 편안히 회복될 수 있도록 자극은 피해 주세요. '
              '48시간 동안은 샴푸와 뜨거운 드라이를 삼가 주시면 좋습니다.',
        _ =>
          '$honorificName, ${_daysLabel(daysSince)} 받으신 $treatmentType 시술 후 '
              '관리가 잘 이어지고 있는지 안내드립니다. '
              '시술 부위 자극은 최소화해 주세요.',
      };
    }

    if (daysSince <= 6) {
      return '$honorificName, $treatmentType 시술 후 '
          '$daysSince일째입니다. 두피 컨디션은 어떠신가요? '
          '불편한 증상이 있으시면 편하게 연락 주세요.';
    }

    if (daysSince <= 13) {
      final memoHint = memo.isNotEmpty ? ' $memo 관련 ' : ' ';
      return '$honorificName, 지난 $treatmentType 시술 후$memoHint'
          '케어 루틴을 한 번 더 점검해 보시면 좋겠습니다. '
          '필요하시면 맞춤 관리 방법도 안내해 드릴게요.';
    }

    final weeks = (daysSince / 7).floor();
    return '$honorificName, 마지막 방문 후 $weeks주가 지났습니다. '
        '이번 달 $treatmentType 프로그램도 준비해 두었으니 '
        '편하실 때 다시 뵙고 싶습니다.';
  }

  static String _daysLabel(int daysSince) {
    return switch (daysSince) {
      0 => '오늘',
      1 => '어제',
      _ => '$daysSince일 전',
    };
  }

  static String _scheduledTime(int index) {
    final hour = 10;
    final minute = index * 30;
    final totalMinutes = hour * 60 + minute;
    final displayHour = totalMinutes ~/ 60;
    final displayMinute = totalMinutes % 60;
    final minuteText = displayMinute.toString().padLeft(2, '0');
    return '오전 $displayHour:$minuteText';
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
