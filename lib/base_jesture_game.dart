import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/collisions.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'score_manager.dart';

abstract class BaseJestureGame extends FlameGame with HasCollisionDetection {
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> livesNotifier = ValueNotifier<int>(20);
  
  int get score => scoreNotifier.value;
  set score(int value) => scoreNotifier.value = value;
  
  int get lives => livesNotifier.value;
  set lives(int value) => livesNotifier.value = value;

  double speedMultiplier = 1.0;
  bool isGameOver = true;
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);

  String get gameTitle;

  bool isDistanceValidating = false;
  final ValueNotifier<String> distanceStatusNotifier = ValueNotifier<String>('Searching...');
  double goodDistanceTimer = 0.0;

  final ValueNotifier<int> countdownNotifier = ValueNotifier<int>(0);
  TimerComponent? countdownTimerComp;

  late final FistTrackerComponent leftFist;
  late final FistTrackerComponent rightFist;
  final Random random = Random();

  BaseJestureGame() {
    leftFist = FistTrackerComponent(Colors.blueAccent);
    rightFist = FistTrackerComponent(Colors.redAccent);
  }

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    addAll([leftFist, rightFist]);
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
    
    countdownTimerComp = TimerComponent(
      period: 1.0,
      repeat: true,
      onTick: () {
        countdownNotifier.value--;
        if (countdownNotifier.value <= 0) {
          countdownTimerComp?.timer.stop();
          if (countdownTimerComp != null) remove(countdownTimerComp!);
          overlays.remove('Countdown');
          startGame();
        }
      }
    );
    add(countdownTimerComp!);
  }

  void startGame() {
    isGameOver = false;
    isPlayingNotifier.value = true;
    
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
    isPlayingNotifier.value = false;
    lives = 20;
    speedMultiplier = 1.0;
    score = 0;
    clearArena();
    startCountdown();
  }
  
  void resumeFromAd() {
    lives = 20;
    clearArena();
    startCountdown();
  }

  // To be implemented by subclasses to remove game-specific elements
  void clearArena();

  void onBallMissed() {
    if (isGameOver) return;
    lives--;
    HapticFeedback.vibrate();
    
    if (lives <= 0) {
      isGameOver = true;
      isPlayingNotifier.value = false;
      ScoreManager.saveScore(gameTitle, score);
      overlays.add('GameOver');
    }
  }

  void updateFullPose(Pose pose, double scale, double offsetX, double offsetY, double inputWidth) {
    if (isDistanceValidating) {
      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
      
      if (leftShoulder != null && rightShoulder != null && leftShoulder.likelihood > 0.5 && rightShoulder.likelihood > 0.5) {
        double shoulderDist = (leftShoulder.x - rightShoulder.x).abs() / inputWidth;
        if (shoulderDist < 0.12) {
          distanceStatusNotifier.value = 'Move Closer';
        } else if (shoulderDist > 0.50) {
          distanceStatusNotifier.value = 'Move Further Back';
        } else {
          distanceStatusNotifier.value = 'Perfect! Hold still...';
        }
      } else {
        distanceStatusNotifier.value = 'Searching for body...';
      }
      return; 
    }

    if (isGameOver) return;
    
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final leftIndex = pose.landmarks[PoseLandmarkType.leftIndex];
    if (leftWrist != null && leftIndex != null && leftWrist.likelihood > 0.4 && leftIndex.likelihood > 0.4) {
      double fistX = (leftWrist.x + leftIndex.x) / 2;
      double fistY = (leftWrist.y + leftIndex.y) / 2;
      double scaledX = (inputWidth - fistX) * scale - offsetX;
      double scaledY = fistY * scale - offsetY;
      leftFist.targetPosition = Vector2(scaledX, scaledY);
    } else {
      leftFist.targetPosition = Vector2(-2000, -2000);
    }
    
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final rightIndex = pose.landmarks[PoseLandmarkType.rightIndex];
    if (rightWrist != null && rightIndex != null && rightWrist.likelihood > 0.4 && rightIndex.likelihood > 0.4) {
      double fistX = (rightWrist.x + rightIndex.x) / 2;
      double fistY = (rightWrist.y + rightIndex.y) / 2;
      double scaledX = (inputWidth - fistX) * scale - offsetX;
      double scaledY = fistY * scale - offsetY;
      rightFist.targetPosition = Vector2(scaledX, scaledY);
    } else {
      rightFist.targetPosition = Vector2(-2000, -2000);
    }
  }
  
  void incrementScore(int addedPoints) {
    score += addedPoints;
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
  }
}

class FistTrackerComponent extends PositionComponent with CollisionCallbacks {
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
  Future<void> onLoad() async {
    super.onLoad();
    add(CircleHitbox(radius: radius, anchor: Anchor.center, position: Vector2(radius, radius)));
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
    final double maxMovePerFrame = 10000.0 * dt; 
    
    if (distance > maxMovePerFrame) {
      final direction = (targetPosition - _smoothedPosition).normalized();
      _smoothedPosition += direction * maxMovePerFrame;
    } else {
      final double lerpFactor = 1.0 - exp(-25.0 * dt);
      _smoothedPosition.lerp(targetPosition, lerpFactor); 
    }
    
    position = _smoothedPosition.clone();
  }

  @override
  void render(Canvas canvas) {
    if (position.x == -2000) return; 
    final center = Offset(radius, radius);
    canvas.drawCircle(center, radius + 10, _glowPaint);
    canvas.drawCircle(center, radius, _corePaint);
  }
}
