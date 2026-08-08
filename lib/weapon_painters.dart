import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math';

/// Renders a highly realistic glossy red boxing glove
void paintBoxingGlove(Canvas canvas, Size size, double cx, double cy, {bool isLeft = true}) {
  final double scale = size.width / 100.0;
  canvas.save();
  canvas.translate(cx, cy);
  canvas.scale(scale, scale);
  if (isLeft) {
    canvas.scale(-1, 1); // mirror left glove to face right
  }

  // Base shadow
  canvas.drawOval(
    const Rect.fromLTWH(-35, -20, 70, 70),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
  );

  // Main glove body (Glossy Red)
  final bodyPath = Path();
  bodyPath.moveTo(-20, -35); // top left
  bodyPath.quadraticBezierTo(0, -45, 25, -30); // top curve
  bodyPath.quadraticBezierTo(45, -10, 40, 20); // right side
  bodyPath.lineTo(25, 45); // bottom right wrist
  bodyPath.lineTo(-25, 45); // bottom left wrist
  bodyPath.quadraticBezierTo(-35, 10, -35, -10); // left side
  bodyPath.close();

  final bodyPaint = Paint()
    ..shader = ui.Gradient.radial(
      const Offset(-10, -15),
      50,
      [const Color(0xFFFF5252), const Color(0xFFD32F2F), const Color(0xFFB71C1C)],
      [0.0, 0.6, 1.0],
    );
  canvas.drawPath(bodyPath, bodyPaint);

  // Big specular highlight (the glossy reflection on the top left)
  final highlightPath = Path();
  highlightPath.moveTo(-25, -20);
  highlightPath.quadraticBezierTo(-10, -35, 5, -25);
  highlightPath.quadraticBezierTo(0, -15, -15, -10);
  highlightPath.close();
  canvas.drawPath(
    highlightPath,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );

  // Thumb nub (attached to the side, facing inwards)
  final thumbPath = Path();
  thumbPath.moveTo(-15, -5);
  thumbPath.quadraticBezierTo(10, 15, 15, 30);
  thumbPath.quadraticBezierTo(-5, 40, -15, 30);
  thumbPath.quadraticBezierTo(-25, 20, -15, -5);
  thumbPath.close();
  
  canvas.drawPath(
    thumbPath,
    Paint()
      ..shader = ui.Gradient.radial(
        const Offset(-10, 15), 30,
        [const Color(0xFFFF1744), const Color(0xFFB71C1C)],
      ),
  );

  // Crease between thumb and main body
  final creasePaint = Paint()
    ..color = const Color(0xFF880000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(const Offset(-15, 0), const Offset(5, 25), creasePaint);
  
  // Stitched crevice in the middle (like the palm opening)
  final crevicePath = Path();
  crevicePath.moveTo(0, 5);
  crevicePath.quadraticBezierTo(15, 25, 5, 40);
  canvas.drawPath(crevicePath, Paint()..color = const Color(0xFF7F0000)..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round);
  canvas.drawPath(crevicePath, Paint()..color = const Color(0xFF3E0000)..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round);

  // Small stitching marks around the crevice
  final stitchPaint = Paint()..color = const Color(0xFFD32F2F)..style = PaintingStyle.stroke..strokeWidth = 1;
  for (int i = 0; i < 5; i++) {
    double y = 15.0 + i * 5;
    canvas.drawLine(Offset(2, y), Offset(8, y + 2), stitchPaint);
  }

  // Wrist Cuff
  final cuffRect = RRect.fromRectAndRadius(const Rect.fromLTWH(-28, 40, 56, 18), const Radius.circular(6));
  canvas.drawRRect(
    cuffRect,
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(-28, 40), const Offset(28, 58),
        [const Color(0xFFD32F2F), const Color(0xFFB71C1C)],
      ),
  );
  // Cuff highlight
  canvas.drawRRect(
    cuffRect,
    Paint()..color = Colors.white.withValues(alpha: 0.15)..style = PaintingStyle.stroke..strokeWidth = 2,
  );

  canvas.restore();
}

/// Renders a highly detailed Barbie-style gardening glove
void paintBarbieGlove(Canvas canvas, Size size, double cx, double cy, {bool isLeft = true}) {
  final double scale = size.width / 100.0;
  canvas.save();
  canvas.translate(cx, cy);
  canvas.scale(scale, scale);
  if (isLeft) {
    canvas.scale(-1, 1);
  }

  // Glove base silhouette (Wrist + back of hand is white)
  final basePath = Path();
  basePath.moveTo(-20, -50); // top left wrist
  basePath.lineTo(20, -50); // top right wrist
  basePath.quadraticBezierTo(25, -20, 35, 5); // right side down to pinky
  basePath.quadraticBezierTo(20, 45, 10, 40); // pinky finger
  basePath.quadraticBezierTo(15, 55, 0, 50); // ring finger
  basePath.quadraticBezierTo(0, 60, -10, 50); // middle finger
  basePath.quadraticBezierTo(-15, 50, -20, 30); // index finger
  basePath.quadraticBezierTo(-40, 10, -35, -5); // thumb
  basePath.quadraticBezierTo(-25, -20, -20, -50); // back up to wrist
  basePath.close();

  // Draw white canvas top
  canvas.drawPath(
    basePath,
    Paint()..color = const Color(0xFFF5F5F5)..style = PaintingStyle.fill,
  );

  // Draw colorful "Barbie" cursive text patterns on the white canvas
  canvas.save();
  canvas.clipPath(basePath);
  
  final textColors = [const Color(0xFFFF1493), const Color(0xFF00BFFF), const Color(0xFFFFD700)];
  final random = Random(42); // fixed seed for consistent pattern
  
  for (int i = 0; i < 15; i++) {
    final tp = TextPainter(
      text: TextSpan(
        text: 'Barbie',
        style: TextStyle(
          color: textColors[random.nextInt(textColors.length)].withValues(alpha: 0.8),
          fontSize: 12 + random.nextDouble() * 6,
          fontFamily: 'cursive', // fallback for script font
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    canvas.save();
    canvas.translate(-30.0 + random.nextDouble() * 60, -40.0 + random.nextDouble() * 70);
    canvas.rotate((random.nextDouble() - 0.5) * 1.5);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }
  canvas.restore();

  // Draw the hot pink rubber palm/fingers coating overlapping the bottom half
  final rubberPath = Path();
  rubberPath.moveTo(-42, 5); // thumb tip
  rubberPath.quadraticBezierTo(-25, -10, -15, 5); // thumb joint crotch
  rubberPath.quadraticBezierTo(0, -5, 15, -5); // palm line across
  rubberPath.quadraticBezierTo(40, 5, 35, 20); // right edge
  // Trace the bottom fingers roughly
  rubberPath.quadraticBezierTo(20, 50, 10, 45); // pinky
  rubberPath.quadraticBezierTo(15, 60, 0, 50); // ring
  rubberPath.quadraticBezierTo(0, 65, -10, 50); // middle
  rubberPath.quadraticBezierTo(-20, 50, -20, 30); // index
  rubberPath.quadraticBezierTo(-30, 20, -40, 5); // back to thumb
  rubberPath.close();

  final rubberPaint = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(-20, 0), const Offset(20, 60),
      [const Color(0xFFFF1493), const Color(0xFFD81B60)],
    );
  
  // We intersect the rubber path with the base path so it stays within the glove lines
  final Path pinkPart = Path.combine(PathOperation.intersect, basePath, rubberPath);
  canvas.drawPath(pinkPart, rubberPaint);

  // Add some shadowing/texture to the rubber fingers
  canvas.drawPath(
    pinkPart,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );

  // Glove outline
  canvas.drawPath(
    basePath,
    Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = 1.5,
  );

  canvas.restore();
}

/// Renders a highly mechanical Iron Man repulsor glove
void paintIronManFist(Canvas canvas, Size size, double cx, double cy, {bool isLeft = true}) {
  final double scale = size.width / 100.0;
  canvas.save();
  canvas.translate(cx, cy);
  canvas.scale(scale, scale);
  if (isLeft) {
    canvas.scale(-1, 1);
  }

  const Color ironRed = Color(0xFFB71C1C);
  const Color ironLight = Color(0xFFE53935);
  const Color gold = Color(0xFFFFD700);
  const Color goldDark = Color(0xFFF57F17);
  const Color mechanicalDark = Color(0xFF212121);

  // Mechanical under-layer (black/dark grey)
  canvas.drawCircle(const Offset(0, 10), 32, Paint()..color = mechanicalDark);

  // Finger plates (spread out)
  void drawFinger(double dx, double dy, double angle, double length, double width) {
    canvas.save();
    canvas.translate(dx, dy);
    canvas.rotate(angle);
    
    // Finger base shadow
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(-width/2, -length, width, length), Radius.circular(width/2));
    canvas.drawRRect(rect, Paint()..color = mechanicalDark);
    
    // Red Armor plates on finger (segments)
    final platePaint = Paint()..shader = ui.Gradient.linear(Offset(-width/2, 0), Offset(width/2, 0), [ironLight, ironRed]);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-width/2+1, -length+2, width-2, length*0.4), Radius.circular(width/3)), platePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-width/2+1, -length*0.5+2, width-2, length*0.4), Radius.circular(width/3)), platePaint);
    
    // Gold knuckle joint at base
    canvas.drawCircle(const Offset(0, 0), width*0.6, Paint()..shader = ui.Gradient.radial(Offset.zero, width*0.6, [gold, goldDark]));
    
    canvas.restore();
  }

  // Draw fingers (thumb, index, middle, ring, pinky)
  drawFinger(-30, 0, -1.2, 35, 12); // Thumb
  drawFinger(-18, -20, -0.4, 40, 11); // Index
  drawFinger(0, -25, 0, 45, 12);     // Middle
  drawFinger(18, -20, 0.4, 40, 11);  // Ring
  drawFinger(32, -8, 0.9, 32, 10);   // Pinky

  // Main Palm Plate (Red with gold accents)
  final palmPath = Path();
  palmPath.moveTo(-25, -15); // top left
  palmPath.quadraticBezierTo(0, -25, 25, -15); // top edge
  palmPath.lineTo(35, 10); // right edge
  palmPath.lineTo(20, 45); // bottom right
  palmPath.lineTo(-20, 45); // bottom left
  palmPath.lineTo(-35, 10); // left edge
  palmPath.close();

  final palmPaint = Paint()
    ..shader = ui.Gradient.radial(
      const Offset(0, 10), 50,
      [ironLight, ironRed, const Color(0xFF7F0000)],
      [0.0, 0.6, 1.0],
    );
  canvas.drawPath(palmPath, palmPaint);

  // Gold accent lines on palm
  final goldStroke = Paint()..color = gold..style = PaintingStyle.stroke..strokeWidth = 2.5;
  canvas.drawPath(palmPath, goldStroke); // Outline
  
  // Palm paneling lines (cutouts)
  final panelPaint = Paint()..color = mechanicalDark..style = PaintingStyle.stroke..strokeWidth = 1.5;
  canvas.drawLine(const Offset(-20, 45), const Offset(-10, 10), panelPaint);
  canvas.drawLine(const Offset(20, 45), const Offset(10, 10), panelPaint);
  canvas.drawLine(const Offset(-25, -15), const Offset(-10, 10), panelPaint);
  canvas.drawLine(const Offset(25, -15), const Offset(10, 10), panelPaint);


  // Repulsor Ring Base
  canvas.drawCircle(const Offset(0, 10), 16, Paint()..color = const Color(0xFFBDBDBD));
  canvas.drawCircle(const Offset(0, 10), 14, Paint()..color = const Color(0xFF424242));
  
  // Repulsor Glow
  final repulsorGlow = Paint()
    ..color = const Color(0xFF40C4FF).withValues(alpha: 0.8)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  canvas.drawCircle(const Offset(0, 10), 18, repulsorGlow);

  // Repulsor Core Light (White/Cyan gradient)
  final repulsorCore = Paint()
    ..shader = ui.Gradient.radial(
      const Offset(0, 10),
      12,
      [Colors.white, const Color(0xFF84FFFF), const Color(0xFF00E5FF)],
      [0.0, 0.5, 1.0],
    );
  canvas.drawCircle(const Offset(0, 10), 12, repulsorCore);

  // Wrist bolt
  canvas.drawCircle(const Offset(35, 10), 4, Paint()..color = const Color(0xFF616161));
}

/// Generates a pre-rendered Image for the boxing glove to save GPU cycles on old devices.
Future<ui.Image> createBoxingGloveImage(double size, {bool isLeft = true}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paintBoxingGlove(canvas, Size(size, size), size / 2, size / 2, isLeft: isLeft);
  final picture = recorder.endRecording();
  return await picture.toImage(size.toInt(), size.toInt());
}

/// Generates a pre-rendered Image for the barbie glove to save GPU cycles on old devices.
Future<ui.Image> createBarbieGloveImage(double size, {bool isLeft = true}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paintBarbieGlove(canvas, Size(size, size), size / 2, size / 2, isLeft: isLeft);
  final picture = recorder.endRecording();
  return await picture.toImage(size.toInt(), size.toInt());
}

/// Generates a pre-rendered Image for the Iron Man glove to save GPU cycles on old devices.
Future<ui.Image> createIronManGloveImage(double size, {bool isLeft = true}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paintIronManFist(canvas, Size(size, size), size / 2, size / 2, isLeft: isLeft);
  final picture = recorder.endRecording();
  return await picture.toImage(size.toInt(), size.toInt());
}

/// A CustomPainter that paints the appropriate glove for the weapon selector UI
class WeaponPreviewPainter extends CustomPainter {
  final dynamic weaponType;
  const WeaponPreviewPainter(this.weaponType);

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // Use dynamic to avoid circular import issues, or just match by index/name
    // In motion_game_arena WeaponType enum: 0=boxing, 1=barbie, 2=ironMan
    if (weaponType.index == 0) {
      paintBoxingGlove(canvas, size, cx, cy, isLeft: true);
    } else if (weaponType.index == 1) {
      paintBarbieGlove(canvas, size, cx, cy, isLeft: true);
    } else if (weaponType.index == 2) {
      paintIronManFist(canvas, size, cx, cy, isLeft: true);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
