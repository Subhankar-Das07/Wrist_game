import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flame/collisions.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
enum BallType { standard, fast, golden }

class MotionGameArena extends FlameGame with HasCollisionDetection {
  late final TextComponent _livesText;
  late final TextComponent _scoreText;
  
  int score = 0;
  int lives = 20;
  double speedMultiplier = 1.0;
  bool _isGameOver = true;

  final ValueNotifier<int> countdownNotifier = ValueNotifier<int>(0);
  TimerComponent? _countdownTimer;

  final FistTrackerComponent _leftFist = FistTrackerComponent(Colors.blueAccent);
  final FistTrackerComponent _rightFist = FistTrackerComponent(Colors.redAccent);
  final Random _random = Random();
  double _spawnTimer = 0.0;

  MotionGameArena();

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    _livesText = TextComponent(
      text: '❤️ 20',
      position: Vector2(size.x - 30, 40),
      anchor: Anchor.topRight,
      textRenderer: TextPaint(style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 28, fontWeight: FontWeight.bold)),
    );
    
    _scoreText = TextComponent(
      text: '★ 0',
      position: Vector2(30, 40),
      anchor: Anchor.topLeft,
      textRenderer: TextPaint(style: TextStyle(color: Colors.yellowAccent.withOpacity(0.9), fontSize: 32, fontWeight: FontWeight.bold)),
    );

    addAll([_livesText, _scoreText, _leftFist, _rightFist]);
  }

  void startCountdown() {
    countdownNotifier.value = 5;
    overlays.add('Countdown');
    
    _countdownTimer = TimerComponent(
      period: 1.0,
      repeat: true,
      onTick: () {
        countdownNotifier.value--;
        if (countdownNotifier.value <= 0) {
          _countdownTimer?.timer.stop();
          if (_countdownTimer != null) remove(_countdownTimer!);
          overlays.remove('Countdown');
          startGame();
        }
      }
    );
    add(_countdownTimer!);
  }

  void startGame() {
    _isGameOver = false;
    
    // Flash Visual Effect
    final flash = RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.white,
      priority: 100, // Ensure it's on top
    );
    flash.add(OpacityEffect.fadeOut(
      LinearEffectController(0.8),
      onComplete: () => flash.removeFromParent(),
    ));
    add(flash);
    HapticFeedback.heavyImpact();
  }

  void resetGame() {
    lives = 20;
    speedMultiplier = 1.0;
    score = 0;
    _scoreText.text = '★ 0';
    _livesText.text = '❤️ 20';
    children.whereType<TargetBall>().forEach((b) => b.removeFromParent());
    startCountdown();
  }
  
  void resumeFromAd() {
    lives = 20;
    _livesText.text = '❤️ 20';
    // Remove existing balls to give player a clean slate
    children.whereType<TargetBall>().forEach((b) => b.removeFromParent());
    startCountdown();
  }

  void onBallMissed() {
    if (_isGameOver) return;
    lives--;
    _livesText.text = '❤️ $lives';
    HapticFeedback.vibrate();
    
    if (lives <= 0) {
      _isGameOver = true;
      overlays.add('AdBreak');
    }
  }

  void updateFullPose(Pose pose, double scale, double offsetX, double offsetY, double inputWidth) {
    if (_isGameOver) return;
    
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final leftIndex = pose.landmarks[PoseLandmarkType.leftIndex];
    if (leftWrist != null && leftIndex != null && leftWrist.likelihood > 0.4 && leftIndex.likelihood > 0.4) {
      double fistX = (leftWrist.x + leftIndex.x) / 2;
      double fistY = (leftWrist.y + leftIndex.y) / 2;
      double scaledX = (inputWidth - fistX) * scale - offsetX;
      double scaledY = fistY * scale - offsetY;
      _leftFist.targetPosition = Vector2(scaledX, scaledY);
    } else {
      _leftFist.targetPosition = Vector2(-2000, -2000);
    }
    
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final rightIndex = pose.landmarks[PoseLandmarkType.rightIndex];
    if (rightWrist != null && rightIndex != null && rightWrist.likelihood > 0.4 && rightIndex.likelihood > 0.4) {
      double fistX = (rightWrist.x + rightIndex.x) / 2;
      double fistY = (rightWrist.y + rightIndex.y) / 2;
      double scaledX = (inputWidth - fistX) * scale - offsetX;
      double scaledY = fistY * scale - offsetY;
      _rightFist.targetPosition = Vector2(scaledX, scaledY);
    } else {
      _rightFist.targetPosition = Vector2(-2000, -2000);
    }
  }
  
  void incrementScore(int addedPoints) {
    score += addedPoints;
    _scoreText.text = '★ $score';
    if (speedMultiplier < 2.5) {
      speedMultiplier += 0.02; // Increase difficulty over time
    }
    HapticFeedback.lightImpact();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isGameOver) return;

    _spawnTimer += dt;
    if (_spawnTimer > 0.70) {
      _spawnTimer = 0;
      final ballX = _random.nextDouble() * (size.x - 60) + 30;
      
      final double roll = _random.nextDouble();
      BallType type = BallType.standard;
      if (roll > 0.90) {
        type = BallType.golden;
      } else if (roll > 0.60) {
        type = BallType.fast;
      }
      
      add(TargetBall(Vector2(ballX, -50), type));
    }
  }
}

class FistTrackerComponent extends PositionComponent {
  final double radius = 30.0;
  late final Paint _corePaint;
  late final Paint _glowPaint;
  
  Vector2 targetPosition = Vector2(-2000, -2000);
  Vector2 _smoothedPosition = Vector2(-2000, -2000);

  FistTrackerComponent(Color color) {
    size = Vector2.all(radius * 2);
    anchor = Anchor.center;
    
    _corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
      
    _glowPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15.0);
      
    position = targetPosition.clone();
    _smoothedPosition = targetPosition.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (targetPosition.x == -2000) {
      position = targetPosition.clone();
      _smoothedPosition = targetPosition.clone();
      return;
    }
    
    if (_smoothedPosition.x == -2000) {
      _smoothedPosition = targetPosition.clone();
      position = _smoothedPosition.clone();
      return;
    }

    final double distance = _smoothedPosition.distanceTo(targetPosition);
    final double maxMovePerFrame = 200.0;
    Vector2 clampedTarget = targetPosition;
    
    if (distance > maxMovePerFrame) {
       final direction = (targetPosition - _smoothedPosition).normalized();
       clampedTarget = _smoothedPosition + (direction * maxMovePerFrame);
    }
    
    final double smoothingFactor = 25.0; 
    _smoothedPosition.lerp(clampedTarget, 1.0 - exp(-smoothingFactor * dt));
    
    position = _smoothedPosition.clone();
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(CircleHitbox(radius: radius, anchor: Anchor.center, position: Vector2(radius, radius)));
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset(radius, radius), radius * 1.6, _glowPaint);
    canvas.drawCircle(Offset(radius, radius), radius * 0.7, _corePaint);
  }
}

class TargetBall extends PositionComponent with CollisionCallbacks {
  final BallType type;
  late final double radius;
  late final double speed;
  late final int points;
  late final Paint _paint;
  
  TargetBall(Vector2 startPosition, this.type) {
    position = startPosition;
    anchor = Anchor.center;
    
    switch (type) {
      case BallType.fast:
        radius = 25.0;
        speed = 500.0;
        points = 30;
        _paint = Paint()..color = Colors.purpleAccent;
        break;
      case BallType.golden:
        radius = 20.0;
        speed = 700.0;
        points = 50;
        _paint = Paint()..color = Colors.amberAccent;
        break;
      case BallType.standard:
      default:
        radius = 35.0;
        speed = 300.0;
        points = 15;
        _paint = Paint()..color = Colors.greenAccent;
        break;
    }
    size = Vector2.all(radius * 2);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(CircleHitbox(radius: radius, anchor: Anchor.center, position: Vector2(radius, radius)));
  }

  @override
  void update(double dt) {
    super.update(dt);
    final game = findGame() as MotionGameArena?;
    final double currentSpeed = speed * (game?.speedMultiplier ?? 1.0);
    
    position.y += currentSpeed * dt;
    if (position.y > 1500) {
      if (game != null) game.onBallMissed();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) => canvas.drawCircle(Offset(radius, radius), radius, _paint);

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    
    if (other is FistTrackerComponent) {
      final game = findGame() as MotionGameArena?;
      if (game != null) {
        game.incrementScore(points);
        
        final random = Random();
        game.add(ParticleSystemComponent(
          particle: Particle.generate(
            count: 14,
            lifespan: 0.4,
            generator: (i) => AcceleratedParticle(
              acceleration: Vector2(0, 150),
              speed: Vector2(random.nextDouble() * 300 - 150, random.nextDouble() * -300),
              position: position.clone(),
              child: CircleParticle(radius: 4, paint: Paint()..color = _paint.color),
            ),
          ),
        ));
      }
      removeFromParent();
    }
  }
}
