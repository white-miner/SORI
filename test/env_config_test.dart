import 'package:flutter_test/flutter_test.dart';
import 'package:sori/config/env.dart';

void main() {
  test('example placeholder is not a real Supabase credential', () {
    expect(
      Env.isPlaceholderCredential('https://YOUR_PROJECT.supabase.co'),
      isTrue,
    );
    expect(Env.isPlaceholderCredential('your_anon_or_publishable_key'), isTrue);
    expect(
      Env.isPlaceholderCredential('https://abcd.supabase.co'),
      isFalse,
    );
  });
}
