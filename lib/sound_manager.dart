import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// SoundManager
///
/// Singleton class managing all in-game sound effects.
/// Audio plays at balanced volume and respects device silent mode.
class SoundManager {
  SoundManager._();
  static final SoundManager _instance = SoundManager._();
  static SoundManager get instance => _instance;

  final AudioPlayer _player = AudioPlayer();
  bool isEnabled = true;

  Future<void> init() async {
    await _player.setVolume(0.65);
    await _player.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> _play(String asset) async {
    if (!isEnabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/$asset'));
    } catch (e) {
      debugPrint('SoundManager: failed to play $asset — $e');
    }
  }

  /// Short punchy impact on successful ball hit
  Future<void> playPunch() => _play('punch.mp3');

  /// Miss sound effect completely disabled per user request
  Future<void> playMiss() async {}

  /// Special shimmery sound for golden ball
  Future<void> playGoldenHit() => _play('golden_hit.mp3');

  /// Deep dramatic sting for game over
  Future<void> playGameOver() => _play('game_over.mp3');

  /// Short tick for countdown (3, 2, 1)
  Future<void> playCountdownTick() => _play('countdown_tick.mp3');

  void dispose() {
    _player.dispose();
  }
}
