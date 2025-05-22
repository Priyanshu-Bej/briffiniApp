@echo off
echo Building Flutter app...
flutter clean
flutter pub get
flutter build apk --release
echo Build completed.
echo If successful, the APK should be at:
echo build\app\outputs\flutter-apk\app-release.apk 