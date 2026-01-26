# OkHttp
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn okhttp3.internal.platform.**

# Keep OkHttp
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Supabase / Realtime
-keep class io.supabase.** { *; }
-keep class com.google.gson.** { *; }

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Core
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Kakao SDK
-keep class com.kakao.** { *; }
-dontwarn com.kakao.**

# Naver SDK
-keep class com.naver.nid.** { *; }
-dontwarn com.naver.nid.**

# Geolocator (Google Play Services Location)
-keep class com.google.android.gms.location.** { *; }
-dontwarn com.google.android.gms.**

# Flutter Background Service
-keep class id.flutter.flutter_background_service.** { *; }

# Model classes (JSON serialization)
-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
