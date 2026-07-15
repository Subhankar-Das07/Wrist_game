import 'dart:math';
import 'dart:ui' as ui;
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

  bool isDistanceValidating = false;
  final ValueNotifier<String> distanceStatusNotifier = ValueNotifier<String>('Searching...');
  double goodDistanceTimer = 0.0;

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

  void startDistanceValidation() {
    isDistanceValidating = true;
    goodDistanceTimer = 0.0;
    distanceStatusNotifier.value = 'Analyzing pose...';
    overlays.add('DistanceValidation');
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
      overlays.add('GameOver');
    }
  }

  void updateFullPose(Pose pose, double scale, double offsetX, double offsetY, double inputWidth) {
    if (isDistanceValidating) {
      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
      
      if (leftShoulder != null && rightShoulder != null && leftShoulder.likelihood > 0.5 && rightShoulder.likelihood > 0.5) {
        double shoulderDist = (leftShoulder.x - rightShoulder.x).abs() / inputWidth;
        if (shoulderDist < 0.15) {
          distanceStatusNotifier.value = 'Move Closer';
        } else if (shoulderDist > 0.35) {
          distanceStatusNotifier.value = 'Move Further Back';
        } else {
          distanceStatusNotifier.value = 'Perfect! Hold still...';
        }
      } else {
        distanceStatusNotifier.value = 'Searching for body...';
      }
      return; // Do not update fists during validation
    }

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
    HapticFeedback.lightImpact();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isDistanceValidating) {
      if (distanceStatusNotifier.value == 'Perfect! Hold still...') {
        goodDistanceTimer += dt;
        if (goodDistanceTimer >= 3.0) {
          isDistanceValidating = false;
          overlays.remove('DistanceValidation');
          startCountdown();
        }
      } else {
        goodDistanceTimer = 0.0;
      }
      return;
    }

    if (_isGameOver) return;

    // Check for Paywall condition
    if (score >= 4000) {
      _isGameOver = true;
      overlays.add('Paywall');
      return;
    }

    _spawnTimer += dt;
    if (_spawnTimer > 0.70) {
      _spawnTimer = 0;
      final ballX = _random.nextDouble() * (size.x - 60) + 30;
      
      BallType type = BallType.standard;
      
      // Dynamic difficulty based on score
      double baseSpeed = (300 + (score / 10.0)).clamp(300, 700);
      double dx = 0;

      if (score < 500) {
        // Level 1: Straight down, slow
      } else if (score < 1500) {
        // Level 1.5: Random small X drift for SOME balls
        if (_random.nextDouble() > 0.5) {
          dx = _random.nextDouble() * 200 - 100;
        }
      } else if (score < 2000) {
        // Level 1.8: Faster, high X drift for wall bouncing
        if (_random.nextDouble() > 0.3) {
          dx = _random.nextDouble() * 600 - 300;
        }
      } else {
        // Level 2 (2000-4000): Fast balls, Yellow balls
        if (_random.nextDouble() > 0.2) {
          dx = _random.nextDouble() * 800 - 400;
        }
        
        final double roll = _random.nextDouble();
        if (roll > 0.85) {
          type = BallType.golden;
          baseSpeed *= 1.4;
        } else if (roll > 0.60) {
          type = BallType.fast;
          baseSpeed *= 1.2;
        }
      }
      
      Vector2 velocity = Vector2(dx, baseSpeed);
      add(TargetBall(Vector2(ballX, -50), type, velocity));
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
  Vector2 velocity;
  late final double radius;
  late final int points;
  late final Paint _paint;
  
  TargetBall(Vector2 startPosition, this.type, this.velocity) {
    position = startPosition;
    anchor = Anchor.center;
    
    switch (type) {
      case BallType.fast:
        radius = 25.0;
        points = 30;
        _paint = Paint()
          ..shader = ui.Gradient.radial(
            Offset(radius, radius), radius,
            [Colors.purpleAccent.shade100, Colors.deepPurple],
            [0.2, 1.0],
          );
        break;
      case BallType.golden:
        radius = 20.0;
        points = 50;
        _paint = Paint()
          ..shader = ui.Gradient.radial(
            Offset(radius, radius), radius,
            [Colors.white, Colors.amberAccent],
            [0.1, 1.0],
          );
        break;
      case BallType.standard:
      default:
        radius = 35.0;
        points = 15;
        _paint = Paint()
          ..shader = ui.Gradient.radial(
            Offset(radius, radius), radius,
            [Colors.lightGreenAccent, Colors.green],
            [0.4, 1.0],
          );
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
    final double mult = game?.speedMultiplier ?? 1.0;
    
    // Wall bouncing physics
    if (game != null) {
       if (position.x <= radius && velocity.x < 0) {
         velocity.x = -velocity.x;
       } else if (position.x >= game.size.x - radius && velocity.x > 0) {
         velocity.x = -velocity.x;
       }
    }
    
    position += (velocity * mult) * dt;
    
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
        
        // Custom explosion effects based on ball type
        final random = Random();
        int particleCount = type == BallType.golden ? 25 : (type == BallType.fast ? 18 : 12);
        double explodeSpeed = type == BallType.golden ? 400 : 250;
        
        game.add(ParticleSystemComponent(
          particle: Particle.generate(
            count: particleCount,
            lifespan: type == BallType.golden ? 0.6 : 0.4,
            generator: (i) => AcceleratedParticle(
              acceleration: Vector2(0, 150),
              speed: Vector2(random.nextDouble() * explodeSpeed * 2 - explodeSpeed, random.nextDouble() * -explodeSpeed),
              position: position.clone(),
              child: CircleParticle(radius: type == BallType.golden ? 6 : 4, paint: Paint()..color = _paint.color),
            ),
          ),
        ));
      }
      removeFromParent();
    }
  }
}
