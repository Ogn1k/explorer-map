// lib/map/fog_painter.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as ymk
    hide Icon, Rect, LocationSettings;

import '../services/zone_service.dart';

class FogPainter extends CustomPainter {
  FogPainter({
    required this.mapWindow,
    required this.zoneService,
    required this.cameraPosition,
    required this.scaleFactor,
  }) : super(repaint: zoneService);

  final ymk.MapWindow mapWindow;
  final ZoneService zoneService;
  final ymk.CameraPosition cameraPosition;
  final double scaleFactor;

  static const double _fogOpacity = 0.82;
  static const double _minZoomForZones = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = scaleFactor;
    final rect = Offset.zero & size;
    final zoom = cameraPosition.zoom;

    final fogPaint = Paint()..color = Colors.black.withValues(alpha: _fogOpacity);

    if (zoom < _minZoomForZones) {
      canvas.drawRect(rect, fogPaint);
      return;
    }

    final sw = mapWindow.screenToWorld(
      ymk.ScreenPoint(x: 0, y: size.height * scale),
    );
    final ne = mapWindow.screenToWorld(
      ymk.ScreenPoint(x: size.width * scale, y: 0),
    );

    if (sw == null || ne == null) {
      canvas.drawRect(rect, fogPaint);
      return;
    }

    final zones = zoneService.getZonesInBounds(
      swLat: sw.latitude,
      swLon: sw.longitude,
      neLat: ne.latitude,
      neLon: ne.longitude,
    );

    final disabledZones = zones.where((z) => !z.enabled).toList();
    if (disabledZones.isEmpty) {
      canvas.drawRect(rect, fogPaint);
      return;
    }

    canvas.saveLayer(rect, Paint());

    canvas.drawRect(rect, fogPaint);

    final erasePaint = Paint()..blendMode = BlendMode.dstOut;

    for (final zone in disabledZones) {
      final swScreen = mapWindow.worldToScreen(
        ymk.Point(latitude: zone.swLat, longitude: zone.swLon),
      );
      final neScreen = mapWindow.worldToScreen(
        ymk.Point(latitude: zone.neLat, longitude: zone.neLon),
      );
      if (swScreen == null || neScreen == null) continue;

      final zoneRect = Rect.fromLTRB(
        math.min(swScreen.x, neScreen.x) / scale,
        math.min(swScreen.y, neScreen.y) / scale,
        math.max(swScreen.x, neScreen.x) / scale,
        math.max(swScreen.y, neScreen.y) / scale,
      );

      canvas.drawRect(zoneRect, erasePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(FogPainter old) {
    return old.scaleFactor != scaleFactor ||
        old.cameraPosition.zoom != cameraPosition.zoom ||
        old.cameraPosition.azimuth != cameraPosition.azimuth ||
        old.cameraPosition.tilt != cameraPosition.tilt ||
        old.cameraPosition.target.latitude != cameraPosition.target.latitude ||
        old.cameraPosition.target.longitude != cameraPosition.target.longitude;
  }
}
