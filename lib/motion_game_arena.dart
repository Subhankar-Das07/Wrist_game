import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';

import 'base_jesture_game.dart';

enum BallType { standard, fast, golden }

class MotionGameArena extends BaseJestureGame {
  double _spawnTimer = 0.0;

  MotionGameArena();

  @override
  void clearArena() {
    children.whereType<TargetBall>().forEach((b) => b.removeFromParent());
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isDistanceValidating || isGameOver) return;

    // Check for Paywall condition
    if (score >= 4000) {
      isGameOver = true;
      overlays.add('Paywall');
      return;
    }

    _spawnTimer += dt;
    if (_spawnTimer > 0.70) {
      _spawnTimer = 0;
      
      double ballX = random.nextDouble() * (size.x - 100) + 50;
      double baseSpeed = 200.0;
      double dx = 0.0;
      BallType type = BallType.standard;
      
      // Dynamic Difficulty & Strategy
      if (score < 500) {
        // Level 1: Straight falling, slow
        baseSpeed = 200.0;
      } else if (score < 1500) {
        // Level 1.5: Straight falling, medium speed
        baseSpeed = 300.0;
        // Occasionally drift slightly
        if (random.nextDouble() > 0.7) {
          dx = random.nextDouble() * 200 - 100;
        }
      } else if (score < 2000) {
        // Level 1.8: Faster, high X drift for wall bouncing
        if (random.nextDouble() > 0.3) {
          dx = random.nextDouble() * 600 - 300;
        }
      } else {
        // Level 2 (2000-4000): Fast balls, Yellow balls
        if (random.nextDouble() > 0.2) {
          dx = random.nextDouble() * 800 - 400;
        }
        
        final double roll = random.nextDouble();
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
        points = 25;
        _paint = Paint()
          ..shader = ui.Gradient.radial(
            Offset(radius, radius), radius,
            [Colors.purpleAccent, Colors.deepPurple],
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
    final game = findGame() as BaseJestureGame?;
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
      final game = findGame() as BaseJestureGame?;
      if (game != null) {
        game.incrementScore(points);
        
        // Custom explosion effects based on ball type
        final random = Random();
        int particleCount = type == BallType.golden ? 25 : (type == BallType.fast ? 18 : 12);
        double explodeSpeed = type == BallType.golden ? 400 : 250;
        
        game.add(ParticleSystemComponent(
          position: position.clone(),
          particle: Particle.generate(
            count: particleCount,
            lifespan: 0.6,
            generator: (i) {
              final angle = random.nextDouble() * 2 * pi;
              final speed = random.nextDouble() * explodeSpeed + 50;
              final dir = Vector2(cos(angle), sin(angle)) * speed;
              
              Color pColor = Colors.greenAccent;
              if (type == BallType.fast) pColor = Colors.purpleAccent;
              if (type == BallType.golden) pColor = Colors.yellowAccent;
              
              return AcceleratedParticle(
                position: Vector2.zero(),
                speed: dir,
                child: CircleParticle(
                  radius: random.nextDouble() * 4 + 2,
                  paint: Paint()..color = pColor.withOpacity(0.8),
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
