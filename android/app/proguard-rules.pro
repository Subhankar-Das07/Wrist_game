# WorkManager
-keep class androidx.work.** { *; }
-keep class androidx.startup.** { *; }

# Google ML Kit Rules
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Google Play Services
-keepnames class com.google.android.gms.** { *; }

# Keep native methods for ML Kit
-keepclasseswithmembernames class * {
    native <methods>;
}
-keep class androidx.startup.** { *; }
