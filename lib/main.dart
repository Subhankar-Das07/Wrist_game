import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'weapon_painters.dart';
import 'package:camera/camera.dart';
import 'package:flame/game.dart' hide Plane;
import 'base_jesture_game.dart';
import 'motion_game_arena.dart';
import 'hit_bugs_arena.dart';
import 'score_manager.dart';
import 'permission_gate.dart';
import 'payment_service.dart';
import 'privacy_policy_screen.dart';
import 'sound_manager.dart';
import 'dart:async';
import 'dart:io';

// ─── MediaPipe MethodChannel ──────────────────────────────────────────────────
const _handLandmarkerChannel = MethodChannel('com.example.jesture/hand_landmarker');
// ─────────────────────────────────────────────────────────────────────────────

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation for consistent gameplay
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Immersive full-screen mode
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Cameras unavailable: $e');
  }

  // Pre-initialize sound manager
  await SoundManager.instance.init();

  runApp(const WristTrackerApp());
}

class WristTrackerApp extends StatelessWidget {
  const WristTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jesture',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      // Route through PermissionGate first — opens GameScreen when camera is granted
      home: const PermissionGate(child: GameScreen()),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  late BaseJestureGame _gameArena;
  bool _isProcessingFrame = false;
  bool _isStreaming = false;
  bool _isStartingCamera = false;
  bool _wasPlayingWhenPaused = false; // tracks if game was active when app went to background
  Uint8List? _frameBuffer;
  int _lastProcessTime = 0;

  CameraDescription? _frontCamera;
  final ValueNotifier<CameraController?> _cameraNotifier = ValueNotifier<CameraController?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initGameArena(MotionGameArena());
    // Camera is NOT opened here — remains 100% powered off until gameplay begins
  }

  void _initGameArena(BaseJestureGame arena) {
    _gameArena = arena;
    _gameArena.onGameStartRequested = () {
      _startCameraAndStreaming();
    };
    _gameArena.onGameEndRequested = () {
      _stopCameraCompletely();
    };
    _gameArena.showOnlyOverlay('MainMenu');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCameraCompletely();
    _cameraNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Track whether a game was actively running or validating when user left
      final bool wasActive = (_gameArena.isPlayingNotifier.value ||
              _gameArena.isDistanceValidating ||
              _gameArena.countdownNotifier.value > 0) &&
          !_gameArena.isGameOver;

      if (wasActive) {
        _wasPlayingWhenPaused = true;
        _gameArena.pauseEngine();
        _gameArena.showOnlyOverlay('PauseMenu');
      }

      // Stop & dispose camera completely — turns off green light & saves battery in background
      _stopCameraCompletely();
    } else if (state == AppLifecycleState.resumed) {
      // If returning to a paused game, ensure engine remains paused and ONLY PauseMenu is up.
      // Camera stays OFF until user taps RESUME in the PauseMenu.
      if (_wasPlayingWhenPaused) {
        _gameArena.pauseEngine();
        _gameArena.showOnlyOverlay('PauseMenu');
      } else {
        // Not in an active game — make sure no stray pause menu or game is showing
        if (_gameArena.isGameOver) {
          if (!_gameArena.overlays.isActive('GameOver') &&
              !_gameArena.overlays.isActive('Paywall') &&
              !_gameArena.overlays.isActive('LeaderboardMenu')) {
            _gameArena.showOnlyOverlay('MainMenu');
          }
        }
      }
    }
  }

  /// Opens the camera hardware and immediately streams frames for gesture detection.
  /// Called ONLY during active gameplay or distance validation.
  Future<void> _startCameraAndStreaming() async {
    if (_isStartingCamera) return;
    _isStartingCamera = true;
    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        if (cameras.isEmpty) return;

        _frontCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );

        final controller = CameraController(
          _frontCamera!,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
        );

        await controller.initialize();
        if (!mounted) {
          await controller.dispose();
          return;
        }

        _cameraController = controller;
        _cameraNotifier.value = controller;
      }

      if (_cameraController != null && _cameraController!.value.isInitialized && !_isStreaming) {
        await _cameraController!.startImageStream((CameraImage image) {
          _processCameraFrame(image);
        });
        _isStreaming = true;
        debugPrint('Camera: opened & streaming started');
      }
    } catch (e) {
      debugPrint('Camera start error: $e');
    } finally {
      _isStartingCamera = false;
    }
  }

  /// Completely disposes and closes the camera hardware.
  /// Turns OFF the green camera indicator LED and eliminates battery drain.
  Future<void> _stopCameraCompletely() async {
    _isStreaming = false;
    _isProcessingFrame = false;
    final ctrl = _cameraController;
    _cameraController = null;
    _cameraNotifier.value = null;

    if (ctrl != null) {
      try {
        if (ctrl.value.isStreamingImages) {
          await ctrl.stopImageStream();
        }
      } catch (_) {}
      try {
        await ctrl.dispose();
        debugPrint('Camera: completely closed & hardware light OFF');
      } catch (e) {
        debugPrint('Camera dispose error: $e');
      }
    }
  }

  void _processCameraFrame(CameraImage image) {
    if (_isProcessingFrame) return;

    // Throttle frame processing to max 15 FPS (~66ms) to save CPU & battery on older devices
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastProcessTime < 66) return;
    _lastProcessTime = now;

    _isProcessingFrame = true;

    try {
      // Calculate total byte length
      final int totalLength = image.planes.fold(0, (sum, p) => sum + p.bytes.length);

      // Reuse pre-allocated buffer (only re-allocate if size changed)
      if (_frameBuffer == null || _frameBuffer!.length != totalLength) {
        _frameBuffer = Uint8List(totalLength);
      }

      int offset = 0;
      for (final plane in image.planes) {
        _frameBuffer!.setRange(offset, offset + plane.bytes.length, plane.bytes);
        offset += plane.bytes.length;
      }

      final int rotation = _frontCamera?.sensorOrientation ?? 270;

      _handLandmarkerChannel.invokeMethod('detectHands', {
        'bytes': _frameBuffer,
        'width': image.width,
        'height': image.height,
        'rotation': rotation,
      }).then((data) {
        if (data is List && data.length == 4) {
          final lx = (data[0] as num).toDouble();
          final ly = (data[1] as num).toDouble();
          final rx = (data[2] as num).toDouble();
          final ry = (data[3] as num).toDouble();
          _gameArena.updateFistPositions(lx, ly, rx, ry);
        }
      }).catchError((e) {
        debugPrint('Hand detection error: $e');
      }).whenComplete(() {
        _isProcessingFrame = false;
      });
    } catch (e) {
      _isProcessingFrame = false;
    }
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Intercept back button — pause game instead of exiting
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (_gameArena.isPlayingNotifier.value && !_gameArena.isGameOver) {
          _wasPlayingWhenPaused = true;
          _gameArena.pauseEngine();
          _stopCameraCompletely();
          _gameArena.showOnlyOverlay('PauseMenu');
        }
      },
      child: Scaffold(
        drawer: Drawer(
          backgroundColor: Colors.blueGrey.shade900,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.cyan),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.sports_martial_arts, size: 48, color: Colors.black),
                    SizedBox(height: 8),
                    Text('Jesture', style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold)),
                    Text('Hand Tracking Game', style: TextStyle(color: Colors.black54, fontSize: 14)),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.sports_basketball, color: Colors.white),
                title: const Text('Play Fall Ball', style: TextStyle(color: Colors.white, fontSize: 18)),
                onTap: () {
                  Navigator.pop(context);
                  _stopCameraCompletely();
                  setState(() {
                    _wasPlayingWhenPaused = false;
                    _initGameArena(MotionGameArena());
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.pest_control, color: Color(0xFF39FF14)),
                title: const Text('Play Hit Bugs', style: TextStyle(color: Color(0xFF39FF14), fontSize: 18)),
                onTap: () {
                  Navigator.pop(context);
                  _stopCameraCompletely();
                  setState(() {
                    _wasPlayingWhenPaused = false;
                    _initGameArena(HitBugsArena());
                  });
                },
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white70),
                title: const Text('Privacy Policy', style: TextStyle(color: Colors.white70, fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white70),
                title: const Text('About', style: TextStyle(color: Colors.white70, fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.blueGrey.shade900,
                      title: const Text('About Jesture', style: TextStyle(color: Colors.cyanAccent)),
                      content: const Text(
                        'Jesture is a real-time computer vision hand-tracking game.\n\n'
                        'Your camera is used only for detecting hand movements on-device. '
                        'No video or images are ever recorded or transmitted.',
                        style: TextStyle(color: Colors.white70, height: 1.5),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('OK', style: TextStyle(color: Colors.cyanAccent)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(color: Colors.white24),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'v1.0.1 · © 2026 Jesture',
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Top HUD Bar — only visible during active gameplay (hidden when menus are up)
              ValueListenableBuilder<bool>(
                key: ValueKey('isPlaying_${_gameArena.hashCode}'),
                valueListenable: _gameArena.isPlayingNotifier,
                builder: (context, isPlaying, child) {
                  if (!isPlaying) return const SizedBox.shrink();
                  if (_gameArena.overlays.isActive('MainMenu') ||
                      _gameArena.overlays.isActive('PauseMenu') ||
                      _gameArena.overlays.isActive('GameOver') ||
                      _gameArena.overlays.isActive('Paywall') ||
                      _gameArena.overlays.isActive('LeaderboardMenu')) {
                    return const SizedBox.shrink();
                  }

                  final bool isBugs = _gameArena is HitBugsArena;

                  return Container(
                    height: 56,
                    width: double.infinity,
                    color: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Pause Button
                        IconButton(
                          icon: const Icon(Icons.pause_circle_filled, color: Colors.white, size: 30),
                          tooltip: 'Pause Game',
                          onPressed: () {
                            _wasPlayingWhenPaused = true;
                            _gameArena.pauseEngine();
                            _stopCameraCompletely();
                            _gameArena.showOnlyOverlay('PauseMenu');
                          },
                        ),

                        // Center: Live category-wise bug counts (if Hit Bugs)
                        if (isBugs)
                          ValueListenableBuilder<Map<BugType, int>>(
                            key: ValueKey('bugStats_${_gameArena.hashCode}'),
                            valueListenable: (_gameArena as HitBugsArena).bugStatsNotifier,
                            builder: (context, stats, child) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildBugStatBadge('🪰', stats[BugType.fly] ?? 0, const Color(0xFF00E5FF)),
                                  const SizedBox(width: 4),
                                  _buildBugStatBadge('🦟', stats[BugType.mosquito] ?? 0, const Color(0xFFFF5252)),
                                  const SizedBox(width: 4),
                                  _buildBugStatBadge('🐝', stats[BugType.hornet] ?? 0, const Color(0xFFFFD600)),
                                  const SizedBox(width: 4),
                                  _buildBugStatBadge('🪲', stats[BugType.toxicBeetle] ?? 0, const Color(0xFF39FF14)),
                                ],
                              );
                            },
                          ),

                        // Right: Score & (Lives for Ball / Target for Bugs)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ValueListenableBuilder<int>(
                              key: ValueKey('score_${_gameArena.hashCode}'),
                              valueListenable: _gameArena.scoreNotifier,
                              builder: (context, score, child) {
                                return Text('★ $score', style: const TextStyle(color: Colors.yellowAccent, fontSize: 18, fontWeight: FontWeight.bold));
                              },
                            ),
                            const SizedBox(width: 8),
                            if (isBugs)
                              ValueListenableBuilder<int>(
                                key: ValueKey('bugsSwatted_${_gameArena.hashCode}'),
                                valueListenable: (_gameArena as HitBugsArena).bugsSwattedNotifier,
                                builder: (context, swatted, child) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD50000).withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFFF5252), width: 1.2),
                                    ),
                                    child: Text(
                                      '🎯 $swatted/40',
                                      style: const TextStyle(color: Color(0xFFFF5252), fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  );
                                },
                              )
                            else
                              ValueListenableBuilder<int>(
                                key: ValueKey('lives_${_gameArena.hashCode}'),
                                valueListenable: _gameArena.livesNotifier,
                                builder: (context, lives, child) {
                                  return Text('❤️ $lives', style: const TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold));
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Camera preview (driven by _cameraNotifier for instant, zero-rebuild camera feed)
                    ValueListenableBuilder<CameraController?>(
                      valueListenable: _cameraNotifier,
                      builder: (context, controller, child) {
                        if (controller != null && controller.value.isInitialized) {
                          return Positioned.fill(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: controller.value.previewSize!.height,
                                height: controller.value.previewSize!.width,
                                child: CameraPreview(controller),
                              ),
                            ),
                          );
                        }
                        return Positioned.fill(
                          child: Container(color: Colors.black),
                        );
                      },
                    ),

                    GameWidget(
                      key: ValueKey(_gameArena.hashCode),
                      game: _gameArena,
                      overlayBuilderMap: {
                        'MainMenu': (context, BaseJestureGame game) {
                          bool isBugs = game is HitBugsArena;
                          String bgImage = isBugs ? 'assets/images/hit_bugs_bg.png' : 'assets/images/fall_ball_bg.png';
                          String title = isBugs ? 'HIT BUGS' : 'FALL BALL';
                          IconData titleIcon = isBugs ? Icons.pest_control : Icons.sports_basketball;
                          Color themeColor = isBugs ? const Color(0xFF39FF14) : Colors.cyan;
                          String instructionsText = isBugs
                              ? '1. Stand 3-5 feet away.\n2. Raise ONE hand to hold the big cartoon swatter.\n3. Swat 40 bugs to reach Level 3 Premium!\n4. Green slime splats show your hits!\n5. Play is continuous with no time/life limit.'
                              : '1. Stand 3-5 feet away.\n2. Show BOTH hands to start.\n3. Punch the falling balls to score points!\n4. You have 20 lives.';

                          return Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade900,
                                  image: DecorationImage(
                                    image: AssetImage(bgImage),
                                    fit: BoxFit.cover,
                                    colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.darken),
                                  ),
                                ),
                                child: Center(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // ─── GAME MODE SELECTOR ───
                                        Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            borderRadius: BorderRadius.circular(30),
                                            border: Border.all(color: Colors.white24, width: 1.5),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  if (isBugs) {
                                                    _stopCameraCompletely();
                                                    setState(() {
                                                      _wasPlayingWhenPaused = false;
                                                      _initGameArena(MotionGameArena());
                                                    });
                                                  }
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: !isBugs ? Colors.cyan : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(25),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.sports_basketball, size: 20, color: !isBugs ? Colors.black : Colors.white70),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'FALL BALL',
                                                        style: TextStyle(
                                                          color: !isBugs ? Colors.black : Colors.white70,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () {
                                                  if (!isBugs) {
                                                    _stopCameraCompletely();
                                                    setState(() {
                                                      _wasPlayingWhenPaused = false;
                                                      _initGameArena(HitBugsArena());
                                                    });
                                                  }
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: isBugs ? const Color(0xFF39FF14) : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(25),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.pest_control, size: 20, color: isBugs ? Colors.black : Colors.white70),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'HIT BUGS',
                                                        style: TextStyle(
                                                          color: isBugs ? Colors.black : Colors.white70,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 25),
                                        Icon(titleIcon, size: 75, color: themeColor),
                                        const SizedBox(height: 10),
                                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold, letterSpacing: 2)),
                                        const SizedBox(height: 30),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: themeColor,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                                            elevation: 10,
                                          ),
                                          onPressed: () {
                                            _wasPlayingWhenPaused = false;
                                            // Fall Ball shows weapon chooser; Hit Bugs goes direct
                                            if (game is MotionGameArena) {
                                              game.showOnlyOverlay('WeaponSelector');
                                            } else {
                                              game.startDistanceValidation();
                                            }
                                          },
                                          child: const Text('START GAME', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(height: 15),
                                        OutlinedButton.icon(
                                          icon: Icon(Icons.help_outline, color: themeColor),
                                          label: Text('HOW TO PLAY', style: TextStyle(color: themeColor, fontSize: 18)),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: themeColor, width: 2),
                                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                          ),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                backgroundColor: Colors.blueGrey.shade900,
                                                title: Text('How to Play: $title', style: TextStyle(color: themeColor)),
                                                content: Text(
                                                  instructionsText,
                                                  style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx),
                                                    child: Text('GOT IT', style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 15),
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.leaderboard, color: Colors.white),
                                          label: const Text('LEADERBOARD', style: TextStyle(color: Colors.white, fontSize: 18)),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Colors.white, width: 2),
                                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                          ),
                                          onPressed: () {
                                            game.showOnlyOverlay('LeaderboardMenu');
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 40,
                                left: 20,
                                child: Builder(
                                  builder: (ctx) => IconButton(
                                    icon: const Icon(Icons.menu, color: Colors.white, size: 40),
                                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                        'WeaponSelector': (context, BaseJestureGame game) {
                          return _buildWeaponSelectorOverlay(context, game);
                        },
                        'DistanceValidation': (context, BaseJestureGame game) {
                          final bool isBugs = game is HitBugsArena;
                          final Color themeColor = isBugs ? const Color(0xFF39FF14) : Colors.cyanAccent;

                          return Center(
                            child: Container(
                              width: 320,
                              padding: const EdgeInsets.all(25),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: themeColor, width: 2),
                                boxShadow: [
                                  BoxShadow(color: themeColor.withValues(alpha: 0.35), blurRadius: 18),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(isBugs ? Icons.sports_tennis : Icons.pan_tool, size: 60, color: themeColor),
                                  const SizedBox(height: 18),
                                  Text(
                                    game.distanceValidationTitle,
                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    game.distanceValidationInstruction,
                                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 25),
                                  ValueListenableBuilder<String>(
                                    valueListenable: game.distanceStatusNotifier,
                                    builder: (context, status, child) {
                                      Color statusColor = Colors.yellowAccent;
                                      if (status == 'Perfect! Hold still...') statusColor = Colors.greenAccent;
                                      if (status == 'No hands detected') statusColor = Colors.redAccent;
                                      return Text(
                                        status,
                                        style: TextStyle(color: statusColor, fontSize: 22, fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 25),
                                  TextButton(
                                    onPressed: () {
                                      game.isDistanceValidating = false;
                                      game.startCountdown();
                                    },
                                    child: const Text('Skip & Start Anyway', style: TextStyle(color: Colors.white54, decoration: TextDecoration.underline)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        'Countdown': (context, BaseJestureGame game) {
                          return Center(
                            child: ValueListenableBuilder<int>(
                              valueListenable: game.countdownNotifier,
                              builder: (context, value, child) {
                                return Text(
                                  value > 0 ? '$value' : 'GO!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 120,
                                    fontWeight: FontWeight.bold,
                                    shadows: [Shadow(color: Colors.black, blurRadius: 10, offset: Offset(2, 2))],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        'GameOver': (context, BaseJestureGame game) {
                          return Stack(
                            children: [
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(40),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.cyanAccent, width: 3),
                                    boxShadow: [
                                      BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('OUT OF LIVES', style: TextStyle(color: Colors.redAccent, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 2)),
                                      const SizedBox(height: 20),
                                      const Text('YOUR FINAL SCORE', style: TextStyle(color: Colors.white70, fontSize: 18, letterSpacing: 1)),
                                      Text('${game.score}', style: const TextStyle(color: Colors.yellowAccent, fontSize: 80, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
                                      const SizedBox(height: 40),
                                      // PLAY AGAIN — clean, no fake ads
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.refresh, size: 24),
                                        label: const Text('PLAY AGAIN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.cyanAccent,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                        ),
                                        onPressed: () {
                                          game.resetGame(); // resets, triggers onGameStartRequested, restarts countdown
                                        },
                                      ),
                                      const SizedBox(height: 15),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.home_outlined),
                                        label: const Text('Main Menu', style: TextStyle(fontSize: 18)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white12,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                        ),
                                        onPressed: () {
                                          game.clearArena();
                                          game.isPlayingNotifier.value = false;
                                          _stopCameraCompletely(); // completely turn off camera hardware when returning to menu
                                          game.showOnlyOverlay('MainMenu');
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 40,
                                left: 20,
                                child: Builder(
                                  builder: (ctx) => IconButton(
                                    icon: const Icon(Icons.menu, color: Colors.white, size: 40),
                                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                        'Paywall': (context, BaseJestureGame game) {
                          bool isBugs = game is HitBugsArena;
                          String paywallTitle = isBugs ? '40 BUGS SWATTER MASTER!' : 'AMAZING SCORE!';
                          String paywallSubtitle = isBugs
                              ? 'You swatted 40 bugs!\nUnlock Level 3 to keep exterminating.'
                              : 'You reached 3000 points!\nUnlock Level 3 to keep going.';
                          Color paywallColor = isBugs ? const Color(0xFF39FF14) : Colors.amberAccent;

                          return Stack(
                            children: [
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(40),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.95),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: paywallColor, width: 3),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(isBugs ? Icons.pest_control : Icons.emoji_events, size: 80, color: paywallColor),
                                      const SizedBox(height: 20),
                                      Text(paywallTitle, style: TextStyle(color: paywallColor, fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                      const SizedBox(height: 10),
                                      Text(paywallSubtitle, style: const TextStyle(color: Colors.white70, fontSize: 18, height: 1.5), textAlign: TextAlign.center),
                                      const SizedBox(height: 30),
                                      // Razorpay-ready unlock button
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: paywallColor,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                        ),
                                        icon: const Icon(Icons.lock_open, size: 24),
                                        label: const Text('UNLOCK PREMIUM', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                        onPressed: () async {
                                          await PaymentService.instance.initiateUnlock(context);
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      TextButton(
                                        onPressed: () {
                                          game.clearArena();
                                          game.isPlayingNotifier.value = false;
                                          _stopCameraCompletely();
                                          game.showOnlyOverlay('MainMenu');
                                        },
                                        child: const Text('Start Over from Level 1', style: TextStyle(color: Colors.white54, fontSize: 16)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 40,
                                left: 20,
                                child: Builder(
                                  builder: (ctx) => IconButton(
                                    icon: const Icon(Icons.menu, color: Colors.white, size: 40),
                                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                        'PauseMenu': (context, BaseJestureGame game) {
                          return Container(
                            color: Colors.black.withValues(alpha: 0.8),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(40),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade900,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('GAME PAUSED', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 30),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.play_arrow, color: Colors.black),
                                      label: const Text('RESUME', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                                      onPressed: () {
                                        _wasPlayingWhenPaused = false;
                                        game.showOnlyOverlay(null);
                                        _startCameraAndStreaming(); // restart camera hardware & feed on continue
                                        game.resumeEngine();
                                      },
                                    ),
                                    const SizedBox(height: 15),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.exit_to_app, color: Colors.black),
                                      label: const Text('LEAVE GAME', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                                      onPressed: () {
                                        _wasPlayingWhenPaused = false;
                                        game.resumeEngine();
                                        game.isPlayingNotifier.value = false;
                                        game.isDistanceValidating = false;
                                        ScoreManager.saveScore(game.gameTitle, game.score);
                                        game.isGameOver = true;
                                        game.clearArena();
                                        _stopCameraCompletely(); // completely turn off camera hardware on leave
                                        game.showOnlyOverlay('MainMenu');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        'LeaderboardMenu': (context, BaseJestureGame game) {
                          if (game is HitBugsArena) {
                            return _buildHitBugsLeaderboard(context, game);
                          } else {
                            return _buildFallBallLeaderboard(context, game);
                          }
                        },
                      },
                    ),
                  ],
                ),
              ),
              // *** GOOGLE ADS SPACE BANNER REMOVED — was a Play Store policy violation ***
            ],
          ),
        ),
      ),
    );
  }

  // ─── Weapon Selector Overlay ─────────────────────────────────────────────────
  Widget _buildWeaponSelectorOverlay(BuildContext context, BaseJestureGame game) {
    final motionGame = game as MotionGameArena;
    WeaponType selected = motionGame.selectedWeapon;

    final List<Map<String, dynamic>> weapons = [
      {
        'type': WeaponType.boxing,
        'name': 'Boxing Gloves',
        'desc': 'Classic power punches',
        'emoji': '🥊',
        'image': 'assets/images/boxing.webp',
        'leftColor': const Color(0xFF1565C0),
        'rightColor': const Color(0xFFB71C1C),
        'glowColor': Colors.cyanAccent,
      },
      {
        'type': WeaponType.barbie,
        'name': 'Barbie Gloves',
        'desc': 'Sparkle & style',
        'emoji': '💅',
        'image': 'assets/images/barbie.webp',
        'leftColor': const Color(0xFFFF1493),
        'rightColor': const Color(0xFFFF1493),
        'glowColor': Colors.pinkAccent,
      },
      {
        'type': WeaponType.ironMan,
        'name': 'Iron Man',
        'desc': 'Arc reactor power!',
        'emoji': '🤖',
        'image': 'assets/images/ironman.jpg',
        'leftColor': const Color(0xFFB71C1C),
        'rightColor': const Color(0xFFFFD700),
        'glowColor': Colors.amberAccent,
      },
    ];

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Scaffold(
          backgroundColor: Colors.black.withValues(alpha: 0.8),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  width: 380,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.7), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withValues(alpha: 0.25),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('⚔️', style: TextStyle(fontSize: 24)),
                      SizedBox(width: 8),
                      Text(
                        'CHOOSE YOUR WEAPON',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pick the hands you\'ll fight with',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Weapon cards (horizontal scroll for small screens)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: weapons.map((w) {
                        final WeaponType wType = w['type'] as WeaponType;
                        final bool isSelected = selected == wType;
                        final Color glowColor = w['glowColor'] as Color;

                        return GestureDetector(
                          onTap: () {
                            setLocalState(() {
                              selected = wType;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 96,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? glowColor.withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? glowColor : Colors.white24,
                                width: isSelected ? 2.2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: glowColor.withValues(alpha: 0.4), blurRadius: 14)]
                                  : [],
                            ),
                            child: Column(
                              children: [
                                // Weapon preview using CustomPaint
                                SizedBox(
                                  width: 70,
                                  height: 80,
                                  child: CustomPaint(painter: WeaponPreviewPainter(w['type'])),
                                ),
                                const SizedBox(height: 8),
                                // Emoji badge
                                Text(w['emoji'] as String, style: const TextStyle(fontSize: 20)),
                                const SizedBox(height: 4),
                                // Name
                                Text(
                                  w['name'] as String,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                // Description
                                Text(
                                  w['desc'] as String,
                                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                                if (isSelected) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: glowColor.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'SELECTED',
                                      style: TextStyle(
                                        color: glowColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).map((widget) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: widget,
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // FIGHT Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Text('⚡', style: TextStyle(fontSize: 18)),
                      label: const Text(
                        'READY? FIGHT!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                      ),
                      onPressed: () {
                        motionGame.applyWeapon(selected);
                        motionGame.startDistanceValidation();
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Back link
                  TextButton(
                    onPressed: () {
                      game.showOnlyOverlay('MainMenu');
                    },
                    child: const Text(
                      '← Back to Menu',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBugStatBadge(String emoji, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildHitBugsLeaderboard(BuildContext context, BaseJestureGame game) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        ScoreManager.getScores('Hit Bugs'),
        ScoreManager.getLifetimeBugStats(),
      ]),
      builder: (context, snapshot) {
        final List<int> scores = (snapshot.data?[0] as List<int>?) ?? [];
        final Map<String, int> stats = (snapshot.data?[1] as Map<String, int>?) ?? {
          'total': 0,
          'fly': 0,
          'mosquito': 0,
          'hornet': 0,
          'toxicBeetle': 0,
        };

        final int totalKills = stats['total'] ?? 0;
        final rankInfo = ScoreManager.getHunterRank(totalKills);

        return Container(
          color: Colors.black.withValues(alpha: 0.92),
          child: Center(
            child: Container(
              width: 350,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF39FF14), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF39FF14).withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🦟', style: TextStyle(fontSize: 26)),
                      SizedBox(width: 8),
                      Text(
                        'EXTERMINATOR LOG',
                        style: TextStyle(
                          color: Color(0xFF39FF14),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Scrollable Content
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Hunter Rank & Lifetime Summary Banner
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(
                                    rankInfo['badge'] as String,
                                    style: const TextStyle(fontSize: 36),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          rankInfo['title'] as String,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '🔥 $totalKills Lifetime Swats',
                                          style: const TextStyle(
                                            color: Color(0xFF39FF14),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: (rankInfo['progress'] as double).clamp(0.0, 1.0),
                                  backgroundColor: Colors.white10,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF39FF14)),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  rankInfo['nextTier'] as String,
                                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Lifetime Species Breakdown Header
                        const Row(
                          children: [
                            Icon(Icons.pie_chart_outline, color: Colors.white70, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'LIFETIME SPECIES KILLS',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Species 2x2 Grid Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildSpeciesKillCard(
                                icon: '🪰',
                                name: 'Housefly',
                                count: stats['fly'] ?? 0,
                                points: '+10 pts',
                                accentColor: const Color(0xFF38BDF8),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSpeciesKillCard(
                                icon: '🦟',
                                name: 'Mosquito',
                                count: stats['mosquito'] ?? 0,
                                points: '+20 pts',
                                accentColor: const Color(0xFFF43F5E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSpeciesKillCard(
                                icon: '🐝',
                                name: 'Hornet',
                                count: stats['hornet'] ?? 0,
                                points: '+35 pts',
                                accentColor: const Color(0xFFFBBF24),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSpeciesKillCard(
                                icon: '🪲',
                                name: 'Toxic Beetle',
                                count: stats['toxicBeetle'] ?? 0,
                                points: '+50 pts',
                                accentColor: const Color(0xFF34D399),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // High Scores Header
                        const Row(
                          children: [
                            Icon(Icons.emoji_events_outlined, color: Colors.amberAccent, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'TOP SWAT RECORDS',
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Top Scores List
                        if (scores.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'No high scores yet. Swat some bugs!',
                                style: TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                            ),
                          )
                        else
                          ...scores.take(5).toList().asMap().entries.map((entry) {
                            final int rank = entry.key + 1;
                            final int score = entry.value;
                            String rankMedal = '#$rank';
                            Color medalColor = Colors.white70;
                            if (rank == 1) {
                              rankMedal = '🥇';
                              medalColor = Colors.amber;
                            } else if (rank == 2) {
                              rankMedal = '🥈';
                              medalColor = Colors.grey.shade300;
                            } else if (rank == 3) {
                              rankMedal = '🥉';
                              medalColor = Colors.brown.shade300;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: rank == 1
                                    ? Colors.amber.withValues(alpha: 0.12)
                                    : Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: rank == 1 ? Colors.amber.withValues(alpha: 0.4) : Colors.white10,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        rankMedal,
                                        style: TextStyle(
                                          fontSize: rank <= 3 ? 18 : 14,
                                          fontWeight: FontWeight.bold,
                                          color: medalColor,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Round Record',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.8),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '$score pts',
                                    style: const TextStyle(
                                      color: Color(0xFF39FF14),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Back Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF39FF14),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 6,
                    ),
                    onPressed: () {
                      game.showOnlyOverlay('MainMenu');
                    },
                    child: const Text(
                      'BACK TO MENU',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  Widget _buildSpeciesKillCard({
    required String icon,
    required String name,
    required int count,
    required String points,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  points,
                  style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '$count',
            style: TextStyle(
              color: accentColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallBallLeaderboard(BuildContext context, BaseJestureGame game) {
    return FutureBuilder<List<int>>(
      future: ScoreManager.getScores(game.gameTitle),
      builder: (context, snapshot) {
        List<int> scores = snapshot.data ?? [];
        return Container(
          color: Colors.black.withValues(alpha: 0.9),
          child: Center(
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade900,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.cyanAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withValues(alpha: 0.3),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_mma, color: Colors.cyanAccent, size: 28),
                      SizedBox(width: 8),
                      Text('Fall Ball Top Scores', style: TextStyle(color: Colors.cyanAccent, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (scores.isEmpty)
                    const Text('No scores yet!', style: TextStyle(color: Colors.white70, fontSize: 18))
                  else
                    ...scores.take(10).toList().asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('#${entry.key + 1}', style: const TextStyle(color: Colors.white70, fontSize: 18)),
                            Text('${entry.value}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                    onPressed: () {
                      game.showOnlyOverlay('MainMenu');
                    },
                    child: const Text('BACK', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

