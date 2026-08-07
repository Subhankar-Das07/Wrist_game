# App classes
-keep class com.subhankardas.jesture.** { *; }
-keep interface com.subhankardas.jesture.** { *; }

# Razorpay
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# MediaPipe Tasks, Vision, Framework & Native Loaders
-keep class com.google.mediapipe.** { *; }
-keep class com.google.mediapipe.tasks.** { *; }
-keep class com.google.mediapipe.framework.** { *; }
-dontwarn com.google.mediapipe.**

# Protobuf
-keep class com.google.protobuf.** { *; }
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite { *; }
-keep class com.google.common.** { *; }
-dontwarn com.google.protobuf.**
-dontwarn com.google.common.**

# CameraX
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# WorkManager & Startup
-keep class androidx.work.** { *; }
-keep class androidx.startup.** { *; }

# Flutter Engine & Plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve stack traces and annotations for reflection
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable
