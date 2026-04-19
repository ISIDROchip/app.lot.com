@echo off
echo =======================================
echo     RECARGANDO Y RECONSTRUYENDO
echo =======================================
echo.
echo Reconstruyendo los contenedores... (esto aplicara tus cambios en el codigo y en el .env)
docker compose up -d --build

echo.
echo =======================================
echo     SERVICIOS ACTUALIZADOS
echo =======================================
docker compose ps
echo.
echo Puedes ver los logs del backend usando: docker compose logs -f backend
pause
