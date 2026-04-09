import 'package:flutter_test/flutter_test.dart';
import 'package:yandex_maps_mapkit_lite/mapkit.dart';

import 'package:explorer/utils/geo_utils.dart';

void main() {
  test('clamp returns tap point when within radius', () {
    const user = Point(latitude: 0.0, longitude: 0.0);
    const tap = Point(latitude: 0.0, longitude: 0.00005); // ~5.5m at equator

    final result = clampPointToRadius(user, tap, 10.0);

    expect(result.latitude, closeTo(tap.latitude, 1e-9));
    expect(result.longitude, closeTo(tap.longitude, 1e-9));
  });

  test('clamp moves point to radius when too far', () {
    const user = Point(latitude: 0.0, longitude: 0.0);
    const tap = Point(latitude: 0.0, longitude: 0.0003); // ~33m at equator

    final result = clampPointToRadius(user, tap, 10.0);
    final d = distanceMeters(user, result);

    expect(d, closeTo(10.0, 0.5));
    expect(result.longitude, greaterThan(0.0));
    expect(result.longitude, lessThan(tap.longitude));
  });
}
