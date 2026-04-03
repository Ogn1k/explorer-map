import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit_lite/init.dart' as mapkit_init;
import 'map_screen.dart';

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
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initMapKit();
  }

  Future<void> _initMapKit() async {
    try {
      await mapkit_init
          .initMapkit(apiKey: '0da56748-63b4-4560-a3b2-d47703c46f76')
          .timeout(const Duration(seconds: 15));
    } catch (e, s) {
      debugPrint('MapKit init failed: $e');
      debugPrint('$s');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'World Explorer',
      theme: ThemeData.dark(),
      home: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text(
                  'MapKit init error:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return const MapScreen();
        },
      ),
    );
  }
}
