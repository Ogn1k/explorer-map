// lib/map/location_controller.dart

import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart' hide Animation;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as ymk
    hide Icon, Rect, LocationSettings;

import '../map/map_icons.dart';
import 'package:yandex_maps_mapkit_lite/src/bindings/image/image_provider.dart'
    as ymk_image;

class LocationController {
  LocationController({
    required ymk.MapWindow? Function() mapWindowGetter,
    required VoidCallback onUpdated,
  })  : _mapWindowGetter = mapWindowGetter,
        _onUpdated = onUpdated;

  final ymk.MapWindow? Function() _mapWindowGetter;
  final VoidCallback _onUpdated;

  StreamSubscription<Position>? _locationSub;
  ymk.Point? _userPoint;
  ymk.PlacemarkMapObject? _userPlacemark;

  ymk.Point? get userPoint => _userPoint;

  Future<void> dispose() async {
    await _locationSub?.cancel();
  }

  Future<void> startTracking({required bool centerCamera}) async {
    final status = await Permission.location.request();
    if (!status.isGranted || _mapWindowGetter() == null) return;

    final initial = await Geolocator.getCurrentPosition();
    _handleNewPosition(initial, centerCamera: centerCamera);

    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen((pos) => _handleNewPosition(pos, centerCamera: false));
  }

  Future<Position?> getFreshPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  void _handleNewPosition(Position pos, {required bool centerCamera}) {
    _userPoint = ymk.Point(latitude: pos.latitude, longitude: pos.longitude);
    if (centerCamera) {
      _mapWindowGetter()?.map.move(
        ymk.CameraPosition(_userPoint!, zoom: 15, azimuth: 0, tilt: 0),
        animation: const ymk.Animation(
          type: ymk.AnimationType.Smooth,
          duration: 1.5,
        ),
      );
    }

    _updatePlacemark();
  }

  Future<void> _updatePlacemark() async {
    final mapWindow = _mapWindowGetter();
    final userPoint = _userPoint;
    if (mapWindow == null || userPoint == null) return;

    if (_userPlacemark == null) {
      final pngBytes = await MapIcons.buildDotIcon();

      _userPlacemark = mapWindow.map.mapObjects.addPlacemark();
      _userPlacemark!
        ..geometry = userPoint
        ..setIconWithStyle(
          ymk_image.ImageProvider.fromImageProvider(MemoryImage(pngBytes)),
          ymk.IconStyle(
            anchor: const math.Point(0.5, 0.5),
            scale: 1,
            zIndex: 10,
          ),
        );
    } else {
      _userPlacemark!.geometry = userPoint;
    }
    _onUpdated();
  }
}
