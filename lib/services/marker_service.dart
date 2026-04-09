// lib/services/marker_service.dart

import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/marker_model.dart';

class MarkerService extends ChangeNotifier {
  MarkerService({required DatabaseHelper db}) : _db = db;

  final DatabaseHelper _db;

  final List<MarkerModel> _markers = [];

  List<MarkerModel> get markers => List.unmodifiable(_markers);

  Future<void> init() async {
    final loaded = await _db.getAllMarkers();
    _markers
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  Future<MarkerModel> addMarker({
    required double lat,
    required double lon,
  }) async {
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final id = 'm_${createdAt}_${lat.toStringAsFixed(6)}_${lon.toStringAsFixed(6)}';
    final marker = MarkerModel(
      id: id,
      lat: lat,
      lon: lon,
      createdAt: createdAt,
    );
    _markers.add(marker);
    notifyListeners();
    await _db.insertMarker(marker);
    return marker;
  }
}
