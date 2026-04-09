import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit_lite/init.dart' as mapkit_init;

import 'db/database_helper.dart';
import 'map/map_screen.dart';
import 'services/marker_service.dart';
import 'services/natural_earth_service.dart';
import 'services/zone_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<_AppServices> _initFuture = _init();

  Future<_AppServices> _init() async {
    try {
      await mapkit_init
          .initMapkit(apiKey: '0da56748-63b4-4560-a3b2-d47703c46f76')
          .timeout(const Duration(seconds: 15));
    } catch (e, s) {
      debugPrint('MapKit init failed: $e');
      debugPrint('$s');
      rethrow;
    }
    await NaturalEarthService.instance.load();

    final db = DatabaseHelper.instance;

    final zoneService = ZoneService(db: db, ne: NaturalEarthService.instance);
    final markerService = MarkerService(db: db);
    await zoneService.init();
    await markerService.init();

    return _AppServices(
      zoneService: zoneService,
      markerService: markerService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Explorer',
      theme: ThemeData.dark(useMaterial3: true),
      home: FutureBuilder<_AppServices>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16)
                  ],
                )
              ),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text(
                  'Ошибка инициализации:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return MapScreen(
            zoneService: snapshot.data!.zoneService,
            markerService: snapshot.data!.markerService,
          );
        },
      ),
    );
  }
}

class _AppServices {
  final ZoneService zoneService;
  final MarkerService markerService;

  const _AppServices({
    required this.zoneService,
    required this.markerService,
  });
}
