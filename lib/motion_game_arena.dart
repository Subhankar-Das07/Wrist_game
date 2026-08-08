import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';

import 'weapon_painters.dart';
import 'base_jesture_game.dart';
import 'sound_manager.dart';

// 4 ball types — clean, fun, hittable
enum BallType { green, golden, redMini, bounce }

// ─── Weapon types selectable before each game ─────────────────────────────────
enum WeaponType { boxing, barbie, ironMan }

class MotionGameArena extends BaseJestureGame {
  @override
  String get gameTitle => 'Fall Ball';

  double _spawnTimer = 0.0;
  bool _introShownGolden = false;
  bool _introShownBounce = false;
  bool _introShownRedMini = false;

  WeaponType selectedWeapon = WeaponType.boxing;

  MotionGameArena();

  /// Swaps the fist weapon components to the selected weapon type.
  /// Call this before startDistanceValidation() to apply the chosen weapon.
  void applyWeapon(WeaponType type) {
    selectedWeapon = type;

    // Remove existing fist components from the game world if they have a parent
    if (leftFist.parent != null) leftFist.removeFromParent();
    if (rightFist.parent != null) rightFist.removeFromParent();

    // Build new weapon fists based on selection
    switch (type) {
      case WeaponType.boxing:
        leftFist = BoxingGloveFist(isLeft: true);
        rightFist = BoxingGloveFist(isLeft: false);
        break;
      case WeaponType.barbie:
        leftFist = BarbieGloveFist(isLeft: true);
        rightFist = BarbieGloveFist(isLeft: false);
        break;
      case WeaponType.ironMan:
        leftFist = IronManFist(isLeft: true);
        rightFist = IronManFist(isLeft: false);
        break;
    }

    // Reset positions off-screen
    leftFist.targetPosition = Vector2(-2000, -2000);
    rightFist.targetPosition = Vector2(-2000, -2000);

    // Add back to the game world
    addAll([leftFist, rightFist]);
  }

  @override
  void clearArena() {
    children.whereType<TargetBall>().forEach((b) => b.removeFromParent());
    children.whereType<ScorePopup>().forEach((p) => p.removeFromParent());
    _spawnTimer = 0;
    _introShownGolden = false;
    _introShownBounce = false;
    _introShownRedMini = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isDistanceValidating || isGameOver) return;

    // Paywall at 3000 points
    if (score >= 3000) {
      isGameOver = true;
      isPlayingNotifier.value = false;
      showOnlyOverlay('Paywall');
      onGameEndRequested?.call();
      return;
    }

    _spawnTimer += dt;

    // ── Phase-based spawn interval ───────────────────────────────────────────
    // 0-600: one new ball every 1.4s (calm intro, only green)
    // 600-2000: 1.1s (ramping, occasional specials)
    // 2000+: 0.75s (active mix)
    double spawnInterval;
    if (score < 600) {
      spawnInterval = 1.4;
    } else if (score < 2000) {
      final double t = (score - 600) / 1400.0;
      spawnInterval = 1.4 - t * 0.65; // 1.4 → 0.75
    } else {
      final double t = (score - 2000) / 1000.0;
      spawnInterval = 0.75 - (t * 0.25).clamp(0.0, 0.25); // 0.75 → 0.5
    }

    if (_spawnTimer >= spawnInterval) {
      _spawnTimer = 0;
      _spawnBall();
    }
  }

  void _spawnBall() {
    final BallType type = _chooseBallType();
    final double ballX = random.nextDouble() * (size.x - 100) + 50;
    add(TargetBall(Vector2(ballX, -60), type, size));
  }

  BallType _chooseBallType() {
    // ── Phase 1: 0–600 pts — only green, easy warm-up ───────────────────────
    if (score < 600) return BallType.green;

    // ── Phase 2: 600–2000 pts — green dominant, one intro of each special ───
    if (score < 2000) {
      // Introduce one golden ball around 650 pts
      if (score >= 650 && !_introShownGolden) {
        _introShownGolden = true;
        return BallType.golden;
      }
      // Introduce one bounce ball around 900 pts
      if (score >= 900 && !_introShownBounce) {
        _introShownBounce = true;
        return BallType.bounce;
      }
      // Introduce one red-mini ball around 1200 pts
      if (score >= 1200 && !_introShownRedMini) {
        _introShownRedMini = true;
        return BallType.redMini;
      }
      // After all intros, mostly green with occasional specials
      final double roll = random.nextDouble();
      if (roll < 0.70) return BallType.green;
      if (roll < 0.84) return BallType.golden;
      if (roll < 0.93) return BallType.bounce;
      return BallType.redMini;
    }

    // ── Phase 3: 2000+ pts — full random mix, all balls viable ─────────────
    final double roll = random.nextDouble();
    if (roll < 0.30) return BallType.green;
    if (roll < 0.57) return BallType.golden;
    if (roll < 0.78) return BallType.bounce;
    return BallType.redMini;
  }

  void spawnScorePopup(Vector2 position, int points, Color color) {
    add(ScorePopup(position: position.clone(), points: points, color: color));
  }
}

// ─── Floating score popup ────────────────────────────────────────────────────
class ScorePopup extends PositionComponent {
  final int points;
  final Color color;
  double _life = 0.0;
  static const double _duration = 0.9;

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
    final double alpha = t < 0.6 ? 1.0 : (1.0 - (t - 0.6) / 0.4);
    final double scale = t < 0.15
        ? (t / 0.15) * 1.3
        : (t < 0.3 ? 1.3 - (t - 0.15) / 0.15 * 0.3 : 1.0);

    final textSpan = TextSpan(
      text: '+$points',
      style: TextStyle(
        color: color.withValues(alpha: alpha),
        fontSize: 30 * scale,
        fontWeight: FontWeight.w900,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: alpha * 0.9),
            blurRadius: 8,
            offset: const Offset(1, 2),
          )
        ],
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }
}

// ─── Target Ball ─────────────────────────────────────────────────────────────
class TargetBall extends PositionComponent with CollisionCallbacks {
  final BallType type;
  final Vector2 arenaSize;
  Vector2 velocity = Vector2.zero();

  late final double radius;
  late final int points;
  late final Color pointColor;
  late final String _label;

  // Paint objects
  Paint? _fillPaint;

  TargetBall(Vector2 startPosition, this.type, this.arenaSize) {
    position = startPosition;
    anchor = Anchor.center;

    switch (type) {
      case BallType.golden:
        radius = 28.0;
        points = 60;
        pointColor = Colors.amberAccent;
        _label = 'GOLD';
        break;

      case BallType.redMini:
        radius = 18.0;
        points = 70;
        pointColor = Colors.redAccent;
        _label = '';
        break;

      case BallType.bounce:
        radius = 32.0;
        points = 50;
        pointColor = Colors.cyanAccent;
        _label = 'BOING';
        break;

      case BallType.green:
        radius = 35.0;
        points = 30;
        pointColor = Colors.lightGreenAccent;
        _label = '';
        break;
    }
    size = Vector2.all(radius * 2);
    _setupVelocity();
  }

  void _setupVelocity() {
    final rng = Random();

    // Base fall speed per type (all clearly hittable but distinct feel)
    double fallSpeed;
    double driftX = 0.0;

    switch (type) {
      case BallType.green:
        // Slow, straight — easy warm-up target
        fallSpeed = 160 + rng.nextDouble() * 30; // 160–190
        driftX = (rng.nextDouble() - 0.5) * 40; // very gentle drift
        break;

      case BallType.golden:
        // Medium — more interesting than green
        fallSpeed = 220 + rng.nextDouble() * 40; // 220–260
        driftX = (rng.nextDouble() - 0.5) * 80;
        break;

      case BallType.bounce:
        // Medium fall speed, strong horizontal — bounces wall to wall
        fallSpeed = 200 + rng.nextDouble() * 40; // 200–240
        driftX = (rng.nextBool() ? 1 : -1) * (350 + rng.nextDouble() * 150); // 350–500
        break;

      case BallType.redMini:
        // Fast fall but small so it feels fair — laser accuracy rewarded
        fallSpeed = 320 + rng.nextDouble() * 60; // 320–380
        driftX = (rng.nextDouble() - 0.5) * 60;
        break;
    }

    velocity = Vector2(driftX, fallSpeed);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Build gradient paint now that we're mounted (radius known)
    _fillPaint = _buildPaint();

    add(CircleHitbox(
      radius: radius,
      anchor: Anchor.center,
      position: Vector2(radius, radius),
    ));
  }

  Paint _buildPaint() {
    switch (type) {
      case BallType.golden:
        return Paint()
          ..shader = ui.Gradient.radial(
            Offset(radius, radius), radius,
            [Colors.white, Colors.amberAccent, Colors.orange.shade700],
            [0.0, 0.45, 1.0],
          );

      case BallType.redMini:
        return Paint()
          ..shader = ui.Gradient.radial(
            Offset(radius, radius), radius,
            [Colors.white, Colors.redAccent, Colors.red.shade900],
            [0.0, 0.4, 1.0],
          );

      case BallType.bounce:
        return Paint()
          ..shader = ui.Gradient.radial(
            Offset(radius, radius), radius,
            [Colors.white, Colors.cyanAccent, Colors.blue.shade700],
            [0.0, 0.4, 1.0],
          );

      case BallType.green:
        return Paint()
          ..shader = ui.Gradient.radial(
            Offset(radius, radius), radius,
            [Colors.white, Colors.lightGreenAccent, Colors.green.shade800],
            [0.0, 0.35, 1.0],
          );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Wall bounce for bounce type (and any ball drifting)
    if (position.x <= radius && velocity.x < 0) {
      velocity.x = -velocity.x;
    } else if (position.x >= arenaSize.x - radius && velocity.x > 0) {
      velocity.x = -velocity.x;
    }

    position += velocity * dt;

    // Missed: fell off bottom
    if (position.y > arenaSize.y + radius + 20) {
      final game = findGame() as BaseJestureGame?;
      if (game != null) game.onBallMissed();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_fillPaint == null) return;
    canvas.drawCircle(Offset(radius, radius), radius, _fillPaint!);

    // Specular highlight — top-left shimmer
    final highlightPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(radius * 0.55, radius * 0.45), radius * 0.4,
        [Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0.0)],
        [0.0, 1.0],
      );
    canvas.drawCircle(Offset(radius, radius), radius, highlightPaint);

    // Label for named types
    if (_label.isNotEmpty) {
      final textSpan = TextSpan(
        text: _label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: radius * 0.4,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(radius - tp.width / 2, radius - tp.height / 2));
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is FistTrackerComponent) {
      final game = findGame() as MotionGameArena?;
      if (game != null) {
        game.incrementScore(points);
        SoundManager.instance.playPunch();
        game.spawnScorePopup(position + Vector2(0, -radius - 10), points, pointColor);
        _spawnParticles(game);
      }
      removeFromParent();
    }
  }

  void _spawnParticles(BaseJestureGame game) {
    final rng = Random();
    final List<Color> colors;
    int count;
    double speed;

    switch (type) {
      case BallType.golden:
        colors = [Colors.amberAccent, Colors.white, Colors.orange];
        count = 22; speed = 380;
        SoundManager.instance.playGoldenHit();
        break;
      case BallType.redMini:
        colors = [Colors.redAccent, Colors.white, Colors.pinkAccent];
        count = 14; speed = 450;
        break;
      case BallType.bounce:
        colors = [Colors.cyanAccent, Colors.white, Colors.blueAccent];
        count = 18; speed = 340;
        break;
      case BallType.green:
        colors = [Colors.lightGreenAccent, Colors.white70];
        count = 12; speed = 260;
        break;
    }

    game.add(ParticleSystemComponent(
      position: position.clone(),
      particle: Particle.generate(
        count: count,
        lifespan: 0.55,
        generator: (i) {
          final angle = rng.nextDouble() * 2 * pi;
          final spd = rng.nextDouble() * speed + 50;
          final dir = Vector2(cos(angle), sin(angle)) * spd;
          final color = colors[rng.nextInt(colors.length)];
          return AcceleratedParticle(
            position: Vector2.zero(),
            speed: dir,
            child: CircleParticle(
              radius: rng.nextDouble() * 5 + 2,
              paint: Paint()..color = color.withValues(alpha: 0.88),
            ),
          );
        },
      ),
    ));
  }
}

// ─── 🥊 Boxing Glove Fist ─────────────────────────────────────────────────────
class BoxingGloveFist extends FistTrackerComponent {
  final bool isLeft;
  ui.Image? _cachedImage;

  BoxingGloveFist({required this.isLeft}) : super(Colors.transparent) {
    size = Vector2(80, 80);
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _cachedImage = await createBoxingGloveImage(size.x, isLeft: isLeft);
  }

  @override
  void render(Canvas canvas) {
    if (position.x == -2000 || _cachedImage == null) return;
    canvas.drawImage(_cachedImage!, Offset.zero, Paint());
  }
}

// ─── 💅 Barbie Glove Fist ─────────────────────────────────────────────────────
class BarbieGloveFist extends FistTrackerComponent {
  final bool isLeft;
  ui.Image? _cachedImage;

  BarbieGloveFist({required this.isLeft}) : super(Colors.transparent) {
    size = Vector2(80, 80);
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _cachedImage = await createBarbieGloveImage(size.x, isLeft: isLeft);
  }

  @override
  void render(Canvas canvas) {
    if (position.x == -2000 || _cachedImage == null) return;
    canvas.drawImage(_cachedImage!, Offset.zero, Paint());
  }
}

// ─── 🦾 Iron Man Fist ─────────────────────────────────────────────────────────
class IronManFist extends FistTrackerComponent {
  final bool isLeft;
  ui.Image? _cachedImage;

  IronManFist({required this.isLeft}) : super(Colors.transparent) {
    size = Vector2(80, 80);
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _cachedImage = await createIronManGloveImage(size.x, isLeft: isLeft);
  }

  @override
  void render(Canvas canvas) {
    if (position.x == -2000 || _cachedImage == null) return;
    canvas.drawImage(_cachedImage!, Offset.zero, Paint());
  }
}
