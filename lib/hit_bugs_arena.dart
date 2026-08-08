import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'base_jesture_game.dart';
import 'score_manager.dart';
import 'sound_manager.dart';

// ─── Bug Types ───────────────────────────────────────────────────────────────
enum BugType { fly, mosquito, hornet, toxicBeetle }

/// HitBugsArena: Standalone bug-swatting game arena.
/// Features:
/// - 1-hand entry and big Tom & Jerry cartoon swatter bat
/// - Continuous endless play until 40 bugs are swatted (no game over from missing bugs)
/// - Distinct species art (Mosquito, Housefly, Hornet, Toxic Beetle)
/// - Category-wise live stats tracking
/// - Lag-free pre-cached rendering and capped decals
class HitBugsArena extends BaseJestureGame {
  @override
  String get gameTitle => 'Hit Bugs';

  @override
  int get requiredHandsCount => 1;

  @override
  String get distanceValidationTitle => 'HAND DETECTION';

  @override
  String get distanceValidationInstruction => 'Raise ONE hand to hold the Big Cartoon Fly Swatter.';

  double _spawnTimer = 0.0;
  int bugsSwatted = 0;
  final ValueNotifier<int> bugsSwattedNotifier = ValueNotifier<int>(0);

  // Live category-wise kill statistics for Top HUD
  final ValueNotifier<Map<BugType, int>> bugStatsNotifier = ValueNotifier<Map<BugType, int>>({
    BugType.fly: 0,
    BugType.mosquito: 0,
    BugType.hornet: 0,
    BugType.toxicBeetle: 0,
  });

  HitBugsArena()
      : super(
          customLeftFist: FistTrackerComponent(Colors.transparent),
          customRightFist: TomJerrySwatterComponent(),
        );

  @override
  void updateFistPositions(double leftX, double leftY, double rightX, double rightY) {
    super.updateFistPositions(leftX, leftY, rightX, rightY);
    if (isDistanceValidating || isGameOver) return;

    // Single bat controller: smoothly follows whichever hand is detected
    if (rightX >= 0 && rightY >= 0) {
      rightFist.targetPosition = Vector2(rightX * size.x, rightY * size.y);
      leftFist.targetPosition = Vector2(-2000, -2000);
    } else if (leftX >= 0 && leftY >= 0) {
      rightFist.targetPosition = Vector2(leftX * size.x, leftY * size.y);
      leftFist.targetPosition = Vector2(-2000, -2000);
    } else {
      rightFist.targetPosition = Vector2(-2000, -2000);
      leftFist.targetPosition = Vector2(-2000, -2000);
    }
  }

  @override
  void clearArena() {
    children.whereType<FlyingBugComponent>().forEach((b) => b.removeFromParent());
    children.whereType<GreenBloodSplatComponent>().forEach((s) => s.removeFromParent());
    children.whereType<ScorePopup>().forEach((p) => p.removeFromParent());
    _spawnTimer = 0.0;
  }

  @override
  void startDistanceValidation() {
    bugsSwatted = 0;
    bugsSwattedNotifier.value = 0;
    bugStatsNotifier.value = {
      BugType.fly: 0,
      BugType.mosquito: 0,
      BugType.hornet: 0,
      BugType.toxicBeetle: 0,
    };
    super.startDistanceValidation();
  }

  @override
  void resetGame() {
    bugsSwatted = 0;
    bugsSwattedNotifier.value = 0;
    bugStatsNotifier.value = {
      BugType.fly: 0,
      BugType.mosquito: 0,
      BugType.hornet: 0,
      BugType.toxicBeetle: 0,
    };
    super.resetGame();
  }

  /// In Hit Bugs, missing a bug never decreases lives or ends the game.
  /// The game continues smoothly until 40 bugs are swatted.
  @override
  void onBallMissed() {
    // No-op for Hit Bugs: play continues without interruption
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isDistanceValidating || isGameOver) return;

    // Level 3 Paywall when player swats 40 bugs
    if (bugsSwatted >= 40) {
      isGameOver = true;
      isPlayingNotifier.value = false;
      showOnlyOverlay('Paywall');
      onGameEndRequested?.call();
      return;
    }

    _spawnTimer += dt;

    // Dynamic spawn pacing based on bug swat progress (1.6s ramping to 0.7s)
    final double progress = (bugsSwatted / 40.0).clamp(0.0, 1.0);
    final double spawnInterval = 1.6 - (progress * 0.9);

    if (_spawnTimer >= spawnInterval) {
      _spawnTimer = 0;

      final double timeToLive = 3.6 - (progress * 1.1);

      // Random spawn side: left, right, or top
      final int edge = random.nextInt(3);
      Vector2 spawnPos;
      Vector2 baseVelocity;

      if (edge == 0) {
        // Spawn Left
        spawnPos = Vector2(-50, random.nextDouble() * (size.y - 320) + 120);
        baseVelocity = Vector2(random.nextDouble() * 130 + 90, (random.nextDouble() - 0.5) * 110);
      } else if (edge == 1) {
        // Spawn Right
        spawnPos = Vector2(size.x + 50, random.nextDouble() * (size.y - 320) + 120);
        baseVelocity = Vector2(-(random.nextDouble() * 130 + 90), (random.nextDouble() - 0.5) * 110);
      } else {
        // Spawn Top
        spawnPos = Vector2(random.nextDouble() * (size.x - 120) + 60, -50);
        baseVelocity = Vector2((random.nextDouble() - 0.5) * 150, random.nextDouble() * 130 + 90);
      }

      // Bug species selection based on probability roll
      BugType type;
      final double roll = random.nextDouble();
      if (roll < 0.38) {
        type = BugType.fly;
      } else if (roll < 0.68) {
        type = BugType.mosquito;
      } else if (roll < 0.86) {
        type = BugType.hornet;
      } else {
        type = BugType.toxicBeetle;
      }

      add(FlyingBugComponent(
        spawnPosition: spawnPos,
        baseVelocity: baseVelocity,
        maxTimeToLive: timeToLive,
        type: type,
      ));
    }
  }

  void onBugSwatted(Vector2 bugPos, BugType type, int points, Color pointColor) {
    bugsSwatted++;
    bugsSwattedNotifier.value = bugsSwatted;

    // Update category-wise stats
    final updated = Map<BugType, int>.from(bugStatsNotifier.value);
    updated[type] = (updated[type] ?? 0) + 1;
    bugStatsNotifier.value = updated;

    // Persist lifetime insect swat record
    ScoreManager.recordBugKill(type.name);

    incrementScore(points);
    SoundManager.instance.playPunch();
    HapticFeedback.mediumImpact();

    // Trigger zap burst on swatter
    if (rightFist is TomJerrySwatterComponent) {
      (rightFist as TomJerrySwatterComponent).triggerShockZap();
    }

    // 1. Floating score popup
    add(ScorePopup(
      position: bugPos + Vector2(0, -35),
      points: points,
      color: pointColor,
    ));

    // 2. Add green blood splat decal (enforce max 5 active decals for zero lag)
    final existingSplats = children.whereType<GreenBloodSplatComponent>().toList();
    if (existingSplats.length >= 5) {
      existingSplats.first.removeFromParent();
    }
    add(GreenBloodSplatComponent(position: bugPos.clone()));

    // 3. Fast particle droplet burst (14 lightweight particles)
    final rng = Random();
    add(ParticleSystemComponent(
      position: bugPos.clone(),
      particle: Particle.generate(
        count: 14,
        lifespan: 0.6,
        generator: (i) {
          final angle = rng.nextDouble() * 2 * pi;
          final speed = rng.nextDouble() * 320 + 80;
          final dir = Vector2(cos(angle), sin(angle)) * speed;
          final color = rng.nextBool()
              ? const Color(0xFF39FF14) // Neon Green
              : (rng.nextBool() ? const Color(0xFF76FF03) : const Color(0xFF00E676));
          return AcceleratedParticle(
            position: Vector2.zero(),
            speed: dir,
            acceleration: Vector2(0, 360),
            child: CircleParticle(
              radius: rng.nextDouble() * 4.0 + 2.0,
              paint: Paint()..color = color.withValues(alpha: 0.85),
            ),
          );
        },
      ),
    ));

    // Check Paywall trigger after 40 bugs
    if (bugsSwatted >= 40) {
      isGameOver = true;
      isPlayingNotifier.value = false;
      showOnlyOverlay('Paywall');
      onGameEndRequested?.call();
    }
  }
}

// ─── Floating Score Popup ─────────────────────────────────────────────────────
class ScorePopup extends PositionComponent {
  final int points;
  final Color color;
  double _life = 0.0;
  static const double _duration = 0.75;

  ScorePopup({required Vector2 position, required this.points, required this.color}) {
    this.position = position;
    anchor = Anchor.center;
    priority = 200;
  }

  @override
  void update(double dt) {
    _life += dt;
    position.y -= 85 * dt;
    if (_life >= _duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final double t = (_life / _duration).clamp(0.0, 1.0);
    final double alpha = t < 0.5 ? 1.0 : (1.0 - (t - 0.5) / 0.5);
    final double scale = t < 0.15 ? (t / 0.15) * 1.15 : 1.0;

    final textStyle = TextStyle(
      color: color.withValues(alpha: alpha),
      fontSize: 28 * scale,
      fontWeight: FontWeight.w900,
      shadows: [
        Shadow(color: Colors.black.withValues(alpha: alpha * 0.9), blurRadius: 6, offset: const Offset(1, 2)),
      ],
    );
    final textSpan = TextSpan(text: '+$points', style: textStyle);
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }
}

// ─── Green Blood / Slime Splat Decal ──────────────────────────────────────────
class GreenBloodSplatComponent extends PositionComponent {
  double _life = 0.0;
  static const double _duration = 1.2;
  late final List<Offset> _splatBlobs;
  late final List<double> _blobRadii;
  late final double _splatRotation;

  // Cached paints for performance
  static final Paint _neonPaint = Paint()
    ..color = const Color(0xFF39FF14)
    ..style = PaintingStyle.fill;

  static final Paint _corePaint = Paint()
    ..color = const Color(0xFF1B5E20)
    ..style = PaintingStyle.fill;

  GreenBloodSplatComponent({required Vector2 position}) {
    this.position = position;
    anchor = Anchor.center;
    priority = 5;

    final rng = Random();
    _splatRotation = rng.nextDouble() * pi * 2;
    _splatBlobs = [];
    _blobRadii = [];

    // Central blob
    _splatBlobs.add(Offset.zero);
    _blobRadii.add(rng.nextDouble() * 10 + 16);

    // 5-7 splatter droplets
    final int dropletCount = rng.nextInt(3) + 5;
    for (int i = 0; i < dropletCount; i++) {
      final double angle = rng.nextDouble() * pi * 2;
      final double dist = rng.nextDouble() * 28 + 10;
      _splatBlobs.add(Offset(cos(angle) * dist, sin(angle) * dist));
      _blobRadii.add(rng.nextDouble() * 6 + 3);
    }
  }

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= _duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final double t = (_life / _duration).clamp(0.0, 1.0);
    final double alpha = t < 0.6 ? 1.0 : (1.0 - (t - 0.6) / 0.4);

    canvas.save();
    canvas.rotate(_splatRotation);

    _neonPaint.color = const Color(0xFF39FF14).withValues(alpha: alpha * 0.85);
    _corePaint.color = const Color(0xFF1B5E20).withValues(alpha: alpha * 0.80);

    for (int i = 0; i < _splatBlobs.length; i++) {
      final r = _blobRadii[i];
      canvas.drawCircle(_splatBlobs[i], r, _neonPaint);
      canvas.drawCircle(_splatBlobs[i], r * 0.55, _corePaint);
    }

    canvas.restore();
  }
}

// ─── Flying Distinct Bug Component ───────────────────────────────────────────
class FlyingBugComponent extends PositionComponent with CollisionCallbacks {
  final Vector2 baseVelocity;
  final double maxTimeToLive;
  double _timeRemaining;
  final BugType type;

  double _life = 0.0;
  late final double _bugRadius;
  late final int _points;
  late final Color _themeColor;
  late final double _sineFreq;
  late final double _sineAmp;

  FlyingBugComponent({
    required Vector2 spawnPosition,
    required this.baseVelocity,
    required this.maxTimeToLive,
    required this.type,
  }) : _timeRemaining = maxTimeToLive {
    position = spawnPosition;
    anchor = Anchor.center;

    final rng = Random();
    _sineFreq = rng.nextDouble() * 3.5 + 4.5;
    _sineAmp = rng.nextDouble() * 26.0 + 16.0;

    switch (type) {
      case BugType.fly:
        _bugRadius = 26.0;
        _points = 15;
        _themeColor = const Color(0xFF00E5FF);
        break;
      case BugType.mosquito:
        _bugRadius = 24.0;
        _points = 20;
        _themeColor = const Color(0xFFFF5252);
        break;
      case BugType.hornet:
        _bugRadius = 28.0;
        _points = 35;
        _themeColor = const Color(0xFFFFD600);
        break;
      case BugType.toxicBeetle:
        _bugRadius = 32.0;
        _points = 50;
        _themeColor = const Color(0xFF39FF14);
        break;
    }

    size = Vector2.all(_bugRadius * 2.8);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(CircleHitbox(
      radius: _bugRadius * 1.15,
      anchor: Anchor.center,
      position: Vector2(_bugRadius * 1.4, _bugRadius * 1.4),
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    _timeRemaining -= dt;

    // Movement: base velocity + buzzing sine wobble
    final double perpX = -baseVelocity.y;
    final double perpY = baseVelocity.x;
    final double perpLen = sqrt(perpX * perpX + perpY * perpY) + 0.001;
    final double wobble = sin(_life * _sineFreq) * _sineAmp;

    position.x += (baseVelocity.x + (perpX / perpLen) * wobble) * dt;
    position.y += (baseVelocity.y + (perpY / perpLen) * wobble) * dt;

    // Rotate bug towards motion
    final double moveDir = atan2(baseVelocity.y, baseVelocity.x);
    angle = moveDir + pi / 2;

    // Miss condition: In Hit Bugs, simply remove the bug silently with no life loss
    if (_timeRemaining <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final double center = _bugRadius * 1.4;
    final double flap = sin(_life * 45); // wing flap

    canvas.save();
    canvas.translate(center, center);

    switch (type) {
      case BugType.mosquito:
        _renderMosquito(canvas, flap);
        break;
      case BugType.fly:
        _renderHousefly(canvas, flap);
        break;
      case BugType.hornet:
        _renderHornet(canvas, flap);
        break;
      case BugType.toxicBeetle:
        _renderToxicBeetle(canvas, flap);
        break;
    }

    canvas.restore();
  }

  // 🦟 MOSQUITO: Needle proboscis, spindly bent legs, red blood abdomen, narrow wings
  void _renderMosquito(Canvas canvas, double flap) {
    final legPaint = Paint()
      ..color = const Color(0xFF424242)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    // 6 spindly bent legs
    for (int i = -1; i <= 1; i++) {
      final yOffset = i * _bugRadius * 0.28;
      // Left leg (bent)
      final leftLeg = Path()
        ..moveTo(-_bugRadius * 0.2, yOffset)
        ..lineTo(-_bugRadius * 0.75, yOffset - 8)
        ..lineTo(-_bugRadius * 1.15, yOffset + 14);
      canvas.drawPath(leftLeg, legPaint);

      // Right leg (bent)
      final rightLeg = Path()
        ..moveTo(_bugRadius * 0.2, yOffset)
        ..lineTo(_bugRadius * 0.75, yOffset - 8)
        ..lineTo(_bugRadius * 1.15, yOffset + 14);
      canvas.drawPath(rightLeg, legPaint);
    }

    // Narrow fluttering wings
    final wingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    final wingStroke = Paint()
      ..color = const Color(0xFFFF8A80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.save();
    canvas.translate(-_bugRadius * 0.25, -_bugRadius * 0.1);
    canvas.scale(flap * 0.9, 1.0);
    final lWing = Rect.fromCenter(center: Offset(-_bugRadius * 0.6, -_bugRadius * 0.2), width: _bugRadius * 1.2, height: _bugRadius * 0.45);
    canvas.drawOval(lWing, wingPaint);
    canvas.drawOval(lWing, wingStroke);
    canvas.restore();

    canvas.save();
    canvas.translate(_bugRadius * 0.25, -_bugRadius * 0.1);
    canvas.scale(-flap * 0.9, 1.0);
    final rWing = Rect.fromCenter(center: Offset(_bugRadius * 0.6, -_bugRadius * 0.2), width: _bugRadius * 1.2, height: _bugRadius * 0.45);
    canvas.drawOval(rWing, wingPaint);
    canvas.drawOval(rWing, wingStroke);
    canvas.restore();

    // Swollen Blood-Filled Red Abdomen
    final abdomenPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, _bugRadius * 0.9),
        [const Color(0xFFD50000), const Color(0xFFFF1744)],
      );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, _bugRadius * 0.42), width: _bugRadius * 0.6, height: _bugRadius * 0.95),
      abdomenPaint,
    );

    // Thorax
    final thoraxPaint = Paint()..color = const Color(0xFF263238);
    canvas.drawCircle(Offset(0, -_bugRadius * 0.15), _bugRadius * 0.32, thoraxPaint);

    // Head
    final headPaint = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawCircle(Offset(0, -_bugRadius * 0.52), _bugRadius * 0.22, headPaint);

    // Glowing Compound Eyes
    final eyePaint = Paint()..color = Colors.redAccent;
    canvas.drawCircle(Offset(-_bugRadius * 0.14, -_bugRadius * 0.56), _bugRadius * 0.09, eyePaint);
    canvas.drawCircle(Offset(_bugRadius * 0.14, -_bugRadius * 0.56), _bugRadius * 0.09, eyePaint);

    // Sharp Needle Proboscis (Blood Syringe)
    final needlePaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawLine(Offset(0, -_bugRadius * 0.65), Offset(0, -_bugRadius * 1.25), needlePaint);
  }

  // 🪰 HOUSEFLY: Huge ruby eyes, iridescent stout body, clear double wings
  void _renderHousefly(Canvas canvas, double flap) {
    // Broad vibrating wings
    final wingPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    final wingStroke = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.save();
    canvas.translate(-_bugRadius * 0.3, -_bugRadius * 0.1);
    canvas.scale(flap * 0.85, 1.0);
    final lWing = Rect.fromCenter(center: Offset(-_bugRadius * 0.7, -_bugRadius * 0.25), width: _bugRadius * 1.3, height: _bugRadius * 0.75);
    canvas.drawOval(lWing, wingPaint);
    canvas.drawOval(lWing, wingStroke);
    canvas.restore();

    canvas.save();
    canvas.translate(_bugRadius * 0.3, -_bugRadius * 0.1);
    canvas.scale(-flap * 0.85, 1.0);
    final rWing = Rect.fromCenter(center: Offset(_bugRadius * 0.7, -_bugRadius * 0.25), width: _bugRadius * 1.3, height: _bugRadius * 0.75);
    canvas.drawOval(rWing, wingPaint);
    canvas.drawOval(rWing, wingStroke);
    canvas.restore();

    // Plump Iridescent Abdomen
    final abdomenPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, _bugRadius * 0.1),
        Offset(0, _bugRadius * 0.8),
        [const Color(0xFF263238), const Color(0xFF00B0FF)],
      );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, _bugRadius * 0.45), width: _bugRadius * 0.95, height: _bugRadius * 1.0),
      abdomenPaint,
    );

    // Bristle segments
    final bristlePaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(-_bugRadius * 0.35, _bugRadius * 0.35), Offset(_bugRadius * 0.35, _bugRadius * 0.35), bristlePaint);
    canvas.drawLine(Offset(-_bugRadius * 0.3, _bugRadius * 0.58), Offset(_bugRadius * 0.3, _bugRadius * 0.58), bristlePaint);

    // Thorax
    final thoraxPaint = Paint()..color = const Color(0xFF37474F);
    canvas.drawCircle(Offset(0, -_bugRadius * 0.1), _bugRadius * 0.45, thoraxPaint);

    // Giant Ruby Compound Eyes
    final rubyEyePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(-_bugRadius * 0.22, -_bugRadius * 0.55),
        _bugRadius * 0.25,
        [const Color(0xFFFF1744), const Color(0xFF880E4F)],
      );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-_bugRadius * 0.22, -_bugRadius * 0.55), width: _bugRadius * 0.42, height: _bugRadius * 0.5),
      rubyEyePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(_bugRadius * 0.22, -_bugRadius * 0.55), width: _bugRadius * 0.42, height: _bugRadius * 0.5),
      rubyEyePaint,
    );
  }

  // 🐝 HORNET / WASP: Striped yellow-black abdomen with stinger, predatory posture
  void _renderHornet(Canvas canvas, double flap) {
    // Sharp predatory wings
    final wingPaint = Paint()
      ..color = const Color(0xFFFFEE58).withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    final wingStroke = Paint()
      ..color = const Color(0xFFFFD600)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.save();
    canvas.translate(-_bugRadius * 0.3, -_bugRadius * 0.15);
    canvas.scale(flap * 0.9, 1.0);
    final lWing = Rect.fromCenter(center: Offset(-_bugRadius * 0.75, -_bugRadius * 0.3), width: _bugRadius * 1.4, height: _bugRadius * 0.55);
    canvas.drawOval(lWing, wingPaint);
    canvas.drawOval(lWing, wingStroke);
    canvas.restore();

    canvas.save();
    canvas.translate(_bugRadius * 0.3, -_bugRadius * 0.15);
    canvas.scale(-flap * 0.9, 1.0);
    final rWing = Rect.fromCenter(center: Offset(_bugRadius * 0.75, -_bugRadius * 0.3), width: _bugRadius * 1.4, height: _bugRadius * 0.55);
    canvas.drawOval(rWing, wingPaint);
    canvas.drawOval(rWing, wingStroke);
    canvas.restore();

    // Pointed Yellow-Black Striped Abdomen
    final abdomenPath = Path()
      ..moveTo(-_bugRadius * 0.4, _bugRadius * 0.15)
      ..lineTo(_bugRadius * 0.4, _bugRadius * 0.15)
      ..lineTo(0, _bugRadius * 0.95)
      ..close();
    final yellowPaint = Paint()..color = const Color(0xFFFFD600);
    canvas.drawPath(abdomenPath, yellowPaint);

    // Black stripes
    final stripePaint = Paint()
      ..color = const Color(0xFF212121)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(-_bugRadius * 0.38, _bugRadius * 0.25, _bugRadius * 0.76, _bugRadius * 0.14), stripePaint);
    canvas.drawRect(Rect.fromLTWH(-_bugRadius * 0.28, _bugRadius * 0.48, _bugRadius * 0.56, _bugRadius * 0.14), stripePaint);
    canvas.drawRect(Rect.fromLTWH(-_bugRadius * 0.16, _bugRadius * 0.70, _bugRadius * 0.32, _bugRadius * 0.12), stripePaint);

    // Venomous Stinger Needle
    final stingerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawLine(Offset(0, _bugRadius * 0.92), Offset(0, _bugRadius * 1.22), stingerPaint);

    // Thorax (black & yellow collar)
    final thoraxPaint = Paint()..color = const Color(0xFF212121);
    canvas.drawCircle(Offset(0, -_bugRadius * 0.1), _bugRadius * 0.42, thoraxPaint);

    // Head
    final headPaint = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawCircle(Offset(0, -_bugRadius * 0.52), _bugRadius * 0.32, headPaint);

    // Glowing Golden Predatory Eyes
    final eyePaint = Paint()..color = const Color(0xFFFFEA00);
    canvas.drawCircle(Offset(-_bugRadius * 0.20, -_bugRadius * 0.58), _bugRadius * 0.12, eyePaint);
    canvas.drawCircle(Offset(_bugRadius * 0.20, -_bugRadius * 0.58), _bugRadius * 0.12, eyePaint);

    // Curved Antennae
    final antPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawLine(Offset(-_bugRadius * 0.12, -_bugRadius * 0.7), Offset(-_bugRadius * 0.35, -_bugRadius * 1.05), antPaint);
    canvas.drawLine(Offset(_bugRadius * 0.12, -_bugRadius * 0.7), Offset(_bugRadius * 0.35, -_bugRadius * 1.05), antPaint);
  }

  // 🪲 TOXIC BEETLE: Armored emerald shell, mandibles, heavy carapace
  void _renderToxicBeetle(Canvas canvas, double flap) {
    // Underwing whir
    final wingPaint = Paint()
      ..color = const Color(0xFF69F0AE).withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(-_bugRadius * 0.4, -_bugRadius * 0.1);
    canvas.scale(flap * 0.8, 1.0);
    final lWing = Rect.fromCenter(center: Offset(-_bugRadius * 0.75, -_bugRadius * 0.2), width: _bugRadius * 1.3, height: _bugRadius * 0.6);
    canvas.drawOval(lWing, wingPaint);
    canvas.restore();

    canvas.save();
    canvas.translate(_bugRadius * 0.4, -_bugRadius * 0.1);
    canvas.scale(-flap * 0.8, 1.0);
    final rWing = Rect.fromCenter(center: Offset(_bugRadius * 0.75, -_bugRadius * 0.2), width: _bugRadius * 1.3, height: _bugRadius * 0.6);
    canvas.drawOval(rWing, wingPaint);
    canvas.restore();

    // Armored Carapace Shell (Metallic Emerald Gradient)
    final carapacePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(-_bugRadius * 0.6, 0),
        Offset(_bugRadius * 0.6, _bugRadius * 0.9),
        [const Color(0xFF00E676), const Color(0xFF1B5E20)],
      );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, _bugRadius * 0.42), width: _bugRadius * 1.15, height: _bugRadius * 1.15),
      carapacePaint,
    );

    // Carapace Wing-Case Center Seam
    final seamPaint = Paint()
      ..color = const Color(0xFF003300)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawLine(Offset(0, _bugRadius * 0.05), Offset(0, _bugRadius * 0.98), seamPaint);

    // Toxic Bioluminescent Dots
    final glowDotPaint = Paint()..color = const Color(0xFF69F0AE);
    canvas.drawCircle(Offset(-_bugRadius * 0.3, _bugRadius * 0.35), _bugRadius * 0.09, glowDotPaint);
    canvas.drawCircle(Offset(_bugRadius * 0.3, _bugRadius * 0.35), _bugRadius * 0.09, glowDotPaint);
    canvas.drawCircle(Offset(-_bugRadius * 0.24, _bugRadius * 0.62), _bugRadius * 0.07, glowDotPaint);
    canvas.drawCircle(Offset(_bugRadius * 0.24, _bugRadius * 0.62), _bugRadius * 0.07, glowDotPaint);

    // Heavy Armored Thorax
    final thoraxPaint = Paint()..color = const Color(0xFF1B5E20);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, -_bugRadius * 0.15), width: _bugRadius * 0.9, height: _bugRadius * 0.5), thoraxPaint);

    // Head with Mandible Pincers
    final headPaint = Paint()..color = const Color(0xFF003300);
    canvas.drawCircle(Offset(0, -_bugRadius * 0.52), _bugRadius * 0.36, headPaint);

    // Mandibles
    final mandiblePaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;
    final leftMandible = Path()
      ..moveTo(-_bugRadius * 0.2, -_bugRadius * 0.65)
      ..lineTo(-_bugRadius * 0.45, -_bugRadius * 0.95)
      ..lineTo(-_bugRadius * 0.25, -_bugRadius * 1.15);
    final rightMandible = Path()
      ..moveTo(_bugRadius * 0.2, -_bugRadius * 0.65)
      ..lineTo(_bugRadius * 0.45, -_bugRadius * 0.95)
      ..lineTo(_bugRadius * 0.25, -_bugRadius * 1.15);
    canvas.drawPath(leftMandible, mandiblePaint);
    canvas.drawPath(rightMandible, mandiblePaint);
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is FistTrackerComponent) {
      final game = findGame() as HitBugsArena?;
      if (game != null) {
        game.onBugSwatted(position.clone(), type, _points, _themeColor);
      }
      removeFromParent();
    }
  }
}

// ─── Big Cartoon Tom & Jerry Style Fly Swatter Bat Component ─────────────────
class TomJerrySwatterComponent extends FistTrackerComponent {
  double _sparkTimer = 0.0;
  double _zapShockTimer = 0.0;

  // Oversized, cartoon proportions (like Tom swatting Jerry)
  static const double swatterWidth = 155.0;
  static const double swatterHeight = 225.0;

  // Cached paint instances
  static final Paint _glowPaint = Paint()
    ..color = const Color(0xFFFF1744).withValues(alpha: 0.35)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

  static final Paint _paddleBorderPaint = Paint()
    ..color = const Color(0xFFD50000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6.0;

  static final Paint _paddleFillPaint = Paint()
    ..color = const Color(0xFFFF5252).withValues(alpha: 0.75)
    ..style = PaintingStyle.fill;

  static final Paint _ribCrossPaint = Paint()
    ..color = const Color(0xFFB71C1C)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5;

  static final Paint _holePaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.50)
    ..style = PaintingStyle.fill;

  static final Paint _handlePaint = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(0, swatterHeight * 0.72),
      const Offset(0, swatterHeight),
      [const Color(0xFF8D6E63), const Color(0xFF4E342E)],
    );

  static final Paint _ferrulePaint = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(0, swatterHeight * 0.68),
      const Offset(0, swatterHeight * 0.73),
      [const Color(0xFFFFD54F), const Color(0xFFFF8F00)],
    );

  static final Paint _shaftPaint = Paint()
    ..color = const Color(0xFFECEFF1)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0;

  static final Paint _pommelPaint = Paint()
    ..color = const Color(0xFF3E2723)
    ..style = PaintingStyle.fill;

  static final Paint _gripWrapPaint = Paint()
    ..color = const Color(0xFFFF1744)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.8;

  TomJerrySwatterComponent() : super(const Color(0xFFFF1744)) {
    size = Vector2(swatterWidth, swatterHeight);
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    // Generous oversized hitbox matching the giant cartoon swatter head
    add(CircleHitbox(
      radius: swatterWidth * 0.46,
      anchor: Anchor.center,
      position: Vector2(swatterWidth / 2, swatterHeight * 0.34),
    ));
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Dynamic screen-size scaling: scales down on smaller phones, max size on tablets.
    // Minimum scale 0.65 ensures it remains a big bat and doesn't become tiny like a fist.
    final double scaleFactor = (size.x / 750.0).clamp(0.65, 1.0);
    scale = Vector2.all(scaleFactor);
  }

  void triggerShockZap() {
    _zapShockTimer = 0.28;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _sparkTimer += dt * 14;
    if (_zapShockTimer > 0) {
      _zapShockTimer -= dt;
    }
  }

  @override
  void render(Canvas canvas) {
    if (position.x == -2000) return;

    const headCenter = Offset(swatterWidth / 2, swatterHeight * 0.34);
    const paddleRect = Rect.fromLTWH(
      (swatterWidth - 130) / 2,
      12,
      130,
      swatterHeight * 0.44,
    );
    final paddleRRect = RRect.fromRectAndRadius(paddleRect, const Radius.circular(16));

    // ── 1. Turned Wooden Handle with Pommel Knob ──────────────────────────────
    final handleRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(swatterWidth / 2, swatterHeight * 0.85),
        width: 26,
        height: swatterHeight * 0.26,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(handleRRect, _handlePaint);

    // Pommel knob at bottom
    canvas.drawCircle(const Offset(swatterWidth / 2, swatterHeight * 0.98), 15.0, _pommelPaint);

    // Red grip wraps on handle
    for (double y = swatterHeight * 0.77; y <= swatterHeight * 0.92; y += 9.0) {
      canvas.drawLine(Offset(swatterWidth / 2 - 11, y), Offset(swatterWidth / 2 + 11, y + 3), _gripWrapPaint);
    }

    // Brass metal collar / ferrule
    final ferruleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(swatterWidth / 2, swatterHeight * 0.70),
        width: 28,
        height: 14,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(ferruleRect, _ferrulePaint);

    // ── 2. Dual Spring-Steel Connecting Shafts ───────────────────────────────
    // Left steel stem
    canvas.drawLine(
      const Offset(swatterWidth / 2 - 12, swatterHeight * 0.69),
      const Offset(swatterWidth / 2 - 16, swatterHeight * 0.46),
      _shaftPaint,
    );
    // Right steel stem
    canvas.drawLine(
      const Offset(swatterWidth / 2 + 12, swatterHeight * 0.69),
      const Offset(swatterWidth / 2 + 16, swatterHeight * 0.46),
      _shaftPaint,
    );

    // ── 3. Giant Cartoon Swatter Head (Tom & Jerry Style) ─────────────────────
    // Glow aura
    canvas.drawRRect(paddleRRect, _glowPaint);

    // Solid colorful paddle face
    canvas.drawRRect(paddleRRect, _paddleFillPaint);

    // Molded reinforcement crossbars
    canvas.drawLine(
      Offset(paddleRect.left + 8, headCenter.dy),
      Offset(paddleRect.right - 8, headCenter.dy),
      _ribCrossPaint,
    );
    canvas.drawLine(
      Offset(headCenter.dx, paddleRect.top + 8),
      Offset(headCenter.dx, paddleRect.bottom - 8),
      _ribCrossPaint,
    );
    // Diagonal reinforcement struts
    canvas.drawLine(
      Offset(paddleRect.left + 12, paddleRect.top + 12),
      Offset(paddleRect.right - 12, paddleRect.bottom - 12),
      _ribCrossPaint,
    );
    canvas.drawLine(
      Offset(paddleRect.right - 12, paddleRect.top + 12),
      Offset(paddleRect.left + 12, paddleRect.bottom - 12),
      _ribCrossPaint,
    );

    // Perforated hole matrix (4x4 matrix of classic swatter ventilation holes)
    for (double row = paddleRect.top + 18; row <= paddleRect.bottom - 18; row += 22) {
      for (double col = paddleRect.left + 18; col <= paddleRect.right - 18; col += 24) {
        canvas.drawCircle(Offset(col, row), 4.5, _holePaint);
      }
    }

    // Bold outer cartoon rim
    canvas.drawRRect(paddleRRect, _paddleBorderPaint);

    // ── 4. Dynamic Electric ZAP / WHACK! Sparks ───────────────────────────────
    final double phase = sin(_sparkTimer);
    final sparkPath = Path();
    sparkPath.moveTo(headCenter.dx - 36, headCenter.dy + phase * 14);
    sparkPath.lineTo(headCenter.dx - 12, headCenter.dy - phase * 18);
    sparkPath.lineTo(headCenter.dx + 14, headCenter.dy + phase * 16);
    sparkPath.lineTo(headCenter.dx + 38, headCenter.dy - phase * 12);

    final sparkPaint = Paint()
      ..color = _zapShockTimer > 0 ? Colors.yellowAccent : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = _zapShockTimer > 0 ? 4.5 : 2.2;
    canvas.drawPath(sparkPath, sparkPaint);

    // Zap flash rays when hitting bug
    if (_zapShockTimer > 0) {
      final zapFlashPaint = Paint()
        ..color = Colors.yellowAccent.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      for (int i = 0; i < 6; i++) {
        final double angle = (i * pi / 3) + _sparkTimer;
        canvas.drawLine(
          headCenter + Offset(cos(angle) * 35, sin(angle) * 35),
          headCenter + Offset(cos(angle) * 62, sin(angle) * 62),
          zapFlashPaint,
        );
      }
    }
  }
}
