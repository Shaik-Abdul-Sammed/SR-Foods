# ==============================================================================
# SR Foods Android ProGuard / R8 Optimization & Obfuscation Rules
# ==============================================================================

# --- Flutter Engine & Core Platform Channels ---
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }

# --- AndroidX Core & Startup ---
-keep class androidx.startup.** { *; }
-keep class androidx.startup.InitializationProvider { *; }
-keep class androidx.core.app.NotificationCompat** { *; }
-keep class androidx.core.content.FileProvider { *; }

# --- WorkManager & Background Tasks ---
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.WorkDatabase_Impl$* { *; }
-keep class androidx.work.impl.background.systemalarm.** { *; }
-keep class androidx.work.impl.background.systemjob.** { *; }
-keep class be.tramckas.workmanager.** { *; }
-keep class dev.fluttercommunity.workmanager.** { *; }

# --- Room Database (Used by WorkManager) ---
-keep class androidx.room.** { *; }
-keep class androidx.room.RoomDatabase { *; }
-keep class * extends androidx.room.RoomDatabase { *; }

# --- Drift / SQLite3 Native JNI & Isolates ---
-keep class org.sqlite.** { *; }
-keep class com.simolus3.sqlite3.** { *; }
-keep class eu.simonbinder.sqlite3.** { *; }
-keepclasseswithmembers class * {
    native <methods>;
}

# --- Flutter Local Notifications ---
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.** { *; }

# --- Flutter Secure Storage & Jetpack Security Crypto ---
-keep class androidx.security.crypto.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# --- Local Auth & Biometrics ---
-keep class io.flutter.plugins.localauth.** { *; }
-keep class androidx.biometric.** { *; }

# --- Mobile Scanner / ML Kit ---
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }

# --- File Picker & Sharing ---
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class crazecoder.openfile.** { *; }
-keep class net.nfet.flutter.printing.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }

# --- Flutter Contacts ---
-keep class co.quis.flutter_contacts.** { *; }

# --- Keep Serializable and Parcelable Models ---
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Don't warn about optional missing third party classes during bytecode shrinking
-dontwarn androidx.work.**
-dontwarn io.flutter.**
-dontwarn com.google.crypto.tink.**
