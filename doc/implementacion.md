# Guía de Implementación — Luxora Smart Lottery

## 1. Requisitos de Software

### Desarrollo local

| Software | Versión mínima | Descarga |
|----------|---------------|---------|
| Flutter SDK | 3.10.0 | https://flutter.dev/docs/get-started/install |
| Dart SDK | 3.0.0 | Incluido con Flutter |
| Node.js | 18.0.0 | https://nodejs.org |
| Python | 3.10.0 | https://python.org |
| Docker Desktop | 24.0.0 | https://docker.com/products/docker-desktop |
| Android Studio | Hedgehog (2023.1) | https://developer.android.com/studio |
| Git | 2.40.0 | https://git-scm.com |

### Herramientas opcionales

| Herramienta | Uso |
|-------------|-----|
| pgAdmin 4 | Administrar la base de datos PostgreSQL |
| Postman | Probar los endpoints del backend |
| VS Code | Editor alternativo a Android Studio |

---

## 2. Estructura del Proyecto

```
mobil.lot/
├── backend/              → API Node.js + Express + TypeScript
├── ai-service/           → Servicio Python + FastAPI (interpretación de sueños)
├── flutter_app/          → App móvil Flutter/Dart
├── migrations/           → Scripts SQL (001 al 006)
├── doc/                  → Documentación
├── docker-compose.yml    → Orquestación de servicios
└── .env                  → Variables de entorno
```

---

## 3. Variables de Entorno

### Archivo `.env` (raíz del proyecto)

```env
# Base de datos
DATABASE_URL=postgresql://sluser:changeme@postgres:5432/smartlottery
POSTGRES_DB=smartlottery
POSTGRES_USER=sluser
POSTGRES_PASSWORD=changeme

# Backend
JWT_SECRET=cambia_esto_por_un_secreto_seguro_de_32_caracteres
PORT=3000
NODE_ENV=development

# AI Service
AI_SERVICE_URL=http://ai-service:8000
AI_SERVICE_API_KEY=cambia_esto_por_una_api_key_segura
```

### Archivo `flutter_app/.env`

```env
# Para desarrollo local (navegador/emulador en la misma PC)
API_BASE_URL=http://localhost:3000

# Para emulador Android
# API_BASE_URL=http://10.0.2.2:3000

# Para dispositivo físico (usar IP local de tu PC)
# API_BASE_URL=http://192.168.1.X:3000
```

---

## 4. Instalación y Configuración Local

### Paso 1 — Clonar el repositorio

```bash
git clone <url-del-repositorio>
cd mobil.lot
```

### Paso 2 — Copiar variables de entorno

```bash
cp .env.example .env
cp backend/.env.example backend/.env
cp ai-service/.env.example ai-service/.env
cp flutter_app/.env.example flutter_app/.env
```

Editar cada `.env` con los valores correctos.

### Paso 3 — Levantar el backend con Docker

```bash
docker compose up --build
```

Esto levanta automáticamente:
- PostgreSQL en el puerto `5433`
- Backend Node.js en el puerto `3000`
- AI Service Python en el puerto `8000`
- Ejecuta todas las migraciones SQL (001 al 006)
- Crea los usuarios de prueba (seed)

### Paso 4 — Instalar dependencias Flutter

```bash
cd flutter_app
flutter pub get
```

### Paso 5 — Correr la app

**En el navegador (más rápido para desarrollo):**
```bash
flutter run -d edge
```

**En emulador Android:**
```bash
flutter run -d emulator-5554
```

**En dispositivo físico:**
```bash
flutter run
```

---

## 5. Credenciales de Prueba

| Rol | Email | Contraseña |
|-----|-------|-----------|
| Usuario normal | jesusenmanuelperezreynoso@gmail.com | jesus123 |
| Super Administrador | admin@luxora.com | jesus123 |

---

## 6. Migraciones de Base de Datos

Las migraciones se ejecutan automáticamente al iniciar Docker por primera vez. Si necesitas aplicarlas manualmente:

```bash
docker exec -i mobillot-postgres-1 psql -U sluser -d smartlottery < backend/migrations/001_initial_schema.sql
docker exec -i mobillot-postgres-1 psql -U sluser -d smartlottery < backend/migrations/002_commitment_form_signature.sql
docker exec -i mobillot-postgres-1 psql -U sluser -d smartlottery < backend/migrations/003_advanced_engine_tables.sql
docker exec -i mobillot-postgres-1 psql -U sluser -d smartlottery < backend/migrations/004_multi_lottery_support.sql
docker exec -i mobillot-postgres-1 psql -U sluser -d smartlottery < backend/migrations/005_seed_users.sql
docker exec -i mobillot-postgres-1 psql -U sluser -d smartlottery < backend/migrations/006_contract_photo_location.sql
```

---

## 7. Carga de Datos Históricos

Para que el motor estadístico funcione correctamente, se deben cargar resultados históricos de sorteos:

1. Iniciar sesión con la cuenta de Super Administrador
2. Tocar el ícono de escudo en el header → Panel Admin
3. Ir a **"Carga de resultados"**
4. Configurar:
   - URL: `https://loteriasdominicanas.com/leidsa/loto-mas`
   - Fecha desde: `01/01/2021`
   - Fecha hasta: fecha actual
   - Días: Miércoles y Sábado
5. Presionar **EJECUTAR SCRAPER**

El proceso puede tardar varios minutos dependiendo del rango de fechas.

---

## 8. Despliegue en Producción

### Backend y Base de Datos

**Opción recomendada: VPS con Docker**

1. Servidor Ubuntu 22.04 LTS mínimo con 2 GB RAM
2. Instalar Docker y Docker Compose
3. Clonar el repositorio en el servidor
4. Configurar `.env` con valores de producción:
   - `NODE_ENV=production`
   - `JWT_SECRET` con valor aleatorio seguro (mínimo 32 caracteres)
   - `DATABASE_URL` apuntando al servidor de DB
5. Configurar un dominio y certificado SSL (Let's Encrypt)
6. Usar Nginx como reverse proxy hacia el puerto 3000

```bash
docker compose -f docker-compose.yml up -d
```

**Servicios cloud alternativos:**
- Railway.app — backend + PostgreSQL
- Render.com — backend + PostgreSQL
- Fly.io — backend + PostgreSQL
- Supabase — solo PostgreSQL

### App Móvil Android — Google Play Store

**Requisitos:**
- Cuenta de desarrollador Google Play ($25 pago único)
- Android Studio instalado
- JDK 17+

**Pasos:**

1. Generar keystore de firma:
```bash
keytool -genkey -v -keystore luxora-release.jks -keyAlias luxora -keyalg RSA -keysize 2048 -validity 10000
```

2. Configurar `flutter_app/android/key.properties`:
```properties
storePassword=<contraseña>
keyPassword=<contraseña>
keyAlias=luxora
storeFile=../luxora-release.jks
```

3. Actualizar `flutter_app/.env` con la URL de producción:
```env
API_BASE_URL=https://api.luxora.com
```

4. Compilar App Bundle para Play Store:
```bash
cd flutter_app
flutter build appbundle --release
```

El archivo se genera en: `flutter_app/build/app/outputs/bundle/release/app-release.aab`

5. Subir el `.aab` a Google Play Console → Producción

---

### App Móvil iOS — Apple App Store

**Requisitos:**
- Mac con macOS 13+ (Ventura o superior) — **obligatorio para compilar iOS**
- Xcode 15+ instalado desde la App Store
- Cuenta de desarrollador Apple ($99/año)
- iPhone o iPad para pruebas (o simulador)

**Pasos:**

1. Instalar dependencias iOS:
```bash
cd flutter_app
flutter pub get
cd ios
pod install
```

2. Abrir el proyecto en Xcode:
```bash
open ios/Runner.xcworkspace
```

3. En Xcode:
   - Seleccionar el target `Runner`
   - En `Signing & Capabilities` → seleccionar tu Team (cuenta Apple Developer)
   - Cambiar el Bundle Identifier a uno único: `com.luxora.smartlottery`

4. Actualizar `flutter_app/.env` con la URL de producción:
```env
API_BASE_URL=https://api.luxora.com
```

5. Compilar para release:
```bash
flutter build ipa --release
```

El archivo `.ipa` se genera en: `flutter_app/build/ios/ipa/`

6. Subir a App Store Connect con Xcode o Transporter
7. Completar la información de la app en App Store Connect y enviar para revisión

---

### Permisos requeridos en iOS (`Info.plist`)

Agregar en `flutter_app/ios/Runner/Info.plist`:

```xml
<!-- Cámara -->
<key>NSCameraUsageDescription</key>
<string>Luxora necesita acceso a la cámara para capturar la foto del firmante en el contrato de compromiso.</string>

<!-- Ubicación -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Luxora necesita tu ubicación para registrarla en el contrato de compromiso.</string>

<!-- Galería de fotos -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Luxora puede acceder a tu galería para seleccionar una foto de perfil.</string>
```

---

## 9. Permisos Requeridos

### Android (`AndroidManifest.xml`)

```xml
<!-- Internet -->
<uses-permission android:name="android.permission.INTERNET"/>

<!-- Cámara (foto del firmante en contrato) -->
<uses-permission android:name="android.permission.CAMERA"/>

<!-- Ubicación (geolocalización en contrato) -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

### iOS (`Info.plist`)

```xml
<key>NSCameraUsageDescription</key>
<string>Luxora necesita acceso a la cámara para capturar la foto del firmante en el contrato de compromiso.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Luxora necesita tu ubicación para registrarla en el contrato de compromiso.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Luxora puede acceder a tu galería para seleccionar una foto de perfil.</string>
```

---

## 10. Comandos Útiles

| Comando | Descripción |
|---------|-------------|
| `docker compose up --build` | Levantar todos los servicios |
| `docker compose down -v` | Detener y borrar la DB |
| `docker compose logs backend` | Ver logs del backend |
| `docker logs mobillot-backend-1` | Logs del contenedor backend |
| `flutter run -d edge` | Correr en navegador Edge |
| `flutter run -d emulator-5554` | Correr en emulador Android |
| `flutter build apk --release` | Compilar APK de producción |
| `flutter analyze` | Verificar errores en el código Flutter |
| `npx tsc --noEmit` | Verificar errores TypeScript en backend |

---

## 11. Solución de Problemas Comunes

### "No pubspec.yaml file found"
Estás en la carpeta equivocada. Navega a `flutter_app/` antes de correr comandos Flutter.

### "Error inesperado" al iniciar sesión
El backend no está corriendo. Verifica con `docker ps` que los contenedores estén activos.

### "Credenciales inválidas" después de `docker compose down -v`
La DB se borró. Los usuarios se recrean automáticamente al levantar Docker de nuevo.

### El scraper no encuentra datos
El sitio web puede haber cambiado su estructura HTML. Verificar la URL y ajustar el parser en `scraper.service.ts`.

### La app no conecta al backend desde el emulador
Cambiar `API_BASE_URL` de `localhost` a `10.0.2.2` en `flutter_app/.env`.
