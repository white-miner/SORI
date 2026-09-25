import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sori/services/region_map_gps.dart';

void main() {
  test('denied checkPermission does not skip getCurrentPosition', () {
    expect(
      RegionMapGps.shouldSkipPositionFor(LocationPermission.denied),
      isFalse,
    );
    expect(
      RegionMapGps.shouldSkipPositionFor(LocationPermission.deniedForever),
      isFalse,
    );
    expect(
      RegionMapGps.shouldSkipPositionFor(LocationPermission.whileInUse),
      isFalse,
    );

    // This contract applies to the explicit GPS button, not the new
    // permission-preserving card distance lookup.
    final src = File('lib/services/region_map_gps.dart').readAsStringSync()
        .split('static Future<({double lat, double lng})?> grantedPositionOrNull()').first;
    expect(src.contains('requestPermission()'), isTrue);
    expect(src.contains('getCurrentPosition('), isTrue);
    expect(src.contains('Geolocator.checkPermission'), isFalse);
    expect(src.contains('kIsWeb'), isTrue);
  });
}

