# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-dontwarn io.flutter.embedding.**
-ignorewarnings

# WebView (if used)
-keep class android.webkit.WebView { *; }

# Keep generic classes
-keepattributes SourceFile,LineNumberTable
