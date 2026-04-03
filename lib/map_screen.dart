import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Animation;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:yandex_maps_mapkit_lite/mapkit.dart' hide Icon, Rect, LocationSettings;
import 'package:yandex_maps_mapkit_lite/mapkit_factory.dart';
import 'package:yandex_maps_mapkit_lite/yandex_map.dart';

import 'package:yandex_maps_mapkit_lite/src/bindings/image/image_provider.dart'
    as ymk_image;


const double _kVisibleRadiusMeters = 300.0;

const double _kMinStepMeters = 50;

double _distanceMeters(Point a, Point b) {
  const r = 6371000; // Earth radius in meters
  final dLat = _deg2rad(b.latitude - a.latitude);
  final dLon = _deg2rad(b.longitude - a.longitude);
  final sinLat = math.sin(dLat / 2);
  final sinLon = math.sin(dLon / 2);
  final h = sinLat * sinLat +
      math.cos(_deg2rad(a.latitude)) *
          math.cos(_deg2rad(b.latitude)) *
          sinLon *
          sinLon;
    return 2 * r * math.asin(math.sqrt(h));
}

double _deg2rad(double deg) => deg * math.pi / 180;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver 
implements MapCameraListener {
  MapWindow? _mapWindow;

  PlacemarkMapObject? _userPlacemark;

  Point? _userPoint;

  final List<Point> _exploredPoints = [];

  List<Offset> _exploredScreenPositions = [];
  double _fogRadiusPx = 0;

  StreamSubscription<Position>? _locationSub;

  static const _initialPoint = Point(latitude: 55.7558, longitude: 37.6173);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    mapkit.onStart();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _mapWindow?.map.removeCameraListener(this);
    mapkit.onStop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      mapkit.onStart();
    } else if (state == AppLifecycleState.paused) {
      mapkit.onStop();
    }
  }

  @override
  void onCameraPositionChanged(
    Map map,
    CameraPosition position,
    CameraUpdateReason reason,
    bool finished,
  ) {
    _updateFogOverlay();
  }

  void _onMapCreated(MapWindow mapWindow) {
    _mapWindow = mapWindow;

    mapWindow.scaleFactor = MediaQuery.of(context).devicePixelRatio;

    final map = mapWindow.map;

    map.hdModeEnabled = false;
    map.awesomeModelsEnabled = false;
    map.indoorEnabled = false;
    map.nightModeEnabled = false; // по желанию
    map.set2DMode(true);          // сильно снижает нагрузку

    map.addCameraListener(this);

    map.move(
      const CameraPosition(
        _initialPoint,
        zoom: 12.0,
        azimuth: 0.0,
        tilt: 0.0,
      ),
    );

    _startTracking();
  }

  Future<void> _startTracking() async {
    final status = await Permission.location.request();
    if (!status.isGranted || _mapWindow == null) return;

    final initial = await Geolocator.getCurrentPosition();
    _handleNewPosition(initial, centerCamera: true);

    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // минимальный интервал в метрах для получения обновлений
      ),
      ).listen((pos) => _handleNewPosition(pos, centerCamera: false));
  }

  void _handleNewPosition(Position pos, {required bool centerCamera}) {
    final newPoint = Point(latitude: pos.latitude, longitude: pos.longitude);

    final shouldRecord= _exploredPoints.isEmpty ||
      _distanceMeters(_exploredPoints.last, newPoint) >= _kMinStepMeters;

    if(shouldRecord) {
      _exploredPoints.add(newPoint);
    }

    _userPoint = newPoint;

    if(centerCamera) {
      _mapWindow!.map.move(
        CameraPosition(
          _userPoint!,
          zoom: 15.0,
          azimuth: 0.0,
          tilt: 0.0,
        ),
        animation: const Animation(type: AnimationType.Smooth, duration: 1.5),
      );
    }
    _updateUserPlacemark();

    _updateFogOverlay();
  }

  Future<void> _centreOnUser() async {
    if(_userPoint == null) {
      await _startTracking();
      return;
    }
    _mapWindow?.map.move(
      CameraPosition(
          _userPoint!,
          zoom: 15.0,
          azimuth: 0.0,
          tilt: 0.0,
        ),
        animation: const Animation(type: AnimationType.Smooth, duration: 1),
    );
  }

  Future<Uint8List> _buildDotIcon({
    double size = 48,
    Color fill = const Color(0xFF2196F3),
    Color ring = Colors.white,
    Color shadow = const Color(0x662196F3), 
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final c = Offset(size / 2, size / 2);

    canvas.drawCircle(
      c,
      size * 0.5,
      Paint()
      ..color = shadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
    );

    canvas.drawCircle(c, size * 0.4, Paint()..color = ring);

    canvas.drawCircle(c, size * 0.25, Paint()..color = fill);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> _updateUserPlacemark() async {
    final mapWindow = _mapWindow;
    final userPoint = _userPoint;
    if(mapWindow == null || userPoint == null) return;

    if(_userPlacemark == null) {
      final pngBytes = await _buildDotIcon();

      _userPlacemark = mapWindow.map.mapObjects.addPlacemark();
      _userPlacemark!
      ..geometry = userPoint
      ..setIconWithStyle(
        ymk_image.ImageProvider.fromImageProvider(MemoryImage(pngBytes)), 
        IconStyle(
          anchor: const math.Point(0.5, 0.5),
          scale: 1,
          zIndex: 10,
        )
        );
    } else {
      _userPlacemark!.geometry = userPoint;
    }
  }

  void _updateFogOverlay() {
    final mapWindow = _mapWindow;
    if(mapWindow == null || _exploredPoints.isEmpty) return;

    final scale = mapWindow.scaleFactor;

    final screenPositions = <Offset>[];

    for (final geoPoint in _exploredPoints) {
      final sp = mapWindow.worldToScreen(geoPoint);

      if(sp != null) screenPositions.add(Offset(sp.x / scale, sp.y / scale));
    }

    final refPoint = _exploredPoints.last;
    const metersPerDegreeLat = 111_000;
    final northPoint = Point(
      latitude: refPoint.latitude + _kVisibleRadiusMeters / metersPerDegreeLat,
      longitude: refPoint.longitude
      );
    final refSp = mapWindow.worldToScreen(refPoint);
    final northSp = mapWindow.worldToScreen(northPoint);

    double radiusPx = 80;
    if(refSp != null && northSp != null) {
      final dx = (northSp.x - refSp.x) / scale;
      final dy = (northSp.y - refSp.y) / scale;
      radiusPx = math.sqrt(dx * dx + dy * dy);
    }

    setState(() {
      _exploredScreenPositions = screenPositions;
      _fogRadiusPx = radiusPx;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          YandexMap(onMapCreated: _onMapCreated),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _FogPainter(
                  exploredPositions: _exploredScreenPositions,
                  radiusInPixels: _fogRadiusPx,
                  ),
                ),
              ),
          ),
          Positioned(
            bottom: 32,
            right: 16,
            child: FloatingActionButton(
              onPressed: _centreOnUser,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}

class _FogPainter extends CustomPainter {
  const _FogPainter({
    required this.exploredPositions,
    required this.radiusInPixels,
  });

  final List<Offset> exploredPositions;
  final double radiusInPixels;

  static const double _fogOpacity = 0.8;

  static const double _clearStop = 0.7;

  static const double _featherStop = 1;
  
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (exploredPositions.isEmpty) {
      canvas.drawRect(
        rect,
        Paint()..color = Colors.black.withValues(alpha: _fogOpacity)
        );
        return;
    }

    canvas.saveLayer(rect, Paint());

    canvas.drawRect(
      rect, 
      Paint()..color = Colors.black.withValues(alpha: _fogOpacity)
      );

      for(final centre in exploredPositions) {
        final circleRect = Rect.fromCircle(
          center: centre,
          radius: radiusInPixels,
        );

        final gradientPaint = Paint()
        ..blendMode = BlendMode.dstOut
        ..shader = RadialGradient(
          colors: const [
            Colors.white,
            Colors.white,
            Color(0x00FFFFFF),
          ],
          stops: const [0, _clearStop, _featherStop],
          ).createShader(circleRect);
    
        canvas.drawCircle(centre, radiusInPixels, gradientPaint);
      }
      

      canvas.restore();

  }
  
  @override
  bool shouldRepaint(_FogPainter old) =>
    old.exploredPositions != exploredPositions || old.radiusInPixels != radiusInPixels;
  
}