# Flutter ve Firebase için özel ProGuard kuralları
# Bu dosya release build sırasında kod optimizasyonu ve obfuscation için kullanılır

# Flutter Framework kuralları
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Flutter Engine kuralları
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.android.** { *; }

# Firebase kuralları
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Auth kuralları
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.auth.internal.** { *; }

# Firestore kuralları
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.cloud.firestore.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Firebase Functions kuralları
-keep class com.google.firebase.functions.** { *; }

# Firebase Storage kuralları
-keep class com.google.firebase.storage.** { *; }

# Firebase Messaging kuralları
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# Firebase Crashlytics kuralları
-keep class com.google.firebase.crashlytics.** { *; }
-keep class com.google.firebase.crashlytics.internal.** { *; }
-dontwarn com.google.firebase.crashlytics.**
-keepattributes SourceFile,LineNumberTable

# Firebase Analytics kuralları
-keep class com.google.firebase.analytics.** { *; }
-keep class com.google.android.gms.measurement.** { *; }
-dontwarn com.google.firebase.analytics.**

# Google Sign In kuralları
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Apple Sign In kuralları (Sign in with Apple plugin)
-keep class com.aboutyou.dart_packages.sign_in_with_apple.** { *; }

# Local Notifications kuralları
-keep class com.dexterous.** { *; }
-keep class androidx.core.app.NotificationCompat** { *; }

# HTTP kuralları
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Gson kuralları (JSON serialization için)
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Model sınıfları için genel koruma (JSON serialization)
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Reflection kuralları
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Genel Android kuralları
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.app.backup.BackupAgentHelper
-keep public class * extends android.preference.Preference

# View constructor kuralları
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# Kotlin kuralları
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# AndroidX kuralları
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-dontwarn androidx.**

# WebView kuralları
-keepclassmembers class fqcn.of.javascript.interface.for.webview {
   public *;
}
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, java.lang.String, android.graphics.Bitmap);
    public boolean *(android.webkit.WebView, java.lang.String);
}
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, jav.lang.String);
}

# R8 optimizasyonları
-allowaccessmodification
-repackageclasses ''

# Debug bilgilerini koru (crash raporları için)
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Enum sınıfları için özel koruma
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Native method kuralları
-keepclasseswithmembernames class * {
    native <methods>;
}

# Parcelable kuralları
-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# Serializable kuralları
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Aggressive optimizasyonlar
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-overloadaggressively

# Crash olmayan uyarıları yoksay
-dontwarn javax.annotation.**
-dontwarn javax.inject.**
-dontwarn sun.misc.Unsafe
-dontwarn com.google.common.util.concurrent.ListenableFuture

# Network Security Config
-keep class android.security.NetworkSecurityPolicy {
    *;
}

# Flutter plugins için genel koruma
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

# Projenize özel model sınıfları (gerekirse ekleyin)
# -keep class com.codenzi.taktik.models.** { *; }

# Release'te Log çağrılarını kaldır (bilgi sızıntısını azalt)
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
    public static *** wtf(...);
}

# Firebase App Check ve Play Integrity API kuralları (SafetyNet yerine)
-keep class com.google.firebase.appcheck.** { *; }
-keep class com.google.android.play.core.integrity.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.firebase.appcheck.**
-dontwarn com.google.android.play.core.integrity.**

# Play Services Base kuralları
-keep class com.google.android.gms.base.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# SafetyNet deprecated - Play Integrity kullanımı için kurallar
-dontwarn com.google.android.gms.safetynet.**
