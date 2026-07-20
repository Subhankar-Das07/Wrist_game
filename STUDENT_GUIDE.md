# 🎓 The Jesture Project: A Student's Guide

Welcome to **Jesture**! If you are a fresher or a student joining this project, this guide is designed specifically for you. It will take you step-by-step through what this app does, how the underlying technologies work together, and how the codebase is structured.

Grab a coffee, and let's dive into the architecture of a real-time Computer Vision Game! ☕

---

## 1. What is "Jesture"?
**Jesture** is an interactive mobile game built with Flutter. Instead of using a touchscreen or a controller, the user plays the game using their physical body movements. 

The app uses the phone's front-facing camera to track the player's body in real-time. When the player punches their left or right fist in the air, a virtual fist on the screen moves to exactly the same spot! We use this mechanic to power two mini-games:
1. **Fall Ball:** Balls fall from the sky, and you must punch them before they hit the ground.
2. **Hit Ball:** Targets appear at random locations and slowly shrink; you must punch them before their time runs out.

---

## 2. The Technology Stack
To make this magic happen seamlessly at 60 FPS (frames per second), we combine three powerful technologies:

1. **Flutter:** The core UI framework. It handles the app's screens, the navigation drawer, and the buttons you press.
2. **Google ML Kit (Pose Detection):** This is the "Brain". It takes the raw video feed from the camera, runs a Machine Learning model locally on the phone, and figures out exactly where the user's shoulders, wrists, and elbows are.
3. **Flame Engine:** This is the "Game Engine". Flutter is great for apps, but bad at running physics, collision detection, and particle explosions. Flame sits *inside* Flutter and handles all the game logic, gravity, and rendering of the balls.

---

## 3. The Architecture Flow
Understanding how data flows through the app is the most important concept to grasp. Here is the lifecycle of a single frame (which happens 30-60 times every second!):

```text
📸 1. Camera    --> Grabs a picture from the front camera.
🧠 2. ML Kit    --> Analyzes the picture, finds the user's X/Y coordinates for their wrists.
🧮 3. main.dart --> Converts the camera's X/Y coordinates to match the phone's screen size.
🎮 4. Flame     --> Updates the virtual fists on the screen to match the user's real fists.
💥 5. Physics   --> Checks if the virtual fist collided with a Ball. If yes, add score!
```

---

## 4. Codebase Structure
We follow a very clean Object-Oriented approach. Here is what every file does:

### `lib/main.dart` (The Orchestrator)
This is where the app starts. It does three major things:
- It opens the `CameraController` and starts streaming images.
- It feeds those images into the `PoseDetector` (ML Kit).
- It displays the `GameWidget` (the Flame Engine canvas) right on top of the camera feed so you can see yourself playing.
- It contains the **Main Menu**, the **Drawer**, and the logic to swap between games.

### `lib/base_jesture_game.dart` (The Foundation)
Because we have two different games (Fall Ball and Hit Ball) that share the exact same mechanics (Score, Lives, Distance Validation, and Fist Tracking), we put all that shared logic here. 
- It defines the `FistTrackerComponent` (the glowing circles on the screen).
- It contains the `updateFullPose` function, which receives the wrist coordinates from `main.dart` and smoothly moves the fists.

### `lib/motion_game_arena.dart` (Fall Ball Game)
This extends `BaseJestureGame`. It only contains logic specific to the falling balls.
- It uses an `update` loop to spawn `TargetBall` objects every few seconds.
- It controls the gravity and speed of the balls as your score increases.

### `lib/hit_ball_arena.dart` (Hit Ball Game)
This also extends `BaseJestureGame`. 
- Instead of falling balls, it spawns `StaticHitBall` objects at random coordinates.
- It manages the timers that make the balls shrink and disappear.

---

## 5. Deep Dive: How the Flame Engine Works
If you haven't used a game engine before, you need to understand the **Game Loop**. Unlike traditional apps that wait for a user to click a button, a game engine runs a continuous loop over and over again.

In Flame, every component (like a Ball or a Fist) has two main methods:

1. **`update(double dt)`:** This is the math phase. `dt` stands for "Delta Time" (the fraction of a second since the last frame). In this method, you update X/Y positions, decrease timers, or calculate gravity. **No drawing happens here.**
2. **`render(Canvas canvas)`:** This is the painting phase. Based on the math calculated in `update`, you use the `canvas` to draw circles, images, or colors on the screen.

### Example from `StaticHitBall`:
```dart
@override
void update(double dt) {
  super.update(dt);
  _timeRemaining -= dt; // Math: Decrease the timer by a fraction of a second
  
  if (_timeRemaining <= 0) {
    removeFromParent(); // Math: The time is up, delete this ball!
  }
}

@override
void render(Canvas canvas) {
  // Paint: Draw a cyan circle on the screen at our current size
  canvas.drawCircle(Offset(radius, radius), radius, paint); 
}
```

---

## 6. Your First Steps as a Developer
If you are tasked with adding a new feature, here is how you should think:

1. **Changing UI?** (Menus, Buttons, Dialogs) -> Look in `main.dart`. We use standard Flutter Widgets for overlays.
2. **Adding a New Game Mode?** -> Create a new file (e.g., `dodge_ball_arena.dart`), make it extend `BaseJestureGame`, and write your custom `update` loop. Then, add a button to the Drawer in `main.dart` to launch it.
3. **Changing the Fists/Tracking?** -> Look in `base_jesture_game.dart`. That's where ML Kit coordinates are converted into screen coordinates.

Good luck, and have fun building the future of motion gaming! 🚀
