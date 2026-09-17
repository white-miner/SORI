import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('market sources never debugPrint public data keys', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    final leaks = <String>[];
    for (final f in files) {
      final text = f.readAsStringSync();
      if (RegExp(r'debugPrint\([^)]*publicDataServiceKey').hasMatch(text) ||
          RegExp(r'debugPrint\([^)]*fromEnvironment').hasMatch(text) ||
          text.contains('debugPrint(Env.publicDataServiceKey') ||
          text.contains("debugPrint('serviceKey")) {
        leaks.add(f.path);
      }
    }
    expect(leaks, isEmpty);
  });
}
