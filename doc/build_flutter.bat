@echo off
echo ========================================
echo Flutter App - Build and Run Script
echo ========================================
echo.
echo This script performs the following steps:
echo 1. Get Flutter dependencies
echo 2. Build Flutter app
echo 3. Run Flutter app (if device connected)
echo.
echo Press any key to continue or Ctrl+C to cancel...
pause >nul

echo.
echo Step 1: Getting Flutter dependencies...
cd /d "%~dp0\flutter_app"
call flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Failed to get dependencies
    pause
    exit /b 1
)

echo.
echo Step 2: Building Flutter app...
call flutter build apk --release
if %errorlevel% neq 0 (
    echo ERROR: Failed to build app
    pause
    exit /b 1
)

echo.
echo Step 3: Checking for connected devices...
call flutter devices
echo.
echo If you see connected devices above, you can run:
echo flutter run
echo.
echo Or install the APK on your device from:
echo build\app\outputs\flutter-apk\app-release.apk
echo.

echo.
echo ========================================
echo Build completed successfully!
echo ========================================
echo.
echo APK available at: flutter_app\build\app\outputs\flutter-apk\app-release.apk
echo.
pause