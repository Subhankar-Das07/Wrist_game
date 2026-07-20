import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';

import 'base_jesture_game.dart';

class HitBallArena extends BaseJestureGame {
  double _spawnTimer = 0.0;

  @override
  void clearArena() {
    children.whereType<StaticHitBall>().forEach((b) => b.removeFromParent());
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
      
      add(StaticHitBall(Vector2(spawnX, spawnY), timeToLive));
    }
  }
}

class StaticHitBall extends PositionComponent with CollisionCallbacks {
  final double maxTimeToLive;
  double _timeRemaining;
  
  final double maxRadius = 40.0;
  late final Paint _paint;
  late CircleHitbox _hitbox;

  StaticHitBall(Vector2 spawnPosition, this.maxTimeToLive) : _timeRemaining = maxTimeToLive {
    position = spawnPosition;
    anchor = Anchor.center;
    size = Vector2.all(maxRadius * 2);
    
    _paint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.9)
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

  @override
  void render(Canvas canvas) {
    double ratio = (_timeRemaining / maxTimeToLive).clamp(0.2, 1.0);
    double currentRadius = maxRadius * ratio;
    
    // Draw the shrinking ball in the center
    canvas.drawCircle(Offset(maxRadius, maxRadius), currentRadius, _paint);
    
    // Draw an outline ring to show original size
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
        // Hitting it faster grants slightly more points? Or just fixed 20 points
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
                  paint: Paint()..color = Colors.cyanAccent,
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
