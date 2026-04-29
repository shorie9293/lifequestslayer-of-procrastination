# ---------------------------------------------------------------------------
# rpg_todo — ProGuard / R8 rules
# ---------------------------------------------------------------------------
# Keep source file names + line numbers so Play Console can symbolicate
# crashes via the uploaded mapping.txt.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ---------------------------------------------------------------------------
# Flutter engine
# ---------------------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ---------------------------------------------------------------------------
# Google Play Core (required by Flutter even if split install isn't used)
# ---------------------------------------------------------------------------
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ---------------------------------------------------------------------------
# flutter_local_notifications (uses Gson via reflection)
# ---------------------------------------------------------------------------
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ---------------------------------------------------------------------------
# in_app_purchase — Google Play Billing
# ---------------------------------------------------------------------------
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# ---------------------------------------------------------------------------
# Hive (reflection-free in this app, but keep safe defaults)
# ---------------------------------------------------------------------------
-keep class ** extends io.flutter.embedding.engine.plugins.FlutterPlugin { *; }

# Hive TypeAdapter とモデルクラスを R8 から保護（BUG-001 再発防止）
# これらのクラスが削除されると Hive が動作不能になりアプリが起動しなくなる
-keep class * extends hive.typeadapter.TypeAdapter { *; }
-keep class com.shorie.lifequest.** { *; }
-keep class **.GeneratedPluginRegistrant { *; }

# Hive がリフレクションでアクセスするフィールドを保護
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Flutter の GeneratedPluginRegistrant を保護
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# ---------------------------------------------------------------------------
# Kotlin metadata / coroutines
# ---------------------------------------------------------------------------
-keepclassmembers class kotlinx.** { *; }
-dontwarn kotlinx.**
-dontwarn kotlin.**

# ---------------------------------------------------------------------------
# AndroidX / Java desugaring
# ---------------------------------------------------------------------------
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
