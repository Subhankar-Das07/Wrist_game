# Android Studio Beginner's Guide: Running Jesture on a Pixel 9

Welcome to Android Studio! Since you are using it for the very first time, this guide will walk you through exactly how to set up a Pixel 9 emulator, run your game, and troubleshoot the unique challenges of running a camera-based game on a virtual device.

## Step 1: Open the Project in Android Studio
1. Open **Android Studio**.
2. Click **Open** (or `File > Open` if you have a project open).
3. Navigate to `C:\Users\ASUS\OneDrive\Desktop\Wrist_game` and select the folder.
4. Wait a minute or two for Android Studio to index the files and load the Flutter plugins. (You might see a loading bar at the very bottom right).

## Step 2: Create the Pixel 9 Emulator
To see the game simultaneously on your computer, we need to create an Android Virtual Device (AVD).

1. In the top right corner of Android Studio, click the **Device Manager** icon (it looks like a phone with a small Android logo).
2. Click the **+ Create Device** button.
3. In the "Phone" category, scroll down and select **Pixel 9** (or Pixel 8 if 9 isn't listed in your Studio version yet), then click **Next**.
4. You will see a list of System Images (Android versions). Look for **UpsideDownCake (API 34)** or **VanillaIceCream (API 35)**.
5. If there is a **Download** icon next to it, click it and wait for the download to finish. 
6. Select that system image and click **Next**.
7. **CRITICAL STEP FOR CAMERA:** Click **Show Advanced Settings**. Scroll down to the **Camera** section.
   - Set **Front** to **Webcam0** (This connects your laptop's real webcam to the emulator's front camera!).
   - Set **Back** to **VirtualScene**.
8. Click **Finish**.

## Step 3: Run the Game
1. In the Device Manager, click the **Play** button (▶) next to your newly created Pixel 9. An interactive phone window will pop up on your screen.
2. In the top toolbar of Android Studio, look for the **Device Dropdown** (it might say "Windows (desktop)" initially). Click it and select your running **Pixel 9 API 34** emulator.
3. To the right of the dropdown, click the **Green Play Button** (▶) (Run 'main.dart').
4. Android Studio will now compile the app and launch it on the Pixel 9 emulator.

---

## ⚠️ Known Issues & Troubleshooting

Since you are running an intense Machine Learning Camera app on a *simulated* phone, you must be aware of the following:

> **Emulator Performance (Lag)**
> Emulators do not have access to a physical Neural Processing Unit (NPU) like your real phone does. ML Kit Pose Detection is forced to run on simulated CPU cores. **The fist tracking will be significantly slower and choppier on the emulator than on your real phone.** This is completely normal! Always use your physical phone for true performance testing.

> **Camera Permissions Crashing**
> When the app first opens on the emulator, it will ask for Camera Permissions. If the emulator freezes or the camera shows a black screen:
> 1. Close the app.
> 2. Go to the emulator's home screen.
> 3. Long-press your app icon -> App Info -> Permissions.
> 4. Manually grant the Camera permission, then reopen the app.

> **Laptop Webcam Aspect Ratio**
> Your laptop webcam is likely a 16:9 landscape camera. Because of our `BoxFit.contain` optimization, the game will perfectly display your wide laptop camera feed on the tall Pixel 9 screen by adding cinematic black bars at the top and bottom.

## Summary Checklist
1. Open Project.
2. Create Pixel 9 in Device Manager (Enable Webcam0).
3. Start Emulator.
4. Select Emulator in dropdown.
5. Click Run.
