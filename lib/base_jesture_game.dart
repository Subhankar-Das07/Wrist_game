import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/collisions.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'score_manager.dart';
import 'sound_manager.dart';

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

  VoidCallback? onGameStartRequested;
  VoidCallback? onGameEndRequested;

  String get gameTitle;

  int get requiredHandsCount => 2;
  String get distanceValidationTitle => 'HAND DETECTION';
  String get distanceValidationInstruction => requiredHandsCount == 1
      ? 'Raise ONE hand so the camera can see your Electric Racket.'
      : 'Raise BOTH hands so the camera can see them clearly.';

  // Distance validation: tracks whether required hands are visible
  bool isDistanceValidating = false;
  final ValueNotifier<String> distanceStatusNotifier = ValueNotifier<String>('Searching...');
  double bothHandsVisibleTimer = 0.0;

  // Stores latest raw fist X positions from MediaPipe (normalized 0–1, or -1 if not detected)
  double _rawLeftX = -1;
  double _rawRightX = -1;

  final ValueNotifier<int> countdownNotifier = ValueNotifier<int>(0);
  TimerComponent? countdownTimerComp;

  late FistTrackerComponent leftFist;
  late FistTrackerComponent rightFist;
  final Random random = Random();

  BaseJestureGame({
    FistTrackerComponent? customLeftFist,
    FistTrackerComponent? customRightFist,
  }) {
    leftFist = customLeftFist ?? FistTrackerComponent(Colors.blueAccent);
    rightFist = customRightFist ?? FistTrackerComponent(Colors.redAccent);
  }

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    addAll([leftFist, rightFist]);
  }

  /// Displays exclusively the specified overlay, removing all other competing menus.
  /// Pass `null` to clear all overlays (e.g. during active gameplay).
  void showOnlyOverlay(String? overlayName) {
    const allOverlays = [
      'MainMenu',
      'DistanceValidation',
      'Countdown',
      'PauseMenu',
      'GameOver',
      'Paywall',
      'LeaderboardMenu',
    ];
    for (final name in allOverlays) {
      if (name != overlayName) {
        overlays.remove(name);
      }
    }
    if (overlayName != null && !overlays.isActive(overlayName)) {
      overlays.add(overlayName);
    }
  }

  void startDistanceValidation() {
    isGameOver = false;
    isPlayingNotifier.value = false;
    isDistanceValidating = true;
    score = 0;
    lives = 20;
    speedMultiplier = 1.0;
    clearArena();
    _rawLeftX = -1;
    _rawRightX = -1;
    leftFist.targetPosition = Vector2(-2000, -2000);
    rightFist.targetPosition = Vector2(-2000, -2000);
    bothHandsVisibleTimer = 0.0;
    distanceStatusNotifier.value = requiredHandsCount == 1
        ? 'Raise your hand to camera...'
        : 'Show both hands to camera...';
    
    // Stop and remove any existing countdown timer
    countdownTimerComp?.timer.stop();
    if (countdownTimerComp != null && countdownTimerComp!.isMounted) {
      remove(countdownTimerComp!);
    }
    countdownTimerComp = null;

    showOnlyOverlay('DistanceValidation');
    resumeEngine();

    onGameStartRequested?.call();
  }

  void startCountdown() {
    resumeEngine();
    countdownNotifier.value = 5;
    
    countdownTimerComp?.timer.stop();
    if (countdownTimerComp != null && countdownTimerComp!.isMounted) {
      remove(countdownTimerComp!);
    }
    
    showOnlyOverlay('Countdown');
    
    countdownTimerComp = TimerComponent(
      period: 1.0,
      repeat: true,
      onTick: () {
        SoundManager.instance.playCountdownTick();
        countdownNotifier.value--;
        if (countdownNotifier.value <= 0) {
          countdownTimerComp?.timer.stop();
          if (countdownTimerComp != null && countdownTimerComp!.isMounted) {
            remove(countdownTimerComp!);
          }
          countdownTimerComp = null;
          startGame();
        }
      }
    );
    add(countdownTimerComp!);
  }

  void startGame() {
    isGameOver = false;
    isPlayingNotifier.value = true;
    showOnlyOverlay(null);
    resumeEngine();
    
    // Flash visual effect
    final flash = RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.white,
      priority: 100,
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
    isDistanceValidating = false;
    lives = 20;
    speedMultiplier = 1.0;
    score = 0;
    clearArena();
    _rawLeftX = -1;
    _rawRightX = -1;
    leftFist.targetPosition = Vector2(-2000, -2000);
    rightFist.targetPosition = Vector2(-2000, -2000);
    onGameStartRequested?.call();
    startCountdown();
  }
  
  void resumeFromAd() {
    lives = 20;
    clearArena();
    startCountdown();
  }

  void clearArena();

  void onBallMissed() {
    if (isGameOver) return;
    lives--;
    HapticFeedback.vibrate();
    
    if (lives <= 0) {
      isGameOver = true;
      isPlayingNotifier.value = false;
      ScoreManager.saveScore(gameTitle, score);
      SoundManager.instance.playGameOver();
      showOnlyOverlay('GameOver');
      onGameEndRequested?.call();
    }
  }

  /// Called from main.dart every time MediaPipe sends a new hand detection result.
  /// [leftX], [leftY]: user's left hand fist center, normalized 0–1 (-1 = not detected)
  /// [rightX], [rightY]: user's right hand fist center, normalized 0–1 (-1 = not detected)
  void updateFistPositions(double leftX, double leftY, double rightX, double rightY) {
    _rawLeftX = leftX;
    _rawRightX = rightX;

    // During distance validation: check required hands count
    if (isDistanceValidating) {
      if (requiredHandsCount == 1) {
        bool oneVisible = (leftX >= 0 || rightX >= 0);
        if (oneVisible) {
          distanceStatusNotifier.value = 'Perfect! Hold still...';
        } else {
          distanceStatusNotifier.value = 'No hands detected';
        }
      } else {
        bool bothVisible = (leftX >= 0 && rightX >= 0);
        if (bothVisible) {
          distanceStatusNotifier.value = 'Perfect! Hold still...';
        } else if (leftX >= 0 || rightX >= 0) {
          distanceStatusNotifier.value = 'Show both hands...';
        } else {
          distanceStatusNotifier.value = 'No hands detected';
        }
      }
      return;
    }

    if (isGameOver) return;

    // Map normalized coordinates to game canvas coordinates
    // leftX is already mirrored correctly by the Kotlin layer
    if (leftX >= 0 && leftY >= 0) {
      leftFist.targetPosition = Vector2(leftX * size.x, leftY * size.y);
    } else {
      leftFist.targetPosition = Vector2(-2000, -2000);
    }

    if (rightX >= 0 && rightY >= 0) {
      rightFist.targetPosition = Vector2(rightX * size.x, rightY * size.y);
    } else {
      rightFist.targetPosition = Vector2(-2000, -2000);
    }
  }
  
  void incrementScore(int addedPoints) {
    score += addedPoints;
    HapticFeedback.lightImpact();
    SoundManager.instance.playPunch();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Distance validation timer: auto-start countdown once required hands are held still
    if (isDistanceValidating) {
      final bool valid = requiredHandsCount == 1
          ? (_rawLeftX >= 0 || _rawRightX >= 0)
          : (_rawLeftX >= 0 && _rawRightX >= 0);
      if (valid) {
        bothHandsVisibleTimer += dt;
        final double targetWait = requiredHandsCount == 1 ? 1.5 : 2.2;
        if (bothHandsVisibleTimer >= targetWait) {
          isDistanceValidating = false;
          showOnlyOverlay('Countdown');
          startCountdown();
        }
      } else {
        bothHandsVisibleTimer = 0.0;
      }
    }
  }
}

class FistTrackerComponent extends PositionComponent with CollisionCallbacks {
  final double radius = 32.0;
  late final Paint _corePaint;
  late final Paint _glowPaint;
  late final Paint _ringPaint;
  
  Vector2 targetPosition = Vector2(-2000, -2000);
  Vector2 _smoothedPosition = Vector2(-2000, -2000);

  FistTrackerComponent(Color color) {
    size = Vector2.all(radius * 2);
    anchor = Anchor.center;
    
    _corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
      
    _glowPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16.0);

    _ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
      
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
    
    // If hand not detected, move off-screen instantly
    if (targetPosition.x == -2000) {
      position = targetPosition.clone();
      _smoothedPosition = targetPosition.clone();
      return;
    }
    
    // Teleport on first detection (was off-screen)
    if (_smoothedPosition.x == -2000) {
      _smoothedPosition = targetPosition.clone();
      position = _smoothedPosition.clone();
      return;
    }

    final double distance = _smoothedPosition.distanceTo(targetPosition);

    // Deadband anti-jitter filter: ignore micro-tremors (< 4px)
    if (distance < 4.0) {
      position = _smoothedPosition.clone();
      return;
    }

    // Adaptive smoothing: ultra-responsive on punches (>40px), rock-steady when holding still
    final double responsiveness = distance > 40.0 ? 32.0 : 18.0;
    final double lerpFactor = (1.0 - exp(-responsiveness * dt)).clamp(0.0, 1.0);
    _smoothedPosition.lerp(targetPosition, lerpFactor);
    
    position = _smoothedPosition.clone();
  }

  @override
  void render(Canvas canvas) {
    if (position.x == -2000) return;
    final center = Offset(radius, radius);
    canvas.drawCircle(center, radius + 10, _glowPaint);
    canvas.drawCircle(center, radius, _corePaint);
    canvas.drawCircle(center, radius, _ringPaint);
  }
}
