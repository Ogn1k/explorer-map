// lib/map/map_controller.dart

import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as ymk
    hide Icon, Rect, LocationSettings;

import '../services/zone_service.dart';

class MapController implements ymk.MapCameraListener {
  MapController({
    required ZoneService zoneService,
    required Size Function() sizeProvider,
    required VoidCallback onCameraChanged,
  })  : _zoneService = zoneService,
        _sizeProvider = sizeProvider,
        _onCameraChanged = onCameraChanged;

  final ZoneService _zoneService;
  final Size Function() _sizeProvider;
  final VoidCallback _onCameraChanged;

  ymk.MapWindow? _mapWindow;
  ymk.MapWindow? get mapWindow => _mapWindow;

  static const _initialPoint = ymk.Point(latitude: 55.7558, longitude: 37.6173);

  void onMapCreated(ymk.MapWindow mapWindow, double devicePixelRatio) {
    _mapWindow = mapWindow;
    mapWindow.scaleFactor = devicePixelRatio;

    final map = mapWindow.map;
    map
      ..hdModeEnabled = false
      ..awesomeModelsEnabled = false
      ..indoorEnabled = false
      ..nightModeEnabled = false
      ..set2DMode(true)
      ..addCameraListener(this)
      ..move(
        const ymk.CameraPosition(
          _initialPoint,
          zoom: 12.0,
          azimuth: 0.0,
          tilt: 0.0,
        ),
      );
  }

  @override
  void onCameraPositionChanged(
    ymk.Map map,
    ymk.CameraPosition position,
    ymk.CameraUpdateReason reason,
    bool finished,
  ) {
    if (finished) preloadCurrentViewport();
    _onCameraChanged();
  }

  void preloadCurrentViewport() {
    final mw = _mapWindow;
    if (mw == null) return;

    final scale = mw.scaleFactor;
    final size = _sizeProvider();

    final swSp = ymk.ScreenPoint(x: 0, y: size.height * scale);
    final neSp = ymk.ScreenPoint(x: size.width * scale, y: 0);

    final sw = mw.screenToWorld(swSp);
    final ne = mw.screenToWorld(neSp);
    if (sw == null || ne == null) return;

    _zoneService.preloadBounds(
      swLat: sw.latitude,
      swLon: sw.longitude,
      neLat: ne.latitude,
      neLon: ne.longitude,
    );
  }
}
