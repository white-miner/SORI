import 'package:flutter_test/flutter_test.dart';
import 'package:sori/models/ai_tool.dart';

void main() {
  test('AiToolQuota remaining clamps at zero', () {
    const q = AiToolQuota(freeUsed: 6, freeLimit: 5);
    expect(q.freeRemaining, 0);
    expect(q.hasFree, false);
    expect(q.chipLabel, '무료 0/5회');
  });

  test('AiToolMode sku and pricing', () {
    expect(AiToolMode.marketing.sku, 'ai_copy_marketing');
    expect(AiToolMode.marketing.priceWon, 200);
    expect(AiToolMode.dual.priceEcho, 4);
    expect(AiToolMode.fromSku('ai_copy_dual'), AiToolMode.dual);
  });

  test('AiToolPurchaseResult parses free quota charge', () {
    final r = AiToolPurchaseResult.fromMap({
      'ok': true,
      'job_id': 'abc',
      'charged_via': 'free_quota',
      'charged_echo': 0,
      'quota': {'free_used': 2, 'free_limit': 5},
    });
    expect(r.ok, isTrue);
    expect(r.usedFreeQuota, isTrue);
    expect(r.quota.freeRemaining, 3);
  });

  test('AiToolDraft clipboardPayload joins hashtags', () {
    const d = AiToolDraft(
      marketingBody: '본문',
      hashtags: ['SORI', '#에스테틱'],
    );
    expect(d.clipboardPayload, contains('본문'));
    expect(d.clipboardPayload, contains('#SORI'));
  });
}
