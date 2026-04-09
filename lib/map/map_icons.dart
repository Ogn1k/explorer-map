// lib/map/map_icons.dart

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class MapIcons {
  static Future<Uint8List> buildDotIcon({
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
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.drawCircle(c, size * 0.4, Paint()..color = ring);

    canvas.drawCircle(c, size * 0.25, Paint()..color = fill);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }
}
