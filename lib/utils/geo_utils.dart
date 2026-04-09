// lib/utils/geo_utils.dart

import 'dart:math' as math;

import 'package:yandex_maps_mapkit_lite/mapkit.dart';

const double kEarthRadiusMeters = 6371000.0;

double _degToRad(double deg) => deg * math.pi / 180;
double _radToDeg(double rad) => rad * 180 / math.pi;

double distanceMeters(Point a, Point b) {
  final dLat = _degToRad(b.latitude - a.latitude);
  final dLon = _degToRad(b.longitude - a.longitude);
  final lat1 = _degToRad(a.latitude);
  final lat2 = _degToRad(b.latitude);

  final sinLat = math.sin(dLat / 2);
  final sinLon = math.sin(dLon / 2);
  final h = sinLat * sinLat +
      math.cos(lat1) * math.cos(lat2) * sinLon * sinLon;
  return 2 * kEarthRadiusMeters * math.asin(math.sqrt(h));
}

Point projectPoint(Point from, Point to, double distanceMeters) {
  final lat1 = _degToRad(from.latitude);
  final lon1 = _degToRad(from.longitude);
  final lat2 = _degToRad(to.latitude);
  final lon2 = _degToRad(to.longitude);

  final dLon = lon2 - lon1;
  final y = math.sin(dLon) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  final bearing = math.atan2(y, x);

  final angularDistance = distanceMeters / kEarthRadiusMeters;
  final sinLat1 = math.sin(lat1);
  final cosLat1 = math.cos(lat1);

  final lat = math.asin(
    sinLat1 * math.cos(angularDistance) +
        cosLat1 * math.sin(angularDistance) * math.cos(bearing),
  );
  final lon = lon1 +
      math.atan2(
        math.sin(bearing) * math.sin(angularDistance) * cosLat1,
        math.cos(angularDistance) - sinLat1 * math.sin(lat),
      );

  double lonDeg = _radToDeg(lon);
  if (lonDeg > 180) lonDeg -= 360;
  if (lonDeg < -180) lonDeg += 360;

  return Point(latitude: _radToDeg(lat), longitude: lonDeg);
}

Point clampPointToRadius(Point user, Point tapped, double radiusMeters) {
  final d = distanceMeters(user, tapped);
  if (d <= radiusMeters) return tapped;
  return projectPoint(user, tapped, radiusMeters);
}
