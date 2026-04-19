# Design Document — Smart Lottery App

## Overview

Smart Lottery App es una aplicación móvil multiplataforma construida con Flutter que se comunica con un backend Node.js/TypeScript y un microservicio de IA en Python. El sistema permite a usuarios mayores de edad interpretar sueños para obtener números sugeridos, analizar estadísticas históricas de sorteos, generar jugadas optimizadas y consultar su historial personal.

### Principios de diseño

- **Separación de responsabilidades**: cada capa tiene una única responsabilidad bien definida.
- **Contrato primero**: los endpoints y DTOs se definen antes de la implementación.
- **Producción desde el inicio**: configuración de seguridad, logging y manejo de errores incluidos desde el día uno.
- **Stateless backend**: el estado de sesión vive en el JWT; el backend no mantiene sesiones en memoria.

---

## Architecture

### Diagrama general

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App (Mobile)                      │
│              iOS / Android / Web (future)                        │
└───────────────────────────┬─────────────────────────────────────┘
                            │ HTTPS / REST JSON
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Node.js / Express API Gateway                   │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│   │ Auth Service │  │Stats Service │  │   Lottery Service    │  │
│   └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘  │
│          │                 │                      │              │
│   ┌──────▼─────────────────▼──────────────────────▼───────────┐  │
│   │              Repository Layer (TypeORM / pg)               │  │
│   └──────────────────────────┬────────────────────────────────┘  │
└──────────────────────────────┼──────────────────────────────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                ▼
     ┌─────────────┐  ┌──────────────┐  ┌──────────────┐
     │ PostgreSQL  │  │  Dream Svc   │  │  (future     │
     │  Database   │  │ Python/FastAPI│  │   services)  │
     └─────────────┘  └──────────────┘  └──────────────┘
```

### Flujo de una petición típica

```
Flutter → HTTPS POST /lottery/request-number
  → JWT Middleware (valida token)
  → LotteryController.requestNumber()
  → LotteryService.generate(tipo, userId)
    → StatsService.getFrequencies()   (datos internos)
  → LotteryRepository.save(jugada)
  → HTTP 201 { numbers, tipo, timestamp }
```

### Comunicación entre servicios

| Origen          | Destino         | Protocolo | Autenticación        |
|-----------------|-----------------|-----------|----------------------|
| Flutter         | API Gateway     | HTTPS     | JWT Bearer           |
| API Gateway     | Dream Service   | HTTP      | API Key (header)     |
| API Gateway     | PostgreSQL      | TCP       | Credenciales env var |
| Dream Service   | —               | —         | Stateless            |

---

## Components and Interfaces

### Backend Node.js — Estructura de carpetas

```
backend/
├── src/
│   ├── config/
│   │   ├── database.ts          # Configuración TypeORM / pg pool
│   │   ├── env.ts               # Validación de variables de entorno (fail-fast)
│   │   └── jwt.ts               # Configuración JWT
│   ├── controllers/
│   │   ├── auth.controller.ts
│   │   ├── dream.controller.ts
│   │   ├── stats.controller.ts
│   │   ├── lottery.controller.ts
│   │   └── admin.controller.ts  # Gestión usuarios, stats, logs, tarifas, cuentas, mensajes, OAuth
│   ├── services/
│   │   ├── auth.service.ts
│   │   ├── dream.service.ts     # Proxy hacia Dream Service Python
│   │   ├── stats.service.ts
│   │   ├── lottery.service.ts
│   │   ├── admin.service.ts     # User management, system stats, audit/error logs
│   │   ├── tariff.service.ts
│   │   ├── bankAccount.service.ts
│   │   ├── predefinedMessage.service.ts
│   │   └── oauth.service.ts
│   ├── repositories/
│   │   ├── user.repository.ts
│   │   ├── lottery.repository.ts
│   │   ├── stats.repository.ts
│   │   ├── admin.repository.ts
│   │   ├── tariff.repository.ts
│   │   ├── bankAccount.repository.ts
│   │   ├── predefinedMessage.repository.ts
│   │   ├── oauthProvider.repository.ts
│   │   └── errorLog.repository.ts
│   ├── middlewares/
│   │   ├── auth.middleware.ts        # Validación JWT
│   │   ├── admin.middleware.ts       # Verifica is_admin=true en JWT, retorna 403 si no
│   │   ├── superAdmin.middleware.ts  # Verifica is_super_admin=true en JWT, retorna 403 si no
│   │   ├── rateLimiter.ts            # 100 req/min por IP
│   │   ├── sanitize.ts               # Sanitización XSS/SQLi
│   │   └── errorHandler.ts           # Manejador global de errores
│   ├── dtos/
│   │   ├── register.dto.ts
│   │   ├── login.dto.ts
│   │   ├── dream.dto.ts
│   │   ├── stats.dto.ts
│   │   ├── lottery.dto.ts
│   │   ├── admin.dto.ts
│   │   ├── tariff.dto.ts
│   │   ├── bankAccount.dto.ts
│   │   ├── predefinedMessage.dto.ts
│   │   └── oauthProvider.dto.ts
│   ├── types/
│   │   └── index.ts             # Tipos compartidos (TipoJugada, JwtPayload, etc.)
│   ├── utils/
│   │   ├── ageValidator.ts
│   │   └── combinationOptimizer.ts
│   └── app.ts                   # Express app factory
├── migrations/
│   └── 001_initial_schema.sql
├── .env.example
├── Dockerfile
├── package.json
└── tsconfig.json
```

### AI Service Python — Estructura de carpetas

```
ai-service/
├── app/
│   ├── main.py                  # FastAPI app factory
│   ├── routers/
│   │   └── dreams.py            # POST /interpret
│   ├── services/
│   │   └── dream_analyzer.py    # Lógica NLP / keyword mapping
│   ├── models/
│   │   └── schemas.py           # Pydantic models
│   └── config.py                # Variables de entorno
├── requirements.txt
├── .env.example
└── Dockerfile
```

### Flutter App — Estructura de carpetas

```
flutter_app/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── api/
│   │   │   ├── api_client.dart       # Dio HTTP client
│   │   │   └── interceptors.dart     # JWT injection, error handling
│   │   ├── constants/
│   │   │   └── app_constants.dart
│   │   └── utils/
│   │       └── validators.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   ├── auth_repository.dart
│   │   │   │   └── auth_dto.dart
│   │   │   ├── domain/
│   │   │   │   └── auth_service.dart
│   │   │   └── presentation/
│   │   │       ├── login_screen.dart
│   │   │       └── register_screen.dart
│   │   ├── dreams/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │       └── dream_screen.dart
│   │   ├── lottery/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │       ├── lottery_screen.dart
│   │   │       └── history_screen.dart
│   │   └── stats/
│   │       ├── data/
│   │       ├── domain/
│   │       └── presentation/
│   │           └── stats_screen.dart
│   └── shared/
│       ├── widgets/
│       └── theme/
├── pubspec.yaml
└── .env.example
```

### Contratos de API

#### Admin Middlewares

```
admin.middleware.ts
  - Verifica que el JWT payload contenga is_admin=true O is_super_admin=true
  - Retorna HTTP 403 { error: "Acceso denegado. Se requiere rol de administrador" } si no

superAdmin.middleware.ts
  - Verifica que el JWT payload contenga is_super_admin=true
  - Retorna HTTP 403 { error: "Acceso denegado. Se requiere rol de super administrador" } si no
```

#### Auth

```
POST /users/register
Body: { fullName: string, birthDate: string (ISO 8601), email: string, phone: string, password: string }
201: { id: string, email: string }
403: { error: "Debes ser mayor de 18 años para registrarte" }
409: { error: "El correo ya está registrado" }
422: { error: string, fields: string[] }

POST /users/login
Body: { email: string, password: string }
200: { token: string, expiresIn: 86400 }
401: { error: "Credenciales inválidas" }
```

#### Dreams

```
POST /dreams/interpret                          [JWT required]
Body: { dreamText: string (10–2000 chars) }
200: { numbers: number[], interpretation: string }
400: { error: "La descripción del sueño es demasiado corta" }
503: { error: "El servicio de interpretación no está disponible" }
```

#### Stats

```
POST /stats/upload-results                      [JWT required]
Body: { results: [{ drawDate: string, numbers: number[] }] }
201: { stored: number }
400: { error: string, invalidEntries: object[] }

GET /stats/frequency                            [JWT required]
200: { frequencies: [{ number: number, count: number }] }

GET /stats/trends                               [JWT required]
200: { mostFrequent: number[], leastFrequent: number[] }
```

#### Lottery

```
POST /lottery/request-number                    [JWT required]
Body: { tipo: "Loto" | "Pale" | "Tripleta" | "Número" }
201: { id: string, tipo: string, numbers: number[], timestamp: string }
400: { error: string }

GET /users/history                              [JWT required]
Query: ?page=1&limit=20
200: { data: HistoryRecord[], total: number, page: number, limit: number }
```

#### Dream Service (interno — Python FastAPI)

```
POST /interpret
Headers: { X-API-Key: string }
Body: { text: string }
200: { numbers: number[], keywords: string[] }
400: { detail: string }
```

#### Admin — Gestión de Usuarios (Admin + SuperAdmin)

```
GET /admin/users                                [admin.middleware]
Query: ?page=1&limit=20&search=string
200: { data: UserRecord[], total: number, page: number, limit: number }

GET /admin/users/:id                            [admin.middleware]
200: { id, full_name, email, phone, is_active, is_admin, is_super_admin, created_at }
404: { error: "Usuario no encontrado" }

PATCH /admin/users/:id/status                   [admin.middleware]
Body: { is_active: boolean }
200: { id, is_active }
400: { error: "No puedes desactivar tu propia cuenta" }
404: { error: "Usuario no encontrado" }
```

#### Admin — Estadísticas del Sistema (SuperAdmin only)

```
GET /admin/stats/overview                       [superAdmin.middleware]
200: { totalUsers: number, totalPlays: number, totalDreams: number, activeUsers: number }

GET /admin/stats/activity                       [superAdmin.middleware]
Query: ?from=ISO8601&to=ISO8601
200: { registrations: number, plays: number, dreams: number, period: { from, to } }
400: { error: "El parámetro 'from' debe ser anterior a 'to'" }
```

#### Admin — Logs y Errores (SuperAdmin only)

```
GET /admin/logs/errors                          [superAdmin.middleware]
Query: ?reference_id=UUID
200: { data: ErrorRecord[] }  (máx 100, ordenados por created_at DESC)
404: { error: "Error no encontrado" }  (solo si reference_id provisto y no existe)

GET /admin/logs/audit                           [superAdmin.middleware]
Query: ?user_id=UUID&action=string
200: { data: AuditRecord[] }  (máx 200, ordenados por created_at DESC)
```

#### Admin — Tarifas (SuperAdmin only)

```
GET /admin/tariffs                              [superAdmin.middleware]
200: { id, base_cost_per_play, subscription_cost, discount_percentage, min_plays_for_discount, updated_at }

PUT /admin/tariffs                              [superAdmin.middleware]
Body: { base_cost_per_play, subscription_cost, discount_percentage, min_plays_for_discount }
200: { id, ...updatedFields, updated_at }
422: { error: string, fields: string[] }
```

#### Admin — Cuentas Bancarias (SuperAdmin only + usuarios autenticados)

```
GET /admin/bank-accounts                        [superAdmin.middleware]
200: { data: BankAccount[] }  (todas, incluyendo inactivas)

POST /admin/bank-accounts                       [superAdmin.middleware]
Body: { bank_name, account_number, account_type, account_holder, description }
201: { id, ...fields, is_active, created_at }

PUT /admin/bank-accounts/:id                    [superAdmin.middleware]
Body: { bank_name, account_number, account_type, account_holder, description }
200: { id, ...updatedFields, updated_at }
404: { error: "Cuenta bancaria no encontrada" }

PATCH /admin/bank-accounts/:id/status           [superAdmin.middleware]
Body: { is_active: boolean }
200: { id, is_active }
404: { error: "Cuenta bancaria no encontrada" }

DELETE /admin/bank-accounts/:id                 [superAdmin.middleware]
204: (no body)
404: { error: "Cuenta bancaria no encontrada" }

GET /bank-accounts                              [auth.middleware]
200: { data: BankAccount[] }  (solo is_active=true)
```

#### Admin — Mensajes Predefinidos (Admin lectura / SuperAdmin CRUD)

```
GET /admin/messages                             [admin.middleware]
200: { data: PredefinedMessage[] }

GET /admin/messages/:id                         [admin.middleware]
200: { id, title, body, message_type, role, is_active, created_at, updated_at }
404: { error: "Mensaje no encontrado" }

POST /admin/messages                            [superAdmin.middleware]
Body: { title, body, message_type, role, is_active }
201: { id, ...fields, created_at }

PUT /admin/messages/:id                         [superAdmin.middleware]
Body: { title, body, message_type, role, is_active }
200: { id, ...updatedFields, updated_at }
404: { error: "Mensaje no encontrado" }

DELETE /admin/messages/:id                      [superAdmin.middleware]
204: (no body)
404: { error: "Mensaje no encontrado" }

PATCH /admin/messages/:id/status                [superAdmin.middleware]
Body: { is_active: boolean }
200: { id, is_active }
404: { error: "Mensaje no encontrado" }
```

#### Admin — OAuth Providers (SuperAdmin only)

```
GET /admin/oauth                                [superAdmin.middleware]
200: { data: [{ id, provider_name, client_id, client_secret: "***", redirect_uri, is_active, updated_at }] }

PUT /admin/oauth/:provider                      [superAdmin.middleware]
Body: { client_id, client_secret, redirect_uri, is_active }
200: { id, provider_name, client_id, redirect_uri, is_active, updated_at }
422: { error: string, fields: string[] }

PATCH /admin/oauth/:provider/status             [superAdmin.middleware]
Body: { is_active: boolean }
200: { provider_name, is_active }
```

---

## Data Models

### Esquema PostgreSQL

```sql
-- Tabla: users
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name       VARCHAR(120)  NOT NULL,
    email           VARCHAR(255)  NOT NULL UNIQUE,
    phone           VARCHAR(20)   NOT NULL,
    password_hash   VARCHAR(72)   NOT NULL,
    birth_date      DATE          NOT NULL,
    is_admin        BOOLEAN       NOT NULL DEFAULT false,
    is_super_admin  BOOLEAN       NOT NULL DEFAULT false,
    is_active       BOOLEAN       NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Tabla: historical_results
CREATE TABLE historical_results (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    draw_date   DATE          NOT NULL,
    numbers     SMALLINT[]    NOT NULL,
    uploaded_by UUID          REFERENCES users(id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Tabla: plays (jugadas)
CREATE TABLE plays (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    play_type   VARCHAR(20)   NOT NULL CHECK (play_type IN ('Loto','Pale','Tripleta','Número')),
    numbers     SMALLINT[]    NOT NULL,
    source      VARCHAR(20)   NOT NULL DEFAULT 'generated' CHECK (source IN ('generated','dream')),
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Tabla: dream_interpretations
CREATE TABLE dream_interpretations (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    dream_text        TEXT          NOT NULL,
    suggested_numbers SMALLINT[]    NOT NULL,
    keywords          TEXT[]        NOT NULL DEFAULT '{}',
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Tabla: audit_logs
CREATE TABLE audit_logs (
    id          BIGSERIAL PRIMARY KEY,
    user_id     UUID          REFERENCES users(id) ON DELETE SET NULL,
    action      VARCHAR(80)   NOT NULL,
    ip_address  INET,
    metadata    JSONB         NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Tabla: application_errors
CREATE TABLE application_errors (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_id    UUID          NOT NULL UNIQUE,
    error_code      VARCHAR(80),
    message         TEXT          NOT NULL,
    stack_trace     TEXT,
    context         JSONB         NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Tabla: application_errors_archive (misma estructura, para rotación diaria)
CREATE TABLE application_errors_archive (
    id              UUID PRIMARY KEY,
    reference_id    UUID          NOT NULL UNIQUE,
    error_code      VARCHAR(80),
    message         TEXT          NOT NULL,
    stack_trace     TEXT,
    context         JSONB         NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Tabla: tariff_config
CREATE TABLE tariff_config (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    base_cost_per_play      NUMERIC(10,2) NOT NULL,
    subscription_cost       NUMERIC(10,2) NOT NULL,
    discount_percentage     NUMERIC(5,2)  NOT NULL DEFAULT 0,
    min_plays_for_discount  INTEGER       NOT NULL DEFAULT 1,
    updated_by              UUID          REFERENCES users(id) ON DELETE SET NULL,
    updated_at              TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Tabla: company_bank_accounts
CREATE TABLE company_bank_accounts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_name       VARCHAR(120)  NOT NULL,
    account_number  VARCHAR(50)   NOT NULL,
    account_type    VARCHAR(50)   NOT NULL,
    account_holder  VARCHAR(120)  NOT NULL,
    description     TEXT,
    is_active       BOOLEAN       NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Tabla: predefined_messages
CREATE TABLE predefined_messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           VARCHAR(255)  NOT NULL,
    body            TEXT          NOT NULL,
    message_type    VARCHAR(80)   NOT NULL,
    role            VARCHAR(20)   NOT NULL CHECK (role IN ('sender','receiver','general')),
    is_active       BOOLEAN       NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Tabla: oauth_providers
CREATE TABLE oauth_providers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_name   VARCHAR(20)   NOT NULL CHECK (provider_name IN ('google','facebook')),
    client_id       VARCHAR(255)  NOT NULL DEFAULT '',
    client_secret   VARCHAR(255)  NOT NULL DEFAULT '',
    redirect_uri    VARCHAR(500)  NOT NULL DEFAULT '',
    is_active       BOOLEAN       NOT NULL DEFAULT false,
    updated_by      UUID          REFERENCES users(id) ON DELETE SET NULL,
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Índices de rendimiento
CREATE INDEX idx_plays_user_id_created        ON plays(user_id, created_at DESC);
CREATE INDEX idx_dream_interp_user_id         ON dream_interpretations(user_id, created_at DESC);
CREATE INDEX idx_historical_draw_date         ON historical_results(draw_date DESC);
CREATE INDEX idx_audit_logs_user_id           ON audit_logs(user_id, created_at DESC);
CREATE INDEX idx_audit_logs_action            ON audit_logs(action, created_at DESC);
CREATE INDEX idx_app_errors_reference_id      ON application_errors(reference_id);
CREATE INDEX idx_app_errors_created_at        ON application_errors(created_at DESC);
CREATE INDEX idx_bank_accounts_is_active      ON company_bank_accounts(is_active);
CREATE INDEX idx_predefined_messages_active   ON predefined_messages(is_active);
```

### Tipos TypeScript compartidos

```typescript
// src/types/index.ts
export type TipoJugada = 'Loto' | 'Pale' | 'Tripleta' | 'Número';

export interface JugadaResult {
  id: string;
  tipo: TipoJugada;
  numbers: number[];
  timestamp: string;
}

export interface FrequencyRecord {
  number: number;
  count: number;
}

export interface HistoryRecord {
  id: string;
  type: 'play' | 'dream';
  numbers: number[];
  createdAt: string;
  meta?: Record<string, unknown>;
}

export interface JwtPayload {
  sub: string;          // user id
  email: string;
  is_admin: boolean;
  is_super_admin: boolean;
  iat: number;
  exp: number;
}

export interface AdminUserRecord {
  id: string;
  full_name: string;
  email: string;
  phone: string;
  is_active: boolean;
  is_admin: boolean;
  is_super_admin: boolean;
  created_at: string;
}
```

### Pydantic models (Dream Service)

```python
# app/models/schemas.py
from pydantic import BaseModel, Field
from typing import List

class DreamRequest(BaseModel):
    text: str = Field(..., min_length=10, max_length=2000)

class DreamResponse(BaseModel):
    numbers: List[int] = Field(..., min_items=3, max_items=6)
    keywords: List[str]
```

---

## Docker Compose

```yaml
# docker-compose.yml
version: "3.9"

services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-smartlottery}
      POSTGRES_USER: ${POSTGRES_USER:-sluser}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - pg_data:/var/lib/postgresql/data
      - ./backend/migrations:/docker-entrypoint-initdb.d:ro
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-sluser}"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
      ai-service:
        condition: service_started
    environment:
      NODE_ENV: production
      DATABASE_URL: postgresql://${POSTGRES_USER:-sluser}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB:-smartlottery}
      JWT_SECRET: ${JWT_SECRET}
      AI_SERVICE_URL: http://ai-service:8000
      AI_SERVICE_API_KEY: ${AI_SERVICE_API_KEY}
      PORT: 3000
    ports:
      - "3000:3000"

  ai-service:
    build:
      context: ./ai-service
      dockerfile: Dockerfile
    restart: unless-stopped
    environment:
      API_KEY: ${AI_SERVICE_API_KEY}
      PORT: 8000
    ports:
      - "8000:8000"

volumes:
  pg_data:
```

---

## Combination Optimizer — Algoritmo

El módulo `combinationOptimizer.ts` implementa la lógica de generación de jugadas optimizadas para el tipo **Loto** (6 números).

### Reglas aplicadas

1. **Balance par/impar**: exactamente 3 pares y 3 impares.
2. **Sin secuencias consecutivas**: ningún subconjunto de 3 o más números consecutivos (ej. 4,5,6 → rechazado).
3. **Ponderación por frecuencia**: los números con mayor frecuencia histórica tienen mayor probabilidad de selección (muestreo ponderado).
4. **Fallback uniforme**: si no hay datos históricos, distribución uniforme.

### Pseudocódigo

```
function generateLoto(frequencies: Map<number, number>): number[]
  candidates = [1..36]
  weights = candidates.map(n => frequencies.get(n) ?? 1)

  maxAttempts = 1000
  for attempt in 1..maxAttempts:
    combo = weightedSample(candidates, weights, 6)
    evens = combo.filter(n => n % 2 == 0)
    odds  = combo.filter(n => n % 2 != 0)
    if evens.length != 3: continue
    if hasConsecutiveRun(combo, 3): continue
    return combo.sort()

  throw Error("No se pudo generar combinación válida")

function hasConsecutiveRun(nums: number[], runLength: number): boolean
  sorted = nums.sort()
  streak = 1
  for i in 1..sorted.length-1:
    if sorted[i] == sorted[i-1] + 1:
      streak++
      if streak >= runLength: return true
    else:
      streak = 1
  return false
```


---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Reflexión de propiedades (eliminación de redundancia)

Antes de listar las propiedades finales se revisaron los candidatos del prework:

- Las propiedades 1.3 (rechazo de menores) y 1.2 (cálculo de edad) se consolidan: si el cálculo de edad es correcto, el rechazo de menores es consecuencia directa. Se mantiene una sola propiedad que cubre ambas.
- Las propiedades 2.4 (JWT válido permite acceso) y 2.6 (JWT inválido rechaza acceso) son complementarias y no redundantes — se mantienen ambas.
- Las propiedades 5.3 (6 números únicos en rango) y 5.7 (3 pares / 3 impares) son invariantes distintos del mismo objeto — se mantienen separadas.
- Las propiedades 5.7 y 5.9 son independientes (balance vs. consecutivos) — se mantienen separadas.
- La propiedad 6.3 (orden descendente) y 6.5 (paginación) son independientes — se mantienen separadas.

---

### Property 1: Rechazo de registro para menores de edad

*For any* fecha de nacimiento que resulte en una edad menor a 18 años al momento del registro, el sistema SHALL rechazar la solicitud con HTTP 403.

**Validates: Requirements 1.2, 1.3**

---

### Property 2: Validación de formato de email

*For any* cadena de texto que no cumpla con el formato de correo electrónico válido (RFC 5322 básico), el endpoint de registro SHALL rechazar la solicitud con HTTP 422.

**Validates: Requirements 1.7**

---

### Property 3: Validación de número de teléfono

*For any* cadena de teléfono con longitud fuera del rango [8, 15] o que contenga caracteres no numéricos, el endpoint de registro SHALL rechazar la solicitud con HTTP 422.

**Validates: Requirements 1.8**

---

### Property 4: JWT válido permite acceso a endpoints protegidos

*For any* JWT emitido por el sistema que no haya expirado y tenga firma válida, una petición a cualquier endpoint protegido SHALL recibir una respuesta distinta de HTTP 401.

**Validates: Requirements 2.4**

---

### Property 5: JWT inválido o expirado es rechazado

*For any* cadena presentada como Bearer token que sea malformada, tenga firma inválida o esté expirada, el API Gateway SHALL responder con HTTP 401.

**Validates: Requirements 2.6**

---

### Property 6: Respuesta del Dream Service siempre dentro del rango válido

*For any* texto de sueño válido (entre 10 y 2000 caracteres), el Dream Service SHALL retornar una lista de entre 3 y 6 números, donde cada número está en el rango [1, 36].

**Validates: Requirements 3.4**

---

### Property 7: Rechazo de texto de sueño demasiado corto

*For any* texto con longitud menor a 10 caracteres, el Dream Service SHALL retornar HTTP 400.

**Validates: Requirements 3.3, 3.5**

---

### Property 8: Validación de rango en resultados históricos

*For any* array de resultados históricos que contenga al menos un número fuera del rango [1, 36], el Stats Service SHALL retornar HTTP 400.

**Validates: Requirements 4.3, 4.4**

---

### Property 9: Correctitud del cálculo de frecuencias

*For any* conjunto de resultados históricos almacenados, la frecuencia reportada para cada número SHALL ser igual al número de veces que ese número aparece en todos los arrays de números ganadores.

**Validates: Requirements 4.5**

---

### Property 10: Combinación Loto contiene exactamente 6 números únicos en rango

*For any* solicitud de jugada de tipo Loto, el Lottery Service SHALL generar exactamente 6 números únicos, todos en el rango [1, 36].

**Validates: Requirements 5.3**

---

### Property 11: Balance par/impar en combinación Loto

*For any* combinación Loto generada, el número de valores pares SHALL ser exactamente 3 y el número de valores impares SHALL ser exactamente 3.

**Validates: Requirements 5.7**

---

### Property 12: Ausencia de secuencias consecutivas en combinaciones

*For any* combinación generada (Loto, Pale, Tripleta), la combinación SHALL NOT contener 3 o más números consecutivos en secuencia.

**Validates: Requirements 5.9**

---

### Property 13: Historial retornado en orden descendente por timestamp

*For any* conjunto de registros de historial de un usuario, la respuesta del endpoint GET /users/history SHALL retornar los registros ordenados por `createdAt` de forma descendente.

**Validates: Requirements 6.3**

---

### Property 14: Paginación correcta del historial

*For any* conjunto de N registros de historial, y parámetros válidos `page` y `limit`, el slice retornado SHALL corresponder exactamente a los registros en la posición `[(page-1)*limit, page*limit)` del conjunto ordenado.

**Validates: Requirements 6.5**

---

### Property 15: Sanitización de payloads de entrada

*For any* payload de entrada que contenga patrones de SQL injection o XSS, el API Gateway SHALL sanitizar el contenido de forma que los patrones maliciosos no lleguen a las capas de servicio o base de datos.

**Validates: Requirements 7.4**

---

### Property 16: Acceso denegado a endpoints admin sin rol

*For any* JWT válido que no contenga `is_admin=true` ni `is_super_admin=true`, una petición a cualquier endpoint bajo `/admin` SHALL recibir HTTP 403.

**Validates: Requirements 9.5, 9.6**

---

### Property 17: Acceso denegado a endpoints SuperAdmin con rol Admin

*For any* JWT válido que contenga `is_admin=true` pero `is_super_admin=false`, una petición a cualquier endpoint exclusivo de SuperAdmin SHALL recibir HTTP 403.

**Validates: Requirements 9.7**

---

### Property 18: Validación de tarifas — campos positivos

*For any* solicitud PUT /admin/tariffs donde `base_cost_per_play` ≤ 0 o `subscription_cost` ≤ 0 o `min_plays_for_discount` ≤ 0 o `discount_percentage` fuera de [0,100], el Admin_Service SHALL retornar HTTP 422.

**Validates: Requirements 13.4, 13.5, 13.6, 13.7**

---

### Property 19: client_secret enmascarado en respuesta OAuth

*For any* respuesta del endpoint GET /admin/oauth, el campo `client_secret` de cada proveedor SHALL ser reemplazado por la cadena `"***"` y nunca exponer el valor real.

**Validates: Requirements 16.2**

---

### Property 20: Usuario inactivo no puede iniciar sesión

*For any* usuario cuyo campo `is_active = false` en la base de datos, una solicitud POST /users/login con credenciales válidas SHALL retornar HTTP 403 con el mensaje "Tu cuenta está desactivada. Contacta al administrador".

**Validates: Requirements 10.7**

---

## Error Handling

### Estrategia global

El backend implementa un middleware `errorHandler.ts` que captura todas las excepciones no manejadas y las normaliza al formato:

```json
{
  "error": "Mensaje legible",
  "code": "ERROR_CODE",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

### Tabla de errores por capa

| Capa              | Escenario                              | HTTP | Código interno              |
|-------------------|----------------------------------------|----|------------------------------|
| Auth              | Edad < 18                              | 403  | UNDERAGE                    |
| Auth              | Email duplicado                        | 409  | EMAIL_CONFLICT              |
| Auth              | Credenciales inválidas                 | 401  | INVALID_CREDENTIALS         |
| Auth              | Cuenta desactivada                     | 403  | ACCOUNT_DISABLED            |
| Auth              | Proveedor OAuth deshabilitado          | 400  | OAUTH_PROVIDER_DISABLED     |
| Auth              | Validación de campos                   | 422  | VALIDATION_ERROR            |
| JWT Middleware    | Token ausente                          | 401  | TOKEN_MISSING               |
| JWT Middleware    | Token expirado/malformado              | 401  | TOKEN_INVALID               |
| Admin Middleware  | No es admin ni superadmin              | 403  | FORBIDDEN_ADMIN_REQUIRED    |
| SuperAdmin MW     | No es superadmin                       | 403  | FORBIDDEN_SUPERADMIN_REQUIRED |
| Admin Service     | Recurso no encontrado                  | 404  | NOT_FOUND                   |
| Admin Service     | Auto-desactivación de cuenta           | 400  | SELF_DEACTIVATION_FORBIDDEN |
| Admin Service     | Validación de tarifas/OAuth            | 422  | VALIDATION_ERROR            |
| Dream Service     | Texto muy corto                        | 400  | DREAM_TOO_SHORT             |
| Dream Service     | Servicio no disponible                 | 503  | DREAM_SERVICE_DOWN          |
| Stats Service     | Número fuera de rango                  | 400  | INVALID_NUMBER_RANGE        |
| Lottery Service   | No se pudo generar combinación         | 500  | GENERATION_FAILED           |
| Rate Limiter      | Límite excedido                        | 429  | RATE_LIMIT_EXCEEDED         |
| Global            | Error interno no manejado              | 500  | INTERNAL_ERROR              |

### Fail-fast en startup

El módulo `config/env.ts` valida todas las variables de entorno requeridas al iniciar. Si alguna falta, el proceso termina con `process.exit(1)` y un mensaje descriptivo. Variables requeridas:

- `DATABASE_URL`
- `JWT_SECRET`
- `AI_SERVICE_URL`
- `AI_SERVICE_API_KEY`

### Circuit breaker para Dream Service

El `dream.service.ts` implementa un timeout de 5 segundos y retorna HTTP 503 si el servicio Python no responde. No se implementa retry automático para evitar cascada de fallos.

---

## Testing Strategy

### Enfoque dual: Unit + Property-Based

La estrategia combina tests de ejemplo para flujos concretos y tests basados en propiedades para invariantes universales.

**Librería PBT seleccionada**: `fast-check` (TypeScript/Node.js) — madura, bien mantenida, integración nativa con Jest/Vitest.

**Librería PBT para Python**: `hypothesis` — estándar de facto para Python.

### Configuración de tests de propiedades

- Mínimo **100 iteraciones** por propiedad (`numRuns: 100` en fast-check).
- Cada test referencia su propiedad del documento de diseño con el tag:
  `// Feature: smart-lottery-app, Property N: <texto>`

### Tests unitarios (Jest + Vitest)

| Módulo                        | Tipo          | Cobertura objetivo |
|-------------------------------|---------------|--------------------|
| `ageValidator.ts`             | Unit + PBT    | 100%               |
| `combinationOptimizer.ts`     | Unit + PBT    | 100%               |
| `auth.service.ts`             | Unit          | 90%                |
| `stats.service.ts`            | Unit + PBT    | 90%                |
| `dream.service.ts`            | Unit (mock)   | 85%                |
| `admin.service.ts`            | Unit          | 90%                |
| `tariff.service.ts`           | Unit          | 90%                |
| `bankAccount.service.ts`      | Unit          | 85%                |
| `predefinedMessage.service.ts`| Unit          | 85%                |
| `oauth.service.ts`            | Unit          | 85%                |
| JWT middleware                 | Unit + PBT    | 95%                |
| admin.middleware               | Unit          | 95%                |
| superAdmin.middleware          | Unit          | 95%                |
| Sanitize middleware            | Unit + PBT    | 95%                |

### Tests de integración

| Escenario                                    | Herramienta        |
|----------------------------------------------|--------------------|
| Registro → Login → JWT → endpoint protegido  | Supertest + TestDB |
| Upload resultados → GET frequency            | Supertest + TestDB |
| Rate limiting (101 requests)                 | Supertest          |
| Dream Service proxy (mock Python service)    | Supertest + nock   |

### Tests de humo (Smoke)

| Escenario                                    | Herramienta        |
|----------------------------------------------|--------------------|
| `docker compose up` — todos los servicios    | Docker + shell     |
| Schema PostgreSQL inicializado               | psql + assertions  |
| Variables de entorno faltantes → exit(1)     | Node.js subprocess |

### Tests de propiedades — mapeo

| Propiedad | Test                                                         | Librería   |
|-----------|--------------------------------------------------------------|------------|
| P1        | `fc.date()` → edad < 18 → assert 403                        | fast-check |
| P2        | `fc.string()` filtrado no-email → assert 422                 | fast-check |
| P3        | `fc.string()` longitud fuera [8,15] → assert 422             | fast-check |
| P4        | `fc.uuid()` como userId → JWT válido → assert !401           | fast-check |
| P5        | `fc.string()` como token → assert 401                        | fast-check |
| P6        | `fc.string({minLength:10,maxLength:2000})` → [3-6] nums      | hypothesis |
| P7        | `fc.string({maxLength:9})` → assert 400                      | hypothesis |
| P8        | `fc.array(fc.integer())` con outliers → assert 400           | fast-check |
| P9        | `fc.array(resultados)` → frecuencia == conteo manual         | fast-check |
| P10       | Loto × 100 → length==6, unique, in [1,36]                    | fast-check |
| P11       | Loto × 100 → evens==3, odds==3                               | fast-check |
| P12       | Loto/Pale/Tripleta × 100 → no 3 consecutivos                 | fast-check |
| P13       | `fc.array(records)` → sorted desc by createdAt               | fast-check |
| P14       | `fc.integer({min:1})` page, limit → slice correcto           | fast-check |
| P15       | `fc.string()` con payloads XSS/SQLi → sanitizado             | fast-check |
| P16       | JWT sin is_admin/is_super_admin → GET /admin/* → assert 403  | fast-check |
| P17       | JWT con is_admin=true, is_super_admin=false → SuperAdmin EP → assert 403 | fast-check |
| P18       | Campos tarifa inválidos → PUT /admin/tariffs → assert 422    | fast-check |
| P19       | GET /admin/oauth → client_secret == "***" siempre            | fast-check |
| P20       | Usuario is_active=false + credenciales válidas → assert 403  | fast-check |
