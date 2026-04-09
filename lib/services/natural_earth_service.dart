// lib/services/natural_earth_service.dart
//
// Loads two pre-bundled GeoJSON assets and answers "what is at (lat, lon)?".
//
// ── Required assets (add to pubspec.yaml under flutter › assets) ─────────────
//
//   assets/
//     ne_countries.geojson   – Natural Earth 110m Admin-0 countries
//       URL: https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_admin_0_countries.geojson
//       (~1 MB – includes CONTINENT and ADMIN fields)
//
//     ne_admin1.geojson      – Natural Earth 50m Admin-1 states/provinces
//       URL: https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_1_states_provinces.geojson
//       (~3 MB – includes name, admin fields)
//
// Both files are free and in the public domain (naturalearthdata.com).
// Download them, place in <project>/assets/, and register in pubspec.yaml.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef GeoNameResult = ({String? continent, String? country, String? region});

// ── Internal polygon representation ──────────────────────────────────────────

class _Ring {
  /// Flat list of [lon0, lat0, lon1, lat1, …].
  final Float64List coords;

  /// Bounding box for quick rejection.
  final double minLon, maxLon, minLat, maxLat;

  final GeoNameResult name;

  _Ring({required List<double> flat, required this.name})
      : coords = Float64List.fromList(flat),
        minLon = _minEven(flat),
        maxLon = _maxEven(flat),
        minLat = _minOdd(flat),
        maxLat = _maxOdd(flat);

  static double _minEven(List<double> l) {
    double m = double.infinity;
    for (int i = 0; i < l.length; i += 2) if (l[i] < m) m = l[i];
    return m;
  }

  static double _maxEven(List<double> l) {
    double m = double.negativeInfinity;
    for (int i = 0; i < l.length; i += 2) if (l[i] > m) m = l[i];
    return m;
  }

  static double _minOdd(List<double> l) {
    double m = double.infinity;
    for (int i = 1; i < l.length; i += 2) if (l[i] < m) m = l[i];
    return m;
  }

  static double _maxOdd(List<double> l) {
    double m = double.negativeInfinity;
    for (int i = 1; i < l.length; i += 2) if (l[i] > m) m = l[i];
    return m;
  }

  bool containsPoint(double lon, double lat) {
    if (lon < minLon || lon > maxLon || lat < minLat || lat > maxLat) {
      return false;
    }
    return _raycast(lon, lat);
  }

  bool _raycast(double lon, double lat) {
    int crossings = 0;
    final n = coords.length;
    for (int i = 0; i < n; i += 2) {
      final aLon = coords[i];
      final aLat = coords[i + 1];
      final bLon = coords[(i + 2) % n];
      final bLat = coords[(i + 3) % n];
      if ((aLat <= lat && bLat > lat) || (bLat <= lat && aLat > lat)) {
        final t = (lat - aLat) / (bLat - aLat);
        if (lon < aLon + t * (bLon - aLon)) crossings++;
      }
    }
    return crossings.isOdd;
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class NaturalEarthService {
  NaturalEarthService._();
  static final NaturalEarthService instance = NaturalEarthService._();

  final List<_Ring> _countryRings = [];
  final List<_Ring> _adminRings = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    await Future.wait([
      _loadAsset('assets/ne_110m_admin_0_countries.geojson', dest: _countryRings, isAdmin1: false),
      _loadAsset('assets/ne_10m_admin_1_states_provinces.geojson', dest: _adminRings, isAdmin1: true),
    ]);
    _loaded = true;
    debugPrint('NaturalEarth: ${_countryRings.length} country rings, '
        '${_adminRings.length} admin-1 rings loaded.');
  }

  Future<void> _loadAsset(
    String path, {
    required List<_Ring> dest,
    required bool isAdmin1,
  }) async {
    try {
      final raw = await rootBundle.loadString(path);
      // Decode on an isolate so the UI thread isn't blocked.
      final data = await compute(_parseGeoJson, raw);
      for (final entry in data) {
        final props = entry['properties'] as Map<String, dynamic>;
        final coords = entry['coords'] as List<List<double>>;

        final continent =
            (props['CONTINENT'] ?? props['continent']) as String?;
        final country =
            (props['ADMIN'] ?? props['NAME'] ?? props['name']) as String?;
        final region = isAdmin1
            ? (props['name'] ?? props['NAME_1'] ?? props['gn_name']) as String?
            : null;

        final nameResult = (
          continent: continent,
          country: country,
          region: region,
        );

        for (final ring in coords) {
          if (ring.length >= 6) dest.add(_Ring(flat: ring, name: nameResult));
        }
      }
    } catch (e) {
      debugPrint('NaturalEarth: could not load $path — $e');
    }
  }

  /// Looks up the geographic name for a (lat, lon) point.
  /// Returns null for ocean / unrecognised territory.
  GeoNameResult? lookup(double lat, double lon) {
    if (!_loaded) return null;

    GeoNameResult? countryResult;
    GeoNameResult? adminResult;

    for (final ring in _countryRings) {
      if (ring.containsPoint(lon, lat)) {
        countryResult = ring.name;
        break;
      }
    }

    for (final ring in _adminRings) {
      if (ring.containsPoint(lon, lat)) {
        adminResult = ring.name;
        break;
      }
    }

    if (countryResult == null && adminResult == null) return null;

    // Merge: prefer country-level continent/country, admin-1 region name.
    return (
      continent: countryResult?.continent ?? adminResult?.continent,
      country: countryResult?.country ?? adminResult?.country,
      region: adminResult?.region,
    );
  }
}

// ── Isolate-safe parser ───────────────────────────────────────────────────────

/// Runs in a separate isolate via [compute].
/// Returns a list of feature maps: {'properties': {...}, 'coords': [[lon, lat, …], …]}.
List<Map<String, dynamic>> _parseGeoJson(String raw) {
  final fc = jsonDecode(raw) as Map<String, dynamic>;
  final features = fc['features'] as List;
  final result = <Map<String, dynamic>>[];

  for (final feature in features) {
    final props = (feature['properties'] as Map?)?.cast<String, dynamic>() ?? {};
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    if (geometry == null) continue;

    final rings = _extractRings(geometry);
    if (rings.isNotEmpty) {
      result.add({'properties': props, 'coords': rings});
    }
  }
  return result;
}

List<List<double>> _extractRings(Map<String, dynamic> geometry) {
  final type = geometry['type'] as String;
  final coords = geometry['coordinates'];
  final rings = <List<double>>[];

  void addRing(List rawRing) {
    final flat = <double>[];
    for (final pt in rawRing) {
      flat.add((pt[0] as num).toDouble()); // lon
      flat.add((pt[1] as num).toDouble()); // lat
    }
    rings.add(flat);
  }

  if (type == 'Polygon') {
    addRing(coords[0] as List); // outer ring only
  } else if (type == 'MultiPolygon') {
    for (final poly in coords as List) {
      addRing((poly as List)[0] as List);
    }
  }
  return rings;
}
