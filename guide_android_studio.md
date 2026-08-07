# Complete Guide: Running & Testing Jesture in Android Studio

This comprehensive guide covers everything you need to run, test, and debug **Jesture** (featuring native **MediaPipe Hand Landmarker** + **Flame Engine**) smoothly from beginning to end using **Android Studio**.

---

## 🎯 Quick Answer: Can it run smoothly on your device?

| Testing Method | Smoothness / FPS | Hand Tracking Accuracy | Recommended For |
| :--- | :--- | :--- | :--- |
| **📱 Real Android Phone** *(via USB/Wi-Fi)* | ⚡ **Ultra Smooth (60 FPS)** | 🎯 **100% Real-time & Instant** | **Best Gameplay Experience & Real Testing** |
| **💻 Android Studio Emulator** *(with PC Webcam)* | 🟡 **Moderate (20-30 FPS)** | ✋ **Good (depends on PC Webcam/CPU)** | **Quick UI / Logic Checking without phone** |

> [!TIP]
> **Why is a Physical Phone better?**
> A real phone uses its dedicated GPU/NPU chip to compute MediaPipe hand landmarks in 5–10ms per frame. On an emulator, your PC CPU has to emulate an ARM processor *and* bridge your webcam frames into Android, which adds slight frame latency.

---

## 🚀 Part 1: Opening the Project in Android Studio

1. Open **Android Studio**.
2. Click **Open** (or `File` ➔ `Open...`).
3. Select the folder:
   ```
   c:\Users\ASUS\OneDrive\Desktop\Wrist_game
   ```
4. Click **OK**.
5. Wait 1–2 minutes while Android Studio indexes files and syncs Flutter dependencies. You will see a progress bar at the bottom status bar.
6. Make sure the **Flutter** and **Dart** plugins are installed in Android Studio (`Settings` ➔ `Plugins` ➔ search for `Flutter`).

---

## 📱 Method A: Testing on a Real Android Phone (Recommended for 60 FPS)

Running on your physical phone gives you full hardware acceleration, instant punch reaction, and true camera responsiveness.

### Step 1: Enable Developer Options & USB Debugging on your Phone
1. On your Android phone, go to **Settings** ➔ **About Phone**.
2. Tap **Build Number** 7 times rapidly until a toast appears saying *"You are now a developer!"*.
3. Go back to **Settings** ➔ **System** (or Additional Settings) ➔ **Developer Options**.
4. Turn on **USB Debugging**.

### Step 2: Connect Phone to PC
1. Connect your phone to your PC via a USB cable.
2. A popup will appear on your phone: *"Allow USB debugging?"* ➔ Check **"Always allow from this computer"** and tap **Allow**.

### Step 3: Run the Game
1. In Android Studio's top toolbar, click the **Device Selector Dropdown**.
2. You will see your phone's name (e.g., *Samsung SM-G998B*, *OnePlus*, *Pixel*, etc.).
3. Select your phone.
4. Click the **Green Run (▶)** button (or press `Shift + F10`).
5. **First Build Note:** The first Gradle build may take 2–4 minutes to download MediaPipe tasks and CameraX libraries.
6. Once launched, allow the **Camera Permission** prompt on your phone screen.
7. Stand 3–5 feet away, show both hands to calibrate, and enjoy the game!

---

## 💻 Method B: Testing on Android Studio Emulator (Using PC Webcam)

If you don't have your phone plugged in, you can configure an Android Emulator to use your laptop/PC's built-in webcam as the phone's front camera.

### Step 1: Open Device Manager
1. In Android Studio, look at the top right toolbar and click the **Device Manager** icon (looks like a phone with an Android robot), or go to `Tools` ➔ `Device Manager`.
2. Click **+ Create Device** (or **Create Virtual Device**).

### Step 2: Choose Hardware & System Image
1. Select **Phone** on the left category.
2. Choose **Pixel 8** or **Pixel 9** (or any modern phone with 1080x2400 resolution). Click **Next**.
3. In the **Release Name** tab, select **API 34 (Android 14 - UpsideDownCake)** or **API 35 (Android 15)**.
   *(If not downloaded yet, click the small Download arrow next to it).*
4. Click **Next**.

### Step 3: ⚠️ CRITICAL: Map Webcam to Front Camera
1. On the configuration page, click **Show Advanced Settings** at the bottom.
2. Scroll down to the **Camera** section:
   - **Front Camera**: Change from `Emulated` ➔ **`Webcam0`** *(This binds your laptop's real physical webcam!)*
   - **Back Camera**: Leave as `VirtualScene` (or `None`).
3. Under **Memory and Storage**:
   - RAM: Set to **2048 MB** (or 4096 MB for smoother emulation).
4. Click **Finish**.

### Step 4: Launch and Play
1. In Device Manager, click the **Play (▶)** icon next to your new Pixel device.
2. The phone window will pop up on your monitor.
3. In Android Studio's top toolbar device dropdown, select your running emulator.
4. Click the **Green Run (▶)** button.
5. When the app starts, your laptop webcam LED will turn on!
6. Raise your hands in front of your laptop webcam to test fist tracking and hit targets!

---

## 🛠️ Step-by-Step Testing Checklist & Game Flow

Once the app opens on your screen:

1. **Camera Permission**: Tap **Allow** when prompted.
2. **Main Menu**:
   - You can toggle between **Fall Ball** and **Hit Stars** using the top-left menu Drawer.
   - Click **HOW TO PLAY** to review game instructions.
   - Click **LEADERBOARD** to see saved top scores.
3. **Start Game & Calibration**:
   - Click **START GAME**.
   - The **Hand Detection** validation screen will appear.
   - Raise **both hands** in view of the camera. The status will turn green (`Perfect! Hold still...`) and a 2.5s timer will start.
   - *(You can also tap "Skip & Start Anyway" at any time).*
4. **Countdown**: `5... 4... 3... 2... 1... GO!`
5. **Gameplay**:
   - Move your fists in front of the camera — you will see the glowing blue and red fist trackers accurately follow your knuckles.
   - Punch the falling balls / glowing stars to score points.
   - Watch the lives counter in the top bar (20 lives).
6. **Pause / Resume**:
   - Tap the top-left **Back Arrow** button during gameplay to open the Pause Menu without losing game state.

---

## 🔍 Troubleshooting & Common Questions

### 1. The camera screen in the emulator is black or frozen
- **Cause**: Android Studio permissions or webcam device conflict.
- **Fix**: 
  1. Make sure no other app (like Zoom, Teams, or Windows Camera app) is using your webcam.
  2. Inside the emulator, go to **Settings ➔ Apps ➔ Jesture ➔ Permissions ➔ Camera ➔ Allow only while using the app**.
  3. Close the app and re-open it.

### 2. Gradle build error or MediaPipe dependency issue
- **Fix**:
  1. Open the Terminal tab at the bottom of Android Studio.
  2. Run:
     ```bash
     flutter clean
     flutter pub get
     ```
  3. Re-run `flutter run` or click the green Play button in Android Studio.

### 3. How to check real-time MediaPipe logs?
- In Android Studio, open the **Logcat** tab at the bottom.
- In the filter bar, type:
  ```
  HandLandmarkerService
  ```
- You will see real-time initialization and detection logs confirming MediaPipe is actively tracking hands.

### 4. Hot Reload & Fast Iteration
- While the game is running, you can press **`r`** in the Run console or click the **⚡ Yellow Lightning Bolt** (Flutter Hot Reload) to see UI and logic changes instantly without restarting the app!
