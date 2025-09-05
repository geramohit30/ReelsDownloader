# ProGuard rules for InstaReelDownloader
# Preserve networking functionality for release builds

# Keep all networking related classes
-keep class java.net.** { *; }
-keep class javax.net.** { *; }
-keep class org.apache.http.** { *; }

# Keep HTTP client classes
-keep class okhttp3.** { *; }
-keep class retrofit2.** { *; }

# Preserve SSL and certificate classes
-keep class javax.net.ssl.** { *; }
-keep class java.security.cert.** { *; }

# Keep DNS and network resolution classes
-keep class java.net.InetAddress { *; }
-keep class java.net.NetworkInterface { *; }

# Preserve Flutter networking
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep all classes that might be used by reflection
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve connectivity manager
-keep class android.net.** { *; }
-keep class android.telephony.** { *; }

# Don't warn about missing classes
-dontwarn okhttp3.**
-dontwarn retrofit2.**
-dontwarn javax.annotation.**

# Keep Instagram related URL patterns
-keep class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}