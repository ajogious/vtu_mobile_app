# ─────────────────────────────────────────────────────────────────────────────
# Flutter / Dart core
# ─────────────────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ─────────────────────────────────────────────────────────────────────────────
# Printing plugin (already present)
# ─────────────────────────────────────────────────────────────────────────────
-keep class net.nfet.flutter.printing.** { *; }

# ─────────────────────────────────────────────────────────────────────────────
# flutter_secure_storage – uses Android Keystore via reflection
# ─────────────────────────────────────────────────────────────────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ─────────────────────────────────────────────────────────────────────────────
# local_auth / biometrics
# ─────────────────────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.localauth.** { *; }

# ─────────────────────────────────────────────────────────────────────────────
# connectivity_plus
# ─────────────────────────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# ─────────────────────────────────────────────────────────────────────────────
# flutter_local_notifications
# ─────────────────────────────────────────────────────────────────────────────
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# ─────────────────────────────────────────────────────────────────────────────
# webview_flutter
# ─────────────────────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.webviewflutter.** { *; }

# ─────────────────────────────────────────────────────────────────────────────
# share_plus
# ─────────────────────────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.share.** { *; }

# ─────────────────────────────────────────────────────────────────────────────
# permission_handler
# ─────────────────────────────────────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }

# ─────────────────────────────────────────────────────────────────────────────
# package_info_plus
# ─────────────────────────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }

# ─────────────────────────────────────────────────────────────────────────────
# url_launcher
# ─────────────────────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.urllauncher.** { *; }

# ─────────────────────────────────────────────────────────────────────────────
# flutter_contacts
# ─────────────────────────────────────────────────────────────────────────────
-keep class com.github.faisalman.** { *; }

# ─────────────────────────────────────────────────────────────────────────────
# Hive – uses generated adapters via reflection
# ─────────────────────────────────────────────────────────────────────────────
-keep class com.hivedb.** { *; }
-keep @interface hive.annotations.*
-keepclassmembers class ** {
    @hive.annotations.HiveType *;
    @hive.annotations.HiveField *;
}

# ─────────────────────────────────────────────────────────────────────────────
# General – keep Serializable / JSON model classes intact
# ─────────────────────────────────────────────────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Keep all model/data classes (adjust package if needed)
-keep class com.a3tech.vtumobile.** { *; }

# Suppress warnings for known missing classes in third-party libs
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**
