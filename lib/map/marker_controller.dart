// lib/map/marker_controller.dart

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as ymk
    hide Icon, Rect, LocationSettings;

import '../services/marker_service.dart';
import '../utils/geo_utils.dart' as geo;
import 'location_controller.dart';
import 'map_icons.dart';
import 'package:yandex_maps_mapkit_lite/src/bindings/image/image_provider.dart'
    as ymk_image;

class MarkerController {
  MarkerController({
    required MarkerService markerService,
    required LocationController locationController,
    required ymk.MapWindow? Function() mapWindowGetter,
    required VoidCallback onUpdated,
  })  : _markerService = markerService,
        _locationController = locationController,
        _mapWindowGetter = mapWindowGetter,
        _onUpdated = onUpdated;

  final MarkerService _markerService;
  final LocationController _locationController;
  final ymk.MapWindow? Function() _mapWindowGetter;
  final VoidCallback _onUpdated;

  final Map<String, ymk.PlacemarkMapObject> _markerPlacemarks =
      <String, ymk.PlacemarkMapObject>{};
  Uint8List? _markerIconBytes;

  static const double maxMarkerDistanceMeters = 100.0;

  Future<void> handleLongTap(ymk.Point tappedPoint, BuildContext context) async {
    final pos = await _locationController.getFreshPosition();
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось получить геопозицию')),
      );
      return;
    }

    final userPoint = ymk.Point(latitude: pos.latitude, longitude: pos.longitude);
    final finalPoint = geo.clampPointToRadius(
      userPoint,
      tappedPoint,
      maxMarkerDistanceMeters,
    );

    await _markerService.addMarker(
      lat: finalPoint.latitude,
      lon: finalPoint.longitude,
    );
  }

  Future<void> syncMarkers() async {
    final mapWindow = _mapWindowGetter();
    if (mapWindow == null) return;
    for (final marker in _markerService.markers) {
      if (_markerPlacemarks.containsKey(marker.id)) continue;
      final pm = mapWindow.map.mapObjects.addPlacemark();
      final bytes = _markerIconBytes ??=
          await MapIcons.buildDotIcon(fill: const Color(0xFFFF9800));
      pm
        ..geometry = ymk.Point(latitude: marker.lat, longitude: marker.lon)
        ..setIconWithStyle(
          ymk_image.ImageProvider.fromImageProvider(MemoryImage(bytes)),
          ymk.IconStyle(
            anchor: const math.Point(0.5, 0.5),
            scale: 0.9,
            zIndex: 9,
          ),
        );
      _markerPlacemarks[marker.id] = pm;
    }
    _onUpdated();
  }
}
