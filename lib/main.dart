import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flame/game.dart' hide Plane;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'base_jesture_game.dart';
import 'motion_game_arena.dart';
import 'hit_stars_arena.dart';
import 'score_manager.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;


List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    // Emulator safe-guard
  }
  runApp(const WristTrackerApp());
}

class WristTrackerApp extends StatelessWidget {
  const WristTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jesture',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  CameraController? _cameraController;
  late BaseJestureGame _gameArena;
  String _initialOverlay = 'MainMenu';
  
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions(
    mode: PoseDetectionMode.stream,
    model: PoseDetectionModel.base, // Using base model for low latency real-time performance
  ));
  
  bool _isProcessingFrame = false;
  CameraDescription? _frontCamera;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _gameArena = MotionGameArena();
    _initializePipeline();
  }

  Future<void> _initializePipeline() async {
    if (cameras.isEmpty) return;
    
    _frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      _frontCamera!,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();

    _cameraController!.startImageStream((CameraImage image) async {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;

      try {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage == null) return;

        final List<Pose> poses = await _poseDetector.processImage(inputImage);
        if (poses.isNotEmpty) {
          _handlePoseResults(poses.first);
        }
      } catch (e) {
        debugPrint("Vision pipeline error: $e");
      } finally {
        _isProcessingFrame = false;
      }
    });
    
    if (mounted) setState(() {});
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_frontCamera == null) return null;
    final sensorOrientation = _frontCamera!.sensorOrientation;
    
    InputImageRotation rotation;
    switch (sensorOrientation) {
      case 90:
        rotation = InputImageRotation.rotation90deg;
        break;
      case 180:
        rotation = InputImageRotation.rotation180deg;
        break;
      case 270:
        rotation = InputImageRotation.rotation270deg;
        break;
      default:
        rotation = InputImageRotation.rotation0deg;
    }

    final format = Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888;

    if (image.planes.isEmpty) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    _imageSize = Size(image.width.toDouble(), image.height.toDouble());

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: _imageSize!,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  void _handlePoseResults(Pose pose) {
    if (_imageSize == null) return;
    
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    final screenSize = MediaQuery.of(context).size;
    
    // Account for native rotation: image height maps to screen width space, image width to screen height space
    final double inputWidth = _imageSize!.height;
    final double inputHeight = _imageSize!.width;
    
    // Calculate the aspect ratio scale factor mirroring BoxFit.contain behavior
    final double scale = math.min(screenSize.width / inputWidth, screenSize.height / inputHeight);
    
    // Determine coordinate offsets caused by letterboxing (black bars)
    // We pass negative offsets because the physics engine natively subtracts them.
    final double offsetX = -(screenSize.width - inputWidth * scale) / 2;
    final double offsetY = -(screenSize.height - inputHeight * scale) / 2;
    
    _gameArena.updateFullPose(pose, scale, offsetX, offsetY, inputWidth);
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        backgroundColor: Colors.blueGrey.shade900,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.cyan),
              child: Text('Jesture Menu', style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.sports_basketball, color: Colors.white),
              title: const Text('Play Fall Ball', style: TextStyle(color: Colors.white, fontSize: 18)),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _gameArena = MotionGameArena();
                  _initialOverlay = 'MainMenu';
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.star, color: Colors.amberAccent),
              title: const Text('Play Hit Stars', style: TextStyle(color: Colors.amberAccent, fontSize: 18)),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _gameArena = HitStarsArena();
                  _initialOverlay = 'MainMenu';
                });
              },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white),
              title: const Text('About & Privacy', style: TextStyle(color: Colors.white, fontSize: 18)),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Colors.black87,
                    title: const Text('About', style: TextStyle(color: Colors.cyanAccent)),
                    content: const Text(
                      'Jesture is a computer vision motion tracking game.\n\n'
                      'Privacy Notice: We do NOT record, transmit, or store any of your camera feed or videos. '
                      'All pose detection math happens strictly on your device locally in real-time.',
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
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: _gameArena.isPlayingNotifier,
              builder: (context, isPlaying, child) {
                if (!isPlaying) return const SizedBox.shrink();
                return Container(
                  height: 50,
                  width: double.infinity,
                  color: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            _gameArena.pauseEngine();
                            _gameArena.overlays.add('PauseMenu');
                          },
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: ValueListenableBuilder<int>(
                          key: ValueKey('score_${_gameArena.hashCode}'),
                          valueListenable: _gameArena.scoreNotifier,
                          builder: (context, score, child) {
                            return Text('★ $score', style: const TextStyle(color: Colors.yellowAccent, fontSize: 24, fontWeight: FontWeight.bold));
                          },
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ValueListenableBuilder<int>(
                          key: ValueKey('lives_${_gameArena.hashCode}'),
                          valueListenable: _gameArena.livesNotifier,
                          builder: (context, lives, child) {
                            return Text('❤️ $lives', style: const TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold));
                          },
                        ),
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
                if (_cameraController != null && _cameraController!.value.isInitialized)
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _cameraController!.value.previewSize!.height,
                        height: _cameraController!.value.previewSize!.width,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  )
                else
            const Center(child: CircularProgressIndicator(color: Colors.cyan)),

          GameWidget(
            key: ValueKey(_gameArena.hashCode),
            game: _gameArena,
            overlayBuilderMap: {
              'MainMenu': (context, BaseJestureGame game) {
                bool isStars = game is HitStarsArena;
                String bgImage = isStars ? 'assets/images/hit_stars_bg.png' : 'assets/images/fall_ball_bg.png';
                String title = isStars ? 'HIT STARS' : 'FALL BALL';
                IconData titleIcon = isStars ? Icons.star : Icons.sports_basketball;
                Color themeColor = isStars ? Colors.amberAccent : Colors.cyan;
                String instructionsText = isStars 
                    ? '1. Stand 3-5 feet away.\n2. Punch the glowing stars before they disappear.\n3. You have 20 lives.'
                    : '1. Stand 3-5 feet away.\n2. Punch the falling balls to score points.\n3. Avoid missing them! You have 20 lives.';

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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(titleIcon, size: 80, color: themeColor),
                            const SizedBox(height: 20),
                            Text(title, style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 2)),
                            const SizedBox(height: 40),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor, 
                                foregroundColor: Colors.black, 
                                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                                elevation: 10,
                              ),
                              onPressed: () {
                                game.overlays.remove('MainMenu');
                                game.startDistanceValidation();
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
                                game.overlays.remove('MainMenu');
                                game.overlays.add('LeaderboardMenu');
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
                          onPressed: () {
                            Scaffold.of(ctx).openDrawer();
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
              'DistanceValidation': (context, BaseJestureGame game) {
                return Center(
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.cyanAccent, width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_front, size: 60, color: Colors.cyanAccent),
                        const SizedBox(height: 20),
                        const Text(
                          'DISTANCE VALIDATION',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Stand so your upper body fits the screen.',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        ValueListenableBuilder<String>(
                          valueListenable: game.distanceStatusNotifier,
                          builder: (context, status, child) {
                            Color statusColor = Colors.yellowAccent;
                            if (status == 'Perfect! Hold still...') statusColor = Colors.greenAccent;
                            if (status == 'Searching for body...') statusColor = Colors.redAccent;
                            
                            return Text(
                              status,
                              style: TextStyle(color: statusColor, fontSize: 22, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            );
                          },
                        ),
                        const SizedBox(height: 30),
                        TextButton(
                          onPressed: () {
                            game.isDistanceValidating = false;
                            game.overlays.remove('DistanceValidation');
                            game.startCountdown();
                          },
                          child: const Text('Skip & Start Anyway', style: TextStyle(color: Colors.white54, decoration: TextDecoration.underline)),
                        )
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
                          color: Colors.black.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.cyanAccent, width: 3),
                          boxShadow: [
                             BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
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
                            ElevatedButton.icon(
                              icon: const Icon(Icons.play_circle_fill, color: Colors.black),
                              label: const Text('WATCH AD TO REVIVE', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                              onPressed: () {
                                game.overlays.remove('GameOver');
                                game.overlays.add('AdSimulation');
                              },
                            ),
                            const SizedBox(height: 15),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.refresh, size: 24),
                              label: const Text('PLAY AGAIN (RESET)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyanAccent, 
                                foregroundColor: Colors.black, 
                                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                              ),
                              onPressed: () {
                                game.overlays.remove('GameOver');
                                game.resetGame();
                              },
                            ),
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: () {
                                game.overlays.remove('GameOver');
                                game.overlays.add('MainMenu');
                              },
                              child: const Text('Main Menu', style: TextStyle(color: Colors.white54, fontSize: 18)),
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
                return Stack(
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.amberAccent, width: 3),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock, size: 80, color: Colors.amberAccent),
                            const SizedBox(height: 20),
                            const Text('LEVEL 3 LOCKED', style: TextStyle(color: Colors.amberAccent, fontSize: 36, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),
                            const Text('You have reached 4000 points!', style: TextStyle(color: Colors.white, fontSize: 20)),
                            const SizedBox(height: 30),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Gateway Placeholder')));
                              },
                              child: const Text('UNLOCK FOR \$0.99', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: () {
                                game.overlays.remove('Paywall');
                                game.resetGame();
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
              'AdSimulation': (context, BaseJestureGame game) {
                return AdSimulationWidget(game: game);
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
                              game.overlays.remove('PauseMenu');
                              game.resumeEngine();
                            },
                          ),
                          const SizedBox(height: 15),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.exit_to_app, color: Colors.black),
                            label: const Text('LEAVE GAME', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                            onPressed: () {
                              game.overlays.remove('PauseMenu');
                              game.resumeEngine();
                              game.isPlayingNotifier.value = false;
                              ScoreManager.saveScore(game.gameTitle, game.score);
                              game.isGameOver = true;
                              game.overlays.add('MainMenu');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              'LeaderboardMenu': (context, BaseJestureGame game) {
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
                            border: Border.all(color: Colors.amberAccent, width: 2),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${game.gameTitle} Top Scores', style: const TextStyle(color: Colors.amberAccent, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                              const SizedBox(height: 20),
                              if (scores.isEmpty)
                                const Text('No scores yet!', style: TextStyle(color: Colors.white70, fontSize: 18))
                              else
                                ...scores.asMap().entries.map((entry) {
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
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                                onPressed: () {
                                  game.overlays.remove('LeaderboardMenu');
                                  game.overlays.add('MainMenu');
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
              },
            },
            initialActiveOverlays: [_initialOverlay],
          ),
        ],
      ),
    ),
          Container(
            height: 45,
            width: double.infinity,
            color: Colors.black,
            alignment: Alignment.center,
            child: const Text('GOOGLE ADS SPACE', style: TextStyle(color: Colors.white54, fontSize: 16, letterSpacing: 2)),
          ),
        ],
      ),
    ));
  }
}

class AdSimulationWidget extends StatefulWidget {
  final BaseJestureGame game;
  const AdSimulationWidget({super.key, required this.game});
  @override
  State<AdSimulationWidget> createState() => _AdSimulationWidgetState();
}

class _AdSimulationWidgetState extends State<AdSimulationWidget> {
  int _countdown = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        _timer?.cancel();
        widget.game.overlays.remove('AdSimulation');
        widget.game.resumeFromAd();
      }
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Icon(Icons.movie, size: 100, color: Colors.blueAccent),
             const SizedBox(height: 20),
             const Text("Simulating Ad...", style: TextStyle(color: Colors.white, fontSize: 32)),
             const SizedBox(height: 20),
             Text("Resuming in $_countdown", style: const TextStyle(color: Colors.yellowAccent, fontSize: 48, fontWeight: FontWeight.bold)),
          ]
        ),
      ),
    );
  }
}
