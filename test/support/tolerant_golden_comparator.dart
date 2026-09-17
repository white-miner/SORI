import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Soft tolerance for constitution harness goldens (label AA differs by OS).
class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(
    super.testFile, {
    this.maxDiffPercent = 1.0,
  });

  /// Allowed pixel mismatch percent (0–100). CI Linux vs Windows ~0.6%.
  final double maxDiffPercent;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed) return true;

    final diff = result.diffPercent;
    if (diff <= maxDiffPercent) {
      // ignore: avoid_print
      print(
        'Golden "$golden": accepted soft diff ${diff.toStringAsFixed(2)}% '
        '<= ${maxDiffPercent.toStringAsFixed(2)}%',
      );
      return true;
    }

    // Preserve default failure feedback path.
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}

/// Install [TolerantGoldenComparator] for the calling test file.
void useTolerantGoldens(String testFilePath, {double maxDiffPercent = 1.0}) {
  goldenFileComparator = TolerantGoldenComparator(
    Uri.file(testFilePath),
    maxDiffPercent: maxDiffPercent,
  );
}
