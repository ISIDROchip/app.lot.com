@echo off
cd /d "%~dp0\.."
echo ========================================
echo Smart Lottery App - Deployment Script
echo ========================================
echo.
echo This script performs the following steps:
echo 1. Install backend dependencies
echo 2. Build the backend
echo 3. Stop Docker containers
echo 4. Rebuild and start Docker services
echo 5. Check backend logs
echo.
echo Press any key to continue or Ctrl+C to cancel...
pause >nul

echo.
echo Step 1: Installing backend dependencies...
cd backend
call npm install
if %errorlevel% neq 0 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)

echo.
echo Step 2: Building the backend...
call npm run build
if %errorlevel% neq 0 (
    echo ERROR: Failed to build backend
    pause
    exit /b 1
)

echo.
echo Step 3: Stopping Docker containers...
cd .
docker compose down
if %errorlevel% neq 0 (
    echo ERROR: Failed to stop containers
    pause
    exit /b 1
)

echo.
echo Step 4: Rebuilding and starting Docker services...
docker compose up --build -d
if %errorlevel% neq 0 (
    echo ERROR: Failed to start services
    pause
    exit /b 1
)

echo.
echo Step 5: Checking backend logs...
timeout /t 5 /nobreak >nul
docker compose logs backend --tail 20

echo.
echo ========================================
echo Deployment completed successfully!
echo ========================================
echo.
echo Services should now be running with the latest changes.
echo Backend: http://localhost:3000
echo.
pause