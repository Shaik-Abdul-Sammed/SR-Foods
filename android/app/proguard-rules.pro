# Flutter WorkManager Plugin / AndroidX WorkManager
# Prevents R8/ProGuard from stripping the generated WorkDatabase_Impl and InitializationProvider
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.WorkDatabase_Impl$* { *; }
-keep class androidx.startup.InitializationProvider { *; }

# Keep Room classes used by WorkManager
-keep class androidx.room.RoomDatabase { *; }
-keep class * extends androidx.room.RoomDatabase { *; }

# Broad keep rule as fallback for AndroidX WorkManager components
-keep class androidx.work.** { *; }
