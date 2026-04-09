// lib/services/zone_service.dart
//
// Responsibilities:
//   • Maintain an in-memory cache of Zone objects.
//   • Serve synchronous viewport queries to FogPainter (paint() must be pure).
//   • Lazily resolve zone names via NaturalEarthService and persist to SQLite.
//   • Toggle zone enabled/disabled state with instant UI feedback.

import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/zone_model.dart';
import 'natural_earth_service.dart';

class ZoneService extends ChangeNotifier {
  ZoneService({required DatabaseHelper db, required NaturalEarthService ne})
      : _db = db,
        _ne = ne;

  final DatabaseHelper _db;
  final NaturalEarthService _ne;

  /// In-memory cache: zoneId → Zone.
  final Map<String, Zone> _cache = {};

  /// IDs currently being resolved (prevents duplicate async work).
  final Set<String> _resolving = {};

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// Call once at startup. Populates cache from persisted zone_names + states.
  Future<void> init() async {
    final zones = await _db.getAllNamedZones();
    for (final z in zones) {
      _cache[z.id] = z;
    }
    debugPrint('ZoneService: loaded ${_cache.length} cached zones.');
  }

  // ── Viewport queries (synchronous — called from FogPainter) ─────────────────

  /// Returns every zone whose grid cell intersects the given bounding box.
  /// Uses only the in-memory cache; unknown zones are returned as default
  /// (fog = on, no name). Call [preloadBounds] first to trigger background
  /// resolution for any unknowns.
  List<Zone> getZonesInBounds({
    required double swLat,
    required double swLon,
    required double neLat,
    required double neLon,
  }) {
    final latStart = latToIdx(swLat) - 1; // one cell of padding
    final latEnd = latToIdx(neLat) + 1;
    final lonStart = lonToIdx(swLon) - 1;
    final lonEnd = lonToIdx(neLon) + 1;

    final latCount = latEnd - latStart;
    final lonCount = lonEnd - lonStart;
    if (latCount * lonCount > 2000) return const [];

    final result = <Zone>[];
    for (int li = latStart; li <= latEnd; li++) {
      for (int lo = lonStart; lo <= lonEnd; lo++) {
        final id = makeZoneIdFromIdx(li, lo);
        result.add(_cache[id] ?? Zone.fromIdx(li, lo));
      }
    }
    return result;
  }

  /// Triggers background resolution for any zone in the viewport that is not
  /// yet in the cache. Safe to call from onCameraPositionChanged.
  void preloadBounds({
    required double swLat,
    required double swLon,
    required double neLat,
    required double neLon,
  }) {
    final latStart = latToIdx(swLat) - 1;
    final latEnd = latToIdx(neLat) + 1;
    final lonStart = lonToIdx(swLon) - 1;
    final lonEnd = lonToIdx(neLon) + 1;

    if ((latEnd -  latStart) * (lonEnd - lonStart)  > 2000) return;

    for (int li = latStart; li <= latEnd; li++) {
      for (int lo = lonStart; lo <= lonEnd; lo++) {
        final id = makeZoneIdFromIdx(li, lo);
        if (!_cache.containsKey(id) && !_resolving.contains(id)) {
          _resolveAsync(id, li, lo);
        }
      }
    }
  }

  // ── Single zone lookup (async — used by tap handler) ────────────────────────

  /// Returns the Zone at a geo coordinate, waiting for name resolution if needed.
  Future<Zone> getZoneAt(double lat, double lon) async {
    final id = makeZoneId(lat, lon);
    if (_cache.containsKey(id) && _cache[id]!.continent != null) {
      return _cache[id]!;
    }
    final li = latToIdx(lat);
    final lo = lonToIdx(lon);
    await _resolveAsync(id, li, lo);
    return _cache[id]!;
  }

  // ── Zone state toggle ────────────────────────────────────────────────────────

  Future<void> setZoneEnabled(String id, bool enabled) async {
    final zone = _cache[id];
    if (zone == null) return;
    // Update cache immediately for instant UI response.
    _cache[id] = zone.copyWith(enabled: enabled);
    notifyListeners();
    // Persist asynchronously.
    await _db.setZoneEnabled(id, enabled);
  }

  // ── Panel data ───────────────────────────────────────────────────────────────

  /// All zones that have a resolved name (shown in the drawer).
  List<Zone> get namedZones =>
      _cache.values.where((z) => z.country != null).toList();

  // ── Internal async resolution ────────────────────────────────────────────────

  Future<void> _resolveAsync(String id, int li, int lo) async {
    if (_resolving.contains(id)) return;
    _resolving.add(id);

    // Insert a placeholder so paint() never queries unknown zones twice.
    _cache[id] = Zone.fromIdx(li, lo);

    try {
      // 1. Check name cache in DB.
      final nameFromDb = await _db.getZoneName(id);

      String? continent, country, region;

      if (nameFromDb != null) {
        continent = nameFromDb.continent;
        country = nameFromDb.country;
        region = nameFromDb.region;
      } else {
        // 2. Point-in-polygon via Natural Earth (runs on main isolate but
        //    the polygons are already parsed — fast lookup).
        final centreLat = idxToLat(li) + kZoneSize / 2;
        final centreLon = idxToLon(lo) + kZoneSize / 2;
        final result = _ne.lookup(centreLat, centreLon);

        if (result != null) {
          continent = result.continent;
          country = result.country;
          region = result.region;
          // Cache to DB (only named zones — oceans are skipped).
          await _db.setZoneName(id,
              continent: continent, country: country, region: region);
        }
      }

      // 3. Fetch enabled state from DB (null = default = true).
      final enabled = await _db.getZoneEnabled(id) ?? true;

      _cache[id] = Zone(
        id: id,
        latIdx: li,
        lonIdx: lo,
        enabled: enabled,
        continent: continent,
        country: country,
        region: region,
      );

      notifyListeners();
    } catch (e) {
      debugPrint('ZoneService: error resolving $id — $e');
    } finally {
      _resolving.remove(id);
    }
  }
}
