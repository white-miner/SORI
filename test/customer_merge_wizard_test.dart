import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sori/services/customer_merge_service.dart';
import 'package:sori/utils/remote_error_message.dart';

void main() {
  group('CustomerMergeService.confirmNameMatches', () {
    test('ignores leading and trailing whitespace', () {
      expect(
        CustomerMergeService.confirmNameMatches('하얀광부 ', '하얀광부'),
        isTrue,
      );
      expect(
        CustomerMergeService.confirmNameMatches('  하얀광부  ', '하얀광부'),
        isTrue,
      );
      expect(
        CustomerMergeService.confirmNameMatches('하얀광부', ' 하얀광부 '),
        isTrue,
      );
    });

    test('rejects different names', () {
      expect(
        CustomerMergeService.confirmNameMatches('다른이름', '하얀광부'),
        isFalse,
      );
    });
  });

  group('formatRemoteError', () {
    test('includes PostgrestException message details and code', () {
      const err = PostgrestException(
        message: 'function missing',
        code: '42883',
        details: 'detail line',
        hint: 'apply migration',
      );
      final text = formatRemoteError(err);
      expect(text, contains('function missing'));
      expect(text, contains('42883'));
      expect(text, contains('detail line'));
      expect(text, contains('apply migration'));
    });
  });
}
