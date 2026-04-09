// lib/models/marker_model.dart

class MarkerModel {
  final String id;
  final double lat;
  final double lon;
  final int createdAt; // epoch millis

  const MarkerModel({
    required this.id,
    required this.lat,
    required this.lon,
    required this.createdAt,
  });

  factory MarkerModel.fromMap(Map<String, Object?> map) => MarkerModel(
        id: map['id'] as String,
        lat: (map['lat'] as num).toDouble(),
        lon: (map['lon'] as num).toDouble(),
        createdAt: map['created_at'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'lat': lat,
        'lon': lon,
        'created_at': createdAt,
      };
}
