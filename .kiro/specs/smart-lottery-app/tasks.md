# Implementation Plan: Smart Lottery App

## Overview

Plan de implementación incremental para Smart Lottery App. Cada tarea es atómica e implementable de forma independiente. El orden sigue la cadena de dependencias: infraestructura → backend → AI service → Flutter → tests de propiedades → Docker final.

Stack: Node.js + Express + TypeScript (backend), Python + FastAPI (AI), Flutter/Dart (mobile), PostgreSQL, Docker Compose.

## Tasks

- [x] 1. Infraestructura base — Docker, DB y configuración
  - [x] 1.1 Crear estructura de carpetas del monorepo
    - Crear directorios: `backend/`, `ai-service/`, `flutter_app/`
    - Crear `.gitignore` raíz con exclusiones para node_modules, __pycache__, .env, build/
    - _Requirements: 8.1, 8.2_

  - [x] 1.2 Crear migración SQL inicial del esquema PostgreSQL
    - Crear `backend/migrations/001_initial_schema.sql` con tablas: `users`, `historical_results`, `plays`, `dream_interpretations`, `audit_logs`
    - Incluir todos los índices de rendimiento definidos en el diseño
    - _Requirements: 8.3_

  - [x] 1.3 Crear `docker-compose.yml` raíz con servicios postgres, backend y ai-service
    - Configurar healthcheck para postgres, depends_on con condición `service_healthy` para backend
    - Montar `./backend/migrations` en `/docker-entrypoint-initdb.d:ro`
    - Definir volumen `pg_data` persistente
    - _Requirements: 8.2, 8.3_

  - [x] 1.4 Crear archivos `.env.example` para backend y ai-service
    - `backend/.env.example`: DATABASE_URL, JWT_SECRET, AI_SERVICE_URL, AI_SERVICE_API_KEY, PORT, NODE_ENV
    - `ai-service/.env.example`: API_KEY, PORT
    - _Requirements: 8.4_

- [x] 2. Backend — Scaffolding y configuración base
  - [x] 2.1 Inicializar proyecto Node.js/TypeScript con dependencias
    - Crear `backend/package.json` con dependencias: express, pg, bcrypt, jsonwebtoken, express-rate-limit, express-validator, helmet, cors, axios
    - Crear `backend/tsconfig.json` con strict mode habilitado
    - Crear `backend/Dockerfile` multi-stage (build + production)
    - _Requirements: 8.1_

  - [x] 2.2 Implementar módulo de configuración y validación de entorno
    - Crear `backend/src/config/env.ts`: validar variables requeridas al startup, `process.exit(1)` si falta alguna
    - Crear `backend/src/config/database.ts`: pool de conexiones pg con DATABASE_URL
    - Crear `backend/src/config/jwt.ts`: configuración de firma y verificación JWT
    - _Requirements: 7.6, 8.5_

  - [x] 2.3 Implementar tipos compartidos y DTOs base
    - Crear `backend/src/types/index.ts`: `TipoJugada`, `JugadaResult`, `FrequencyRecord`, `HistoryRecord`
    - Crear DTOs: `register.dto.ts`, `login.dto.ts`, `dream.dto.ts`, `stats.dto.ts`, `lottery.dto.ts`
    - _Requirements: 1.1, 2.1, 3.1, 4.1, 5.1_

  - [x] 2.4 Implementar middlewares globales
    - Crear `backend/src/middlewares/errorHandler.ts`: normalizar errores al formato `{ error, code, timestamp }`
    - Crear `backend/src/middlewares/rateLimiter.ts`: 100 req/min por IP
    - Crear `backend/src/middlewares/sanitize.ts`: sanitización XSS/SQLi en body y query params
    - Crear `backend/src/middlewares/auth.middleware.ts`: validación JWT Bearer, retornar 401 si ausente/inválido/expirado
    - _Requirements: 7.3, 7.4, 2.4, 2.5, 2.6_

  - [x] 2.5 Crear Express app factory y punto de entrada
    - Crear `backend/src/app.ts`: registrar middlewares (helmet, cors, json, rateLimiter, sanitize), montar routers
    - Crear `backend/src/server.ts`: inicializar config/env, conectar DB, arrancar servidor
    - _Requirements: 7.1, 7.3_

- [x] 3. Backend — Módulo Auth
  - [x] 3.1 Implementar utilidad de validación de edad
    - Crear `backend/src/utils/ageValidator.ts`: función `calculateAge(birthDate: Date): number` y `isAdult(birthDate: Date): boolean`
    - _Requirements: 1.2, 1.3_

  - [ ]* 3.2 Escribir property tests para ageValidator (P1)
    - **Property 1: Rechazo de registro para menores de edad**
    - Usar `fast-check`: `fc.date()` generando fechas que resulten en edad < 18 → assert `isAdult()` retorna false
    - Usar `fc.date()` generando fechas con edad ≥ 18 → assert `isAdult()` retorna true
    - Tag: `// Feature: smart-lottery-app, Property 1`
    - **Validates: Requirements 1.2, 1.3**

  - [x] 3.3 Implementar User Repository
    - Crear `backend/src/repositories/user.repository.ts`: métodos `create()`, `findByEmail()`, `findById()`
    - Usar pg pool, queries parametrizadas (sin ORM)
    - _Requirements: 1.4, 1.5, 1.6_

  - [x] 3.4 Implementar Auth Service
    - Crear `backend/src/services/auth.service.ts`: `register()` con validación de edad, hash bcrypt (cost 10), detección de email duplicado; `login()` con comparación bcrypt y emisión JWT 24h
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.6, 2.2, 2.3, 7.2, 7.5_

  - [x] 3.5 Implementar Auth Controller y rutas
    - Crear `backend/src/controllers/auth.controller.ts`: handlers para POST /users/register y POST /users/login
    - Aplicar validación de DTOs (express-validator) para email (P2) y teléfono (P3)
    - Montar rutas en `app.ts`
    - _Requirements: 1.1, 1.7, 1.8, 2.1_

  - [ ]* 3.6 Escribir property tests para validación de email y teléfono (P2, P3)
    - **Property 2: Validación de formato de email**
    - **Property 3: Validación de número de teléfono**
    - Usar `fast-check`: `fc.string()` con strings no-email → assert 422; strings con longitud fuera [8,15] → assert 422
    - Tag: `// Feature: smart-lottery-app, Property 2` y `Property 3`
    - **Validates: Requirements 1.7, 1.8**

  - [ ]* 3.7 Escribir property tests para JWT middleware (P4, P5)
    - **Property 4: JWT válido permite acceso a endpoints protegidos**
    - **Property 5: JWT inválido o expirado es rechazado**
    - Usar `fast-check`: JWT válido generado con `fc.uuid()` como userId → assert respuesta != 401; strings arbitrarios como Bearer token → assert 401
    - Tag: `// Feature: smart-lottery-app, Property 4` y `Property 5`
    - **Validates: Requirements 2.4, 2.6**

- [x] 4. Checkpoint — Auth funcional
  - Verificar que POST /users/register y POST /users/login responden correctamente con DB activa.
  - Verificar que endpoints protegidos retornan 401 sin token válido.
  - Asegurar que todos los tests pasen. Consultar al usuario si surgen dudas.

- [x] 5. Backend — Módulo Stats
  - [x] 5.1 Implementar Stats Repository
    - Crear `backend/src/repositories/stats.repository.ts`: métodos `insertResults()`, `getFrequencies()`, `getTrends()`
    - Query de frecuencias: `UNNEST(numbers)` + `COUNT` agrupado, ordenado DESC
    - _Requirements: 4.5, 4.6, 4.7_

  - [x] 5.2 Implementar Stats Service
    - Crear `backend/src/services/stats.service.ts`: `uploadResults()` con validación de rango [1,36]; `getFrequencies()`; `getTrends()` retornando top 5 y bottom 5
    - _Requirements: 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8_

  - [x] 5.3 Implementar Stats Controller y rutas
    - Crear `backend/src/controllers/stats.controller.ts`: handlers para POST /stats/upload-results, GET /stats/frequency, GET /stats/trends
    - Proteger con `auth.middleware`
    - _Requirements: 4.1, 4.6, 4.7_

  - [ ]* 5.4 Escribir property tests para Stats Service (P8, P9)
    - **Property 8: Validación de rango en resultados históricos**
    - **Property 9: Correctitud del cálculo de frecuencias**
    - Usar `fast-check`: arrays con números fuera de [1,36] → assert 400; arrays de resultados válidos → frecuencia reportada == conteo manual
    - Tag: `// Feature: smart-lottery-app, Property 8` y `Property 9`
    - **Validates: Requirements 4.3, 4.4, 4.5**

- [ ] 6. Backend — Módulo Lottery
  - [x] 6.1 Implementar combinationOptimizer
    - Crear `backend/src/utils/combinationOptimizer.ts`: función `generateLoto(frequencies)` con muestreo ponderado, balance 3 pares/3 impares, rechazo de 3+ consecutivos, fallback uniforme; funciones auxiliares para Pale (2), Tripleta (3), Número (1)
    - _Requirements: 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 5.11_

  - [ ]* 6.2 Escribir property tests para combinationOptimizer (P10, P11, P12)
    - **Property 10: Combinación Loto contiene exactamente 6 números únicos en rango**
    - **Property 11: Balance par/impar en combinación Loto**
    - **Property 12: Ausencia de secuencias consecutivas en combinaciones**
    - Usar `fast-check`: ejecutar generador × 100 → assert length==6, unique, in [1,36]; evens==3, odds==3; no 3 consecutivos
    - Tag: `// Feature: smart-lottery-app, Property 10`, `Property 11`, `Property 12`
    - **Validates: Requirements 5.3, 5.7, 5.9**

  - [x] 6.3 Implementar Lottery Repository
    - Crear `backend/src/repositories/lottery.repository.ts`: métodos `savePlay()`, `getHistory(userId, page, limit)` ordenado por `created_at DESC`
    - _Requirements: 5.10, 6.2, 6.3, 6.5_

  - [x] 6.4 Implementar Lottery Service
    - Crear `backend/src/services/lottery.service.ts`: `generate(tipo, userId)` que obtiene frecuencias de StatsService, delega a combinationOptimizer, persiste jugada; `getHistory(userId, page, limit)`
    - _Requirements: 5.2, 5.8, 5.10, 5.11, 6.2, 6.3, 6.4_

  - [x] 6.5 Implementar Lottery Controller y rutas
    - Crear `backend/src/controllers/lottery.controller.ts`: handlers para POST /lottery/request-number y GET /users/history con paginación (page, limit, defaults 1/20)
    - Proteger con `auth.middleware`
    - _Requirements: 5.1, 6.1, 6.5_

  - [ ]* 6.6 Escribir property tests para historial paginado (P13, P14)
    - **Property 13: Historial retornado en orden descendente por timestamp**
    - **Property 14: Paginación correcta del historial**
    - Usar `fast-check`: arrays de registros → assert orden DESC por createdAt; `fc.integer({min:1})` para page/limit → assert slice correcto
    - Tag: `// Feature: smart-lottery-app, Property 13` y `Property 14`
    - **Validates: Requirements 6.3, 6.5**

- [ ] 7. Checkpoint — Backend completo
  - Verificar que todos los endpoints del backend responden correctamente.
  - Ejecutar suite de tests unitarios y de propiedades del backend.
  - Asegurar que todos los tests pasen. Consultar al usuario si surgen dudas.

- [ ] 8. Backend — Módulo Dreams (proxy)
  - [x] 8.1 Implementar Dream Service (proxy)
    - Crear `backend/src/services/dream.service.ts`: `interpret(text, userId)` que llama a `AI_SERVICE_URL/interpret` con header `X-API-Key`, timeout 5s, retorna 503 si no responde; persiste interpretación en DB
    - _Requirements: 3.2, 3.6, 3.7_

  - [x] 8.2 Implementar Dream Controller y rutas
    - Crear `backend/src/controllers/dream.controller.ts`: handler para POST /dreams/interpret
    - Proteger con `auth.middleware`; retornar 400 si texto < 10 chars antes de llamar al servicio Python
    - _Requirements: 3.1, 3.3, 3.5, 3.6_

- [ ] 9. AI Service — Python FastAPI
  - [x] 9.1 Inicializar proyecto FastAPI con dependencias
    - Crear `ai-service/requirements.txt`: fastapi, uvicorn, pydantic, python-dotenv, hypothesis (dev)
    - Crear `ai-service/Dockerfile`: imagen python:3.11-slim, instalar deps, CMD uvicorn
    - _Requirements: 8.1_

  - [x] 9.2 Implementar configuración y modelos Pydantic
    - Crear `ai-service/app/config.py`: cargar API_KEY y PORT desde env, fail-fast si falta API_KEY
    - Crear `ai-service/app/models/schemas.py`: `DreamRequest` (text, min 10, max 2000), `DreamResponse` (numbers list[int] 3-6, keywords list[str])
    - _Requirements: 3.3, 3.4, 8.5_

  - [x] 9.3 Implementar Dream Analyzer Service
    - Crear `ai-service/app/services/dream_analyzer.py`: función `analyze(text: str) -> DreamResponse` con mapeo keyword → números, retornar 3-6 números únicos en [1,36]
    - _Requirements: 3.4_

  - [x] 9.4 Implementar router /interpret y app factory
    - Crear `ai-service/app/routers/dreams.py`: POST /interpret con validación de API Key en header X-API-Key (401 si inválida), delegar a dream_analyzer
    - Crear `ai-service/app/main.py`: FastAPI app factory, incluir router, middleware de manejo de errores
    - _Requirements: 3.3, 3.4, 3.5_

  - [ ]* 9.5 Escribir property tests para Dream Service con Hypothesis (P6, P7)
    - **Property 6: Respuesta del Dream Service siempre dentro del rango válido**
    - **Property 7: Rechazo de texto de sueño demasiado corto**
    - Usar `hypothesis`: `st.text(min_size=10, max_size=2000)` → assert len(numbers) in [3,6] y all n in [1,36]; `st.text(max_size=9)` → assert HTTP 400
    - Tag: `# Feature: smart-lottery-app, Property 6` y `Property 7`
    - **Validates: Requirements 3.3, 3.4, 3.5**

- [ ] 10. Checkpoint — AI Service funcional
  - Verificar que POST /interpret responde con números válidos para texto de sueño de prueba.
  - Verificar rechazo con 401 para API Key inválida y 400 para texto corto.
  - Asegurar que todos los tests pasen. Consultar al usuario si surgen dudas.

- [x] 11. Flutter — Core (API client, interceptors, navegación)
  - [x] 11.1 Inicializar proyecto Flutter y dependencias
    - Crear `flutter_app/pubspec.yaml` con dependencias: dio, flutter_secure_storage, go_router, provider (o riverpod), flutter_dotenv
    - Crear estructura de carpetas: `lib/core/`, `lib/features/`, `lib/shared/`
    - _Requirements: 8.1_

  - [x] 11.2 Implementar API client y interceptors
    - Crear `flutter_app/lib/core/api/api_client.dart`: instancia Dio con baseUrl desde env, timeout 10s
    - Crear `flutter_app/lib/core/api/interceptors.dart`: inyección de JWT Bearer en headers, manejo de 401 (limpiar token + redirect login), logging de errores
    - _Requirements: 2.4, 2.5, 2.6_

  - [x] 11.3 Implementar constantes, validadores y tema
    - Crear `flutter_app/lib/core/constants/app_constants.dart`: rutas de API, timeouts, límites de paginación
    - Crear `flutter_app/lib/core/utils/validators.dart`: validadores de email, teléfono, texto de sueño
    - Crear `flutter_app/lib/shared/theme/`: tema base de la app
    - _Requirements: 1.7, 1.8, 3.3_

  - [x] 11.4 Implementar navegación con go_router
    - Crear `flutter_app/lib/main.dart`: configurar GoRouter con rutas: `/login`, `/register`, `/dreams`, `/lottery`, `/history`, `/stats`
    - Implementar guard de autenticación: redirigir a `/login` si no hay token
    - _Requirements: 2.4, 2.5_

- [ ] 12. Flutter — Feature Auth
  - [x] 12.1 Implementar Auth Repository y Service
    - Crear `flutter_app/lib/features/auth/data/auth_repository.dart`: llamadas a POST /users/register y POST /users/login via api_client
    - Crear `flutter_app/lib/features/auth/data/auth_dto.dart`: modelos RegisterRequest, LoginRequest, LoginResponse
    - Crear `flutter_app/lib/features/auth/domain/auth_service.dart`: lógica de negocio, persistir JWT en flutter_secure_storage
    - _Requirements: 1.1, 2.1, 2.2_

  - [x] 12.2 Implementar pantallas Login y Register
    - Crear `flutter_app/lib/features/auth/presentation/login_screen.dart`: formulario email/password, manejo de error 401
    - Crear `flutter_app/lib/features/auth/presentation/register_screen.dart`: formulario con todos los campos, validación de edad en cliente, manejo de errores 403/409/422
    - _Requirements: 1.1, 1.3, 2.1, 2.3_

- [ ] 13. Flutter — Feature Dreams
  - [x] 13.1 Implementar Dreams Repository y Service
    - Crear `flutter_app/lib/features/dreams/data/`: repository con POST /dreams/interpret, DTO de request/response
    - Crear `flutter_app/lib/features/dreams/domain/`: service con validación de longitud de texto (10-2000 chars)
    - _Requirements: 3.1, 3.3, 3.5, 3.6_

  - [x] 13.2 Implementar pantalla Dream
    - Crear `flutter_app/lib/features/dreams/presentation/dream_screen.dart`: campo de texto multiline, botón interpretar, mostrar números sugeridos e interpretación, manejo de error 503
    - _Requirements: 3.1, 3.4, 3.6_

- [ ] 14. Flutter — Feature Lottery
  - [x] 14.1 Implementar Lottery Repository y Service
    - Crear `flutter_app/lib/features/lottery/data/`: repository con POST /lottery/request-number y GET /users/history, DTOs
    - Crear `flutter_app/lib/features/lottery/domain/`: service con lógica de paginación del historial
    - _Requirements: 5.1, 6.1, 6.5_

  - [x] 14.2 Implementar pantallas Lottery e History
    - Crear `flutter_app/lib/features/lottery/presentation/lottery_screen.dart`: selector de TipoJugada, botón generar, mostrar números generados
    - Crear `flutter_app/lib/features/lottery/presentation/history_screen.dart`: lista paginada de jugadas e interpretaciones, scroll infinito o paginación manual
    - _Requirements: 5.2, 6.1, 6.3, 6.4, 6.5_

- [ ] 15. Flutter — Feature Stats
  - [x] 15.1 Implementar Stats Repository y Service
    - Crear `flutter_app/lib/features/stats/data/`: repository con POST /stats/upload-results, GET /stats/frequency, GET /stats/trends, DTOs
    - Crear `flutter_app/lib/features/stats/domain/`: service con transformación de datos para visualización
    - _Requirements: 4.1, 4.6, 4.7_

  - [x] 15.2 Implementar pantalla Stats
    - Crear `flutter_app/lib/features/stats/presentation/stats_screen.dart`: visualización de frecuencias (lista o gráfico de barras simple), sección de tendencias (top 5 / bottom 5), botón de upload de resultados
    - _Requirements: 4.6, 4.7_

- [ ] 16. Checkpoint — Flutter integrado con backend
  - Verificar flujo completo: registro → login → generación de jugada → historial.
  - Verificar flujo de sueños: texto → interpretación → números mostrados.
  - Asegurar que todos los tests pasen. Consultar al usuario si surgen dudas.

- [ ] 17. Tests de propiedades — Backend (fast-check)
  - [ ] 17.1 Configurar entorno de testing en backend
    - Instalar dependencias de test: vitest (o jest), supertest, fast-check, nock
    - Crear `backend/src/__tests__/` con configuración de test DB (variables de entorno de test)
    - _Requirements: 8.1_

  - [ ]* 17.2 Implementar property tests P1–P5 (Auth)
    - Consolidar y ejecutar tests de propiedades P1 (edad), P2 (email), P3 (teléfono), P4 (JWT válido), P5 (JWT inválido)
    - Mínimo 100 iteraciones por propiedad (`numRuns: 100`)
    - **Validates: Requirements 1.2, 1.3, 1.7, 1.8, 2.4, 2.6**

  - [ ]* 17.3 Implementar property tests P8–P9 (Stats)
    - Consolidar y ejecutar tests de propiedades P8 (rango histórico), P9 (frecuencias)
    - **Validates: Requirements 4.3, 4.4, 4.5**

  - [ ]* 17.4 Implementar property tests P10–P12 (Lottery optimizer)
    - Consolidar y ejecutar tests de propiedades P10 (6 únicos en rango), P11 (balance par/impar), P12 (sin consecutivos)
    - **Validates: Requirements 5.3, 5.7, 5.9**

  - [ ]* 17.5 Implementar property tests P13–P15 (Historial y sanitización)
    - Consolidar y ejecutar tests de propiedades P13 (orden DESC), P14 (paginación), P15 (sanitización XSS/SQLi)
    - **Validates: Requirements 6.3, 6.5, 7.4**

- [ ] 18. Tests de propiedades — AI Service (hypothesis)
  - [ ]* 18.1 Implementar property tests P6–P7 con Hypothesis
    - Configurar pytest + hypothesis en `ai-service/`
    - Consolidar y ejecutar tests P6 (rango de respuesta válido) y P7 (rechazo texto corto)
    - Mínimo 100 ejemplos por propiedad (`@settings(max_examples=100)`)
    - **Validates: Requirements 3.3, 3.4, 3.5**

- [ ] 19. Docker Compose final y README
  - [ ] 19.1 Validar y completar `docker-compose.yml`
    - Verificar que todos los servicios arrancan con `docker compose up`
    - Confirmar que la migración SQL se ejecuta automáticamente al iniciar postgres
    - Confirmar healthchecks y depends_on correctos
    - _Requirements: 8.2, 8.3_

  - [ ] 19.2 Crear `README.md` raíz
    - Documentar requisitos de software con versiones mínimas: Flutter ≥ 3.10, Node.js ≥ 18.0, Python ≥ 3.10, PostgreSQL ≥ 14.0, Docker ≥ 24.0
    - Incluir instrucciones de setup: clonar repo, copiar `.env.example` → `.env`, `docker compose up`
    - Incluir comandos para ejecutar tests de cada servicio
    - _Requirements: 8.1, 8.2, 8.4_

- [ ] 20. Checkpoint final — Sistema completo
  - Verificar que `docker compose up` levanta todos los servicios sin errores.
  - Verificar que el esquema PostgreSQL se inicializa correctamente.
  - Ejecutar suite completa de tests (backend + AI service).
  - Asegurar que todos los tests pasen. Consultar al usuario si surgen dudas.

- [x] 21. Migración SQL — Nuevas tablas y columnas admin
  - [x] 21.1 Agregar columnas admin a tabla users
    - Agregar `is_admin BOOLEAN NOT NULL DEFAULT false`, `is_super_admin BOOLEAN NOT NULL DEFAULT false`, `is_active BOOLEAN NOT NULL DEFAULT true` a la tabla `users` en `001_initial_schema.sql`
    - _Requirements: 9.1, 9.2_

  - [x] 21.2 Crear tablas de administración
    - Crear tablas: `application_errors`, `application_errors_archive`, `tariff_config`, `company_bank_accounts`, `predefined_messages`, `oauth_providers` con todas las columnas y constraints definidos en el diseño
    - Agregar índices: `idx_app_errors_reference_id`, `idx_app_errors_created_at`, `idx_bank_accounts_is_active`, `idx_predefined_messages_active`, `idx_audit_logs_action`
    - _Requirements: 12.1, 13.1, 14.1, 15.1, 16.1_

- [x] 22. Backend — Middlewares admin y superAdmin
  - [x] 22.1 Actualizar Auth Service para incluir roles en JWT
    - Modificar `auth.service.ts`: incluir `is_admin` e `is_super_admin` en el payload del JWT al emitirlo en `login()`
    - Modificar `auth.service.ts`: verificar `is_active=true` antes de emitir token, retornar HTTP 403 con mensaje "Tu cuenta está desactivada. Contacta al administrador" si no
    - Actualizar `JwtPayload` en `src/types/index.ts` con los campos `is_admin`, `is_super_admin`
    - _Requirements: 9.4, 10.7_

  - [x] 22.2 Implementar admin.middleware.ts
    - Crear `backend/src/middlewares/admin.middleware.ts`: verificar que el JWT payload contenga `is_admin=true` O `is_super_admin=true`, retornar HTTP 403 si no
    - _Requirements: 9.5, 9.6_

  - [x] 22.3 Implementar superAdmin.middleware.ts
    - Crear `backend/src/middlewares/superAdmin.middleware.ts`: verificar que el JWT payload contenga `is_super_admin=true`, retornar HTTP 403 si no
    - _Requirements: 9.7_

  - [ ]* 22.4 Escribir property tests para middlewares admin (P16, P17)
    - **Property 16: Acceso denegado a endpoints admin sin rol**
    - **Property 17: Acceso denegado a endpoints SuperAdmin con rol Admin**
    - Usar `fast-check`: JWT sin roles admin → GET /admin/* → assert 403; JWT con is_admin=true, is_super_admin=false → endpoint SuperAdmin → assert 403
    - Tag: `// Feature: smart-lottery-app, Property 16` y `Property 17`
    - **Validates: Requirements 9.5, 9.6, 9.7**

- [x] 23. Backend — Módulo gestión de usuarios admin
  - [x] 23.1 Implementar Admin Repository (usuarios)
    - Crear `backend/src/repositories/admin.repository.ts`: métodos `listUsers(page, limit, search)`, `findUserById(id)`, `setUserStatus(id, is_active)`
    - Queries parametrizadas con filtro opcional por `full_name` o `email` (ILIKE)
    - _Requirements: 10.1, 10.2, 10.3, 10.6_

  - [x] 23.2 Implementar Admin Service (user management)
    - Crear `backend/src/services/admin.service.ts`: métodos `listUsers()`, `getUserById()`, `setUserStatus()` con validación de auto-desactivación (HTTP 400 si el admin intenta desactivarse a sí mismo)
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.8_

  - [x] 23.3 Implementar Admin Controller — rutas de usuarios
    - Crear `backend/src/controllers/admin.controller.ts`: handlers para `GET /admin/users`, `GET /admin/users/:id`, `PATCH /admin/users/:id/status`
    - Proteger con `auth.middleware` + `admin.middleware`
    - Crear DTOs en `admin.dto.ts`: `UpdateUserStatusDto`
    - _Requirements: 10.1, 10.2, 10.3, 10.5, 10.8_

  - [ ]* 23.4 Escribir property test para usuario inactivo (P20)
    - **Property 20: Usuario inactivo no puede iniciar sesión**
    - Usar `fast-check`: usuario con `is_active=false` + credenciales válidas → assert HTTP 403
    - Tag: `// Feature: smart-lottery-app, Property 20`
    - **Validates: Requirements 10.7**

- [x] 24. Backend — Módulo estadísticas, logs y tarifas (SuperAdmin)
  - [x] 24.1 Implementar Admin Service — estadísticas del sistema
    - Extender `admin.service.ts`: métodos `getOverviewStats()` (total users, plays, dreams, active users) y `getActivityStats(from, to)` con validación de rango de fechas
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6_

  - [x] 24.2 Implementar Error Log Repository y rotación
    - Crear `backend/src/repositories/errorLog.repository.ts`: métodos `insert(error)`, `findRecent(limit)`, `findByReferenceId(uuid)`, `archiveOlderThan(days)`
    - Implementar lógica de rotación diaria: mover registros > 30 días a `application_errors_archive` y eliminarlos de la tabla principal
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6_

  - [x] 24.3 Actualizar errorHandler para persistir errores
    - Modificar `backend/src/middlewares/errorHandler.ts`: al capturar un error no manejado, insertar registro en `application_errors` con `reference_id` UUID único e incluir ese UUID en la respuesta HTTP
    - _Requirements: 12.2_

  - [x] 24.4 Implementar Tariff Repository y Service
    - Crear `backend/src/repositories/tariff.repository.ts`: métodos `getCurrent()`, `upsert(data, updatedBy)`
    - Crear `backend/src/services/tariff.service.ts`: `getTariff()`, `updateTariff(data, adminId)` con validaciones de campos y registro en `audit_logs` con acción `TARIFF_UPDATED`
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7, 13.8_

  - [x] 24.5 Implementar Admin Controller — rutas stats, logs y tarifas
    - Extender `admin.controller.ts`: handlers para `GET /admin/stats/overview`, `GET /admin/stats/activity`, `GET /admin/logs/errors`, `GET /admin/logs/audit`, `GET /admin/tariffs`, `PUT /admin/tariffs`
    - Proteger stats/logs/tariffs con `auth.middleware` + `superAdmin.middleware`
    - Crear DTOs: `UpdateTariffDto`, `ActivityQueryDto`
    - _Requirements: 11.1, 11.3, 12.3, 12.4, 12.7, 13.2, 13.3_

  - [ ]* 24.6 Escribir property test para validación de tarifas (P18)
    - **Property 18: Validación de tarifas — campos positivos**
    - Usar `fast-check`: campos con valores ≤ 0 o discount_percentage fuera de [0,100] → PUT /admin/tariffs → assert 422
    - Tag: `// Feature: smart-lottery-app, Property 18`
    - **Validates: Requirements 13.4, 13.5, 13.6, 13.7**

- [x] 25. Backend — Módulo cuentas bancarias, mensajes predefinidos y OAuth (SuperAdmin)
  - [x] 25.1 Implementar Bank Account Repository y Service
    - Crear `backend/src/repositories/bankAccount.repository.ts`: métodos `findAll()`, `findActive()`, `create(data)`, `update(id, data)`, `setStatus(id, is_active)`, `delete(id)`
    - Crear `backend/src/services/bankAccount.service.ts`: CRUD completo delegando al repository
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 14.7, 14.8_

  - [x] 25.2 Implementar Predefined Message Repository y Service
    - Crear `backend/src/repositories/predefinedMessage.repository.ts`: métodos `findAll()`, `findById(id)`, `create(data)`, `update(id, data)`, `setStatus(id, is_active)`, `delete(id)`
    - Crear `backend/src/services/predefinedMessage.service.ts`: CRUD completo con validación de rol CHECK ('sender','receiver','general')
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6, 15.7, 15.9_

  - [x] 25.3 Implementar OAuth Provider Repository y Service
    - Crear `backend/src/repositories/oauthProvider.repository.ts`: métodos `findAll()`, `findByProvider(name)`, `upsert(provider, data, updatedBy)`, `setStatus(provider, is_active)`
    - Crear `backend/src/services/oauth.service.ts`: `getProviders()` (con client_secret enmascarado), `updateProvider(name, data, adminId)` con validación de campos no vacíos y registro en `audit_logs` con acción `OAUTH_CONFIG_UPDATED` (sin loguear client_secret), `setProviderStatus(name, is_active)`
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5, 16.6, 16.8_

  - [x] 25.4 Implementar Admin Controller — rutas bank accounts, messages y OAuth
    - Extender `admin.controller.ts`: handlers para todos los endpoints de `/admin/bank-accounts`, `/bank-accounts`, `/admin/messages`, `/admin/oauth`
    - Proteger con `auth.middleware` + `superAdmin.middleware` (excepto GET /bank-accounts con solo `auth.middleware` y GET /admin/messages con `admin.middleware`)
    - Crear DTOs: `CreateBankAccountDto`, `UpdateBankAccountDto`, `CreateMessageDto`, `UpdateMessageDto`, `UpdateOAuthProviderDto`, `ToggleStatusDto`
    - _Requirements: 14.2, 14.3, 14.4, 14.5, 14.7, 14.8, 15.2, 15.3, 15.5, 15.6, 15.7, 15.9, 16.2, 16.3, 16.8_

  - [ ]* 25.5 Escribir property test para enmascaramiento OAuth (P19)
    - **Property 19: client_secret enmascarado en respuesta OAuth**
    - Usar `fast-check`: cualquier configuración OAuth guardada → GET /admin/oauth → assert client_secret == "***" en todos los registros
    - Tag: `// Feature: smart-lottery-app, Property 19`
    - **Validates: Requirements 16.2**

- [x] 26. Flutter — Pantallas de administración
  - [x] 26.1 Documentar alcance del panel admin en mobile vs web
    - El panel de administración (R9–R16) está diseñado para uso web/desktop. En la app Flutter mobile, implementar únicamente:
      - Visualización de cuentas bancarias activas (`GET /bank-accounts`) en la pantalla de pagos
      - Detección de cuenta desactivada en login (manejo de HTTP 403 con mensaje específico)
    - Las pantallas de gestión admin completas (usuarios, stats, logs, tarifas, mensajes, OAuth) son web-only y quedan fuera del scope de la app Flutter mobile
    - _Requirements: 10.7, 14.7_

  - [x] 26.2 Implementar visualización de cuentas bancarias en Flutter
    - Crear `flutter_app/lib/features/payments/data/bank_account_repository.dart`: llamada a `GET /bank-accounts` via api_client
    - Crear `flutter_app/lib/features/payments/presentation/bank_accounts_screen.dart`: lista de cuentas activas con banco, número, titular y tipo
    - _Requirements: 14.7_

  - [x] 26.3 Manejar cuenta desactivada en pantalla de login
    - Modificar `flutter_app/lib/features/auth/presentation/login_screen.dart`: detectar HTTP 403 con mensaje "Tu cuenta está desactivada" y mostrar mensaje específico al usuario (distinto del error de credenciales inválidas)
    - _Requirements: 10.7_

- [x] 27. Checkpoint final — Módulos admin completos
  - Verificar que todos los endpoints `/admin/*` retornan 403 sin token admin válido.
  - Verificar que endpoints SuperAdmin retornan 403 con token admin (no superadmin).
  - Ejecutar suite de tests de los módulos 21–26.
  - Asegurar que todos los tests pasen. Consultar al usuario si surgen dudas.

## Notes

- Las sub-tareas marcadas con `*` son opcionales y pueden omitirse para un MVP más rápido
- Cada tarea referencia los requisitos específicos para trazabilidad completa
- Los checkpoints garantizan validación incremental antes de avanzar a la siguiente capa
- Los property tests validan las 20 propiedades de corrección definidas en el diseño (P1–P20)
- Los tests unitarios complementan los property tests para flujos concretos y casos borde
- Las tareas 21–26 cubren los módulos de administración (R9–R16); el panel admin completo es web-only
- La tarea 26 documenta explícitamente qué partes del módulo admin aplican a la app Flutter mobile
