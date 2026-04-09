// lib/models/zone_model.dart

const double kZoneSize = 0.1; // degrees ≈ 11 km
const int kZoneScale = 10;    // 1 / kZoneSize

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Converts a latitude to its grid-row index (SW corner of the cell).
/// Adding 1e-9 avoids floor rounding down on exact multiples.
int latToIdx(double lat) => (lat * kZoneScale + 1e-9).floor();
int lonToIdx(double lon) => (lon * kZoneScale + 1e-9).floor();

double idxToLat(int idx) => idx / kZoneScale;
double idxToLon(int idx) => idx / kZoneScale;

/// Unique zone ID – uses integer grid indices to avoid floating-point drift.
/// Format: "{latIdx}_{lonIdx}", e.g. "557_376", "-557_-376".
String makeZoneId(double lat, double lon) =>
    '${latToIdx(lat)}_${lonToIdx(lon)}';

String makeZoneIdFromIdx(int latIdx, int lonIdx) => '${latIdx}_${lonIdx}';

/// Parses a zone ID back to (latIdx, lonIdx).
/// Uses lastIndexOf('_') so negative latitudes (e.g. "-557_376") parse correctly.
({int latIdx, int lonIdx}) parseZoneId(String id) {
  final sep = id.lastIndexOf('_');
  return (
    latIdx: int.parse(id.substring(0, sep)),
    lonIdx: int.parse(id.substring(sep + 1)),
  );
}

// ── Data class ────────────────────────────────────────────────────────────────

class Zone {
  final String id;
  final int latIdx; // SW-corner row index
  final int lonIdx; // SW-corner column index
  final bool enabled; // true = fog is visible (default)
  final String? continent;
  final String? country;
  final String? region;

  const Zone({
    required this.id,
    required this.latIdx,
    required this.lonIdx,
    this.enabled = true,
    this.continent,
    this.country,
    this.region,
  });

  factory Zone.fromIdx(int latIdx, int lonIdx, {
    bool enabled = true,
    String? continent,
    String? country,
    String? region,
  }) =>
      Zone(
        id: makeZoneIdFromIdx(latIdx, lonIdx),
        latIdx: latIdx,
        lonIdx: lonIdx,
        enabled: enabled,
        continent: continent,
        country: country,
        region: region,
      );

  Zone copyWith({
    bool? enabled,
    String? continent,
    String? country,
    String? region,
  }) =>
      Zone(
        id: id,
        latIdx: latIdx,
        lonIdx: lonIdx,
        enabled: enabled ?? this.enabled,
        continent: continent ?? this.continent,
        country: country ?? this.country,
        region: region ?? this.region,
      );

  // Geo bounds
  double get swLat => idxToLat(latIdx);
  double get swLon => idxToLon(lonIdx);
  double get neLat => idxToLat(latIdx + 1);
  double get neLon => idxToLon(lonIdx + 1);
  double get centreLat => swLat + kZoneSize / 2;
  double get centreLon => swLon + kZoneSize / 2;

  String get coordLabel =>
      '${swLat.toStringAsFixed(1)}°, ${swLon.toStringAsFixed(1)}°';

  /// Title shown inside the accordion item: "{region} — {coords}" or just coords.
  String get panelTitle =>
      region != null ? '$region — $coordLabel' : coordLabel;

  /// Full breadcrumb used for search / tooltip.
  String get fullTitle => [
        if (continent != null) continent!,
        if (country != null) country!,
        if (region != null) region!,
        coordLabel,
      ].join(' — ');
}
