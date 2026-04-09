import 'package:flutter/material.dart' hide Animation;
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as ymk
    hide Icon, Rect, LocationSettings;
import 'package:yandex_maps_mapkit_lite/mapkit_factory.dart';
import 'package:yandex_maps_mapkit_lite/yandex_map.dart';

import '../services/marker_service.dart';
import '../services/zone_service.dart';
import '../widgets/zone_drawer.dart';
import 'fog_painter.dart';
import 'location_controller.dart';
import 'map_controller.dart';
import 'marker_controller.dart';

class MapScreen extends StatefulWidget {
  final ZoneService zoneService;
  final MarkerService markerService;

  const MapScreen({
    super.key,
    required this.zoneService,
    required this.markerService,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with WidgetsBindingObserver
    implements ymk.MapInputListener {
  // Drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  final GlobalKey<ZoneDrawerState> _drawerKey = GlobalKey();
  String? _highlinghtedZoneId;

  late final MapController _mapController = MapController(
    zoneService: widget.zoneService,
    sizeProvider: () => MediaQuery.of(context).size,
    onCameraChanged: _rebuild,
  );

  late final LocationController _locationController = LocationController(
    mapWindowGetter: () => _mapController.mapWindow,
    onUpdated: _rebuild,
  );

  late final MarkerController _markerController = MarkerController(
    markerService: widget.markerService,
    locationController: _locationController,
    mapWindowGetter: () => _mapController.mapWindow,
    onUpdated: _rebuild,
  );

  // Lifecycle

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    mapkit.onStart();
    widget.zoneService.addListener(_onZonesChanged);
    widget.markerService.addListener(_onMarkersChanged);
  }

  @override
  void dispose() {
    _locationController.dispose();
    _mapController.mapWindow?.map.removeInputListener(this);
    _mapController.mapWindow?.map.removeCameraListener(_mapController);
    widget.zoneService.removeListener(_onZonesChanged);
    widget.markerService.removeListener(_onMarkersChanged);
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

  void _rebuild() => mounted ? setState(() {}) : null;

  void _onZonesChanged() => _rebuild();

  void _onMarkersChanged() {
    _markerController.syncMarkers();
    _rebuild();
  }

  // MapInputListener

  @override
  void onMapTap(ymk.Map map, ymk.Point point) async {
    final zone =
        await widget.zoneService.getZoneAt(point.latitude, point.longitude);
    setState(() => _highlinghtedZoneId = zone.id);
    _scaffoldKey.currentState?.openDrawer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drawerKey.currentState?.scrollToZone(zone.id);
    });
  }

  @override
  void onMapLongTap(ymk.Map map, ymk.Point point) {
    _markerController.handleLongTap(point, context);
  }

  // Map creation

  void _onMapCreated(ymk.MapWindow mapWindow) {
    _mapController.onMapCreated(
      mapWindow,
      MediaQuery.of(context).devicePixelRatio,
    );
    mapWindow.map.addInputListener(this);

    _locationController.startTracking(centerCamera: true);
    _mapController.preloadCurrentViewport();
    _markerController.syncMarkers();
  }

  // Build

  @override
  Widget build(BuildContext context) {
    final mapWindow = _mapController.mapWindow;

    return Scaffold(
      key: _scaffoldKey,
      drawer: ZoneDrawer(
        key: _drawerKey,
        zoneService: widget.zoneService,
        highlightId: _highlinghtedZoneId,
      ),
      body: Stack(
        children: [
          // Base map
          YandexMap(onMapCreated: _onMapCreated),

          // Fog overlay
          if (mapWindow != null)
            Positioned.fill(
              child: RepaintBoundary(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: FogPainter(
                      mapWindow: mapWindow,
                      zoneService: widget.zoneService,
                      cameraPosition: mapWindow.map.cameraPosition,
                      scaleFactor: mapWindow.scaleFactor,
                    ),
                  ),
                ),
              ),
            ),

          // FABs
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'layers',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              tooltip: 'Зоны',
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            bottom: 32,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'location',
              onPressed: _centreOnUser,
              tooltip: 'Моя позиция',
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _centreOnUser() async {
    if (_locationController.userPoint == null) {
      await _locationController.startTracking(centerCamera: true);
      return;
    }
    _mapController.mapWindow?.map.move(
      ymk.CameraPosition(
        _locationController.userPoint!,
        zoom: 15.0,
        azimuth: 0.0,
        tilt: 0.0,
      ),
      animation: const ymk.Animation(
        type: ymk.AnimationType.Smooth,
        duration: 1,
      ),
    );
  }
}
