# Smart Lottery App

Aplicación móvil de lotería inteligente con análisis de sueños mediante IA. Permite a los usuarios generar combinaciones de números basadas en la interpretación de sus sueños, gestionar jugadas y consultar resultados históricos.

## Stack tecnológico

| Capa | Tecnología |
|------|-----------|
| Mobile | Flutter 3.x |
| Backend | Node.js + TypeScript + Express |
| AI Service | Python + FastAPI |
| Base de datos | PostgreSQL 16 |
| Infraestructura | Docker + Docker Compose |

## Prerrequisitos

- Flutter ≥ 3.10
- Node.js ≥ 18.0 (solo desarrollo local sin Docker)
- Python ≥ 3.10 (solo desarrollo local sin Docker)
- Docker ≥ 24.0 con Docker Compose v2

## Setup rápido

```bash
# 1. Clonar el repositorio
git clone <repo-url>
cd smart-lottery-app

# 2. Copiar variables de entorno
cp .env.example .env
cp backend/.env.example backend/.env
cp ai-service/.env.example ai-service/.env

# 3. Editar los .env con tus valores y levantar servicios
docker compose up -d

# 4. App Flutter
cd flutter_app
flutter pub get
flutter run
```

## Variables de entorno (backend/.env)

| Variable | Descripción |
|----------|-------------|
| `DATABASE_URL` | Cadena de conexión PostgreSQL |
| `JWT_SECRET` | Secreto JWT (mín. 32 caracteres) |
| `AI_SERVICE_URL` | URL del servicio de IA |
| `AI_SERVICE_API_KEY` | API key compartida con el AI service |
| `PORT` | Puerto del backend (default: 3000) |
| `NODE_ENV` | Entorno (`development` / `production`) |
| `POSTGRES_DB` | Nombre de la base de datos |
| `POSTGRES_USER` | Usuario de PostgreSQL |
| `POSTGRES_PASSWORD` | Contraseña de PostgreSQL |

## Comandos útiles

```bash
# Levantar servicios
docker compose up -d

# Ver logs del backend
docker compose logs -f backend

# Detener servicios
docker compose down

# Tests backend
cd backend && npm test

# Tests AI service
cd ai-service && python -m pytest
```

## Estructura del proyecto

```
smart-lottery-app/
├── backend/              # API REST (Node.js + TypeScript)
│   ├── src/
│   │   ├── controllers/
│   │   ├── services/
│   │   ├── repositories/
│   │   ├── middlewares/
│   │   └── config/
│   ├── migrations/       # Esquema SQL inicial
│   └── Dockerfile
├── ai-service/           # Servicio de análisis de sueños (Python + FastAPI)
│   ├── app/
│   │   ├── routers/
│   │   ├── services/
│   │   └── models/
│   └── Dockerfile
├── flutter_app/          # App móvil (Flutter)
│   └── lib/
│       ├── core/         # API client, router, utils
│       └── features/     # auth, dreams, lottery, payments
└── docker-compose.yml
```

## Asignar rol SuperAdmin

Ejecutar directamente en PostgreSQL (reemplaza el email):

```sql
UPDATE users
SET is_super_admin = true, is_admin = true
WHERE email = 'tu@email.com';
```

Acceso rápido vía Docker:

```bash
docker compose exec postgres psql -U sluser -d smartlottery \
  -c "UPDATE users SET is_super_admin = true, is_admin = true WHERE email = 'tu@email.com';"
```
