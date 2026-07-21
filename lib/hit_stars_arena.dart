import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';

import 'base_jesture_game.dart';

class HitStarsArena extends BaseJestureGame {
  @override
  String get gameTitle => 'Hit Stars';

  double _spawnTimer = 0.0;

  @override
  void clearArena() {
    children.whereType<StaticHitStar>().forEach((b) => b.removeFromParent());
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isDistanceValidating || isGameOver) return;

    if (score >= 5000) {
      isGameOver = true;
      overlays.add('Paywall');
      return;
    }

    _spawnTimer += dt;
    
    // Difficulty scaling based on score (0 to 3000)
    double progress = (score / 3000.0).clamp(0.0, 1.0);
    
    // Spawn interval goes from 2.0s down to 0.6s
    double spawnInterval = 2.0 - (progress * 1.4);
    
    if (_spawnTimer >= spawnInterval) {
      _spawnTimer = 0;
      
      // Target time-to-live goes from 3.0s down to 1.0s
      double timeToLive = 3.0 - (progress * 2.0);
      
      double spawnX = random.nextDouble() * (size.x - 100) + 50;
      double spawnY = random.nextDouble() * (size.y - 300) + 100;
      
      add(StaticHitStar(Vector2(spawnX, spawnY), timeToLive));
    }
  }
}

class StaticHitStar extends PositionComponent with CollisionCallbacks {
  final double maxTimeToLive;
  double _timeRemaining;
  
  final double maxRadius = 40.0;
  late final Paint _paint;
  late CircleHitbox _hitbox;

  StaticHitStar(Vector2 spawnPosition, this.maxTimeToLive) : _timeRemaining = maxTimeToLive {
    position = spawnPosition;
    anchor = Anchor.center;
    size = Vector2.all(maxRadius * 2);
    
    _paint = Paint()
      ..color = Colors.amberAccent.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _hitbox = CircleHitbox(radius: maxRadius, anchor: Anchor.center, position: Vector2(maxRadius, maxRadius));
    add(_hitbox);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timeRemaining -= dt;
    
    if (_timeRemaining <= 0) {
      final game = findGame() as BaseJestureGame?;
      if (game != null) game.onBallMissed();
      removeFromParent();
      // Flash red when almost out of time
      if (_timeRemaining < 0.5) {
        _paint.color = Colors.redAccent.withValues(alpha: 0.9);
      }
    }
  }

  Path _createStarPath(double radius) {
    final path = Path();
    final center = Offset(maxRadius, maxRadius); // using bounding box center
    const points = 5;
    final innerRadius = radius / 2.5;
    
    const angle = (pi * 2) / points;
    
    for (int i = 0; i < points; i++) {
      double r = radius;
      double a = angle * i - pi / 2;
      
      if (i == 0) {
        path.moveTo(center.dx + r * cos(a), center.dy + r * sin(a));
      } else {
        path.lineTo(center.dx + r * cos(a), center.dy + r * sin(a));
      }
      
      r = innerRadius;
      a += angle / 2;
      path.lineTo(center.dx + r * cos(a), center.dy + r * sin(a));
    }
    
    path.close();
    return path;
  }

  @override
  void render(Canvas canvas) {
    double timeElapsed = maxTimeToLive - _timeRemaining;
    
    // Heartbeat pulsating effect
    // Sine wave that oscillates between approx 0.8 and 1.2
    double beatScale = 1.0 + 0.15 * sin(timeElapsed * 10);
    double currentRadius = maxRadius * beatScale;
    
    // Fade out a bit if almost dead? The prompt just said "then dissapear".
    // When time remaining is <= 0 it gets removed, so it just disappears.
    
    final path = _createStarPath(currentRadius);
    canvas.drawPath(path, _paint);
    
    // Draw an outline ring to show original size / bounding area optionally
    final outlinePaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset(maxRadius, maxRadius), maxRadius, outlinePaint);
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    
    if (other is FistTrackerComponent) {
      final game = findGame() as BaseJestureGame?;
      if (game != null) {
        game.incrementScore(20);
        
        final random = Random();
        game.add(ParticleSystemComponent(
          position: position.clone() + Vector2(size.x/2, size.y/2),
          particle: Particle.generate(
            count: 15,
            lifespan: 0.5,
            generator: (i) {
              final angle = random.nextDouble() * 2 * pi;
              final speed = random.nextDouble() * 300 + 50;
              final dir = Vector2(cos(angle), sin(angle)) * speed;
              return AcceleratedParticle(
                position: Vector2.zero(),
                speed: dir,
                child: CircleParticle(
                  radius: random.nextDouble() * 4 + 2,
                  paint: Paint()..color = Colors.amberAccent,
                ),
              );
            },
          ),
        ));
      }
      removeFromParent();
    }
  }
}

