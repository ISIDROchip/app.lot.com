# Requirements Document

## Introduction

Smart Lottery App es una aplicación móvil multiplataforma (Flutter) con backend Node.js/TypeScript y microservicio de IA en Python. Ayuda a jugadores de lotería a interpretar sueños para obtener números sugeridos, analizar estadísticas históricas, generar jugadas optimizadas y gestionar su historial personal. La aplicación incluye validación de edad obligatoria para garantizar que solo usuarios mayores de edad accedan al servicio.

## Glossary

- **App**: Aplicación móvil Flutter que actúa como cliente principal.
- **API_Gateway**: Capa de entrada del backend Node.js/Express que enruta peticiones a los microservicios correspondientes.
- **Auth_Service**: Módulo del backend responsable de registro, login y emisión de tokens JWT.
- **Dream_Service**: Microservicio Python (FastAPI) que analiza texto de sueños y devuelve números sugeridos.
- **Stats_Service**: Módulo del backend que procesa resultados históricos y calcula frecuencias y tendencias.
- **Lottery_Service**: Módulo del backend que genera combinaciones de jugadas optimizadas.
- **User_Repository**: Capa de acceso a datos para entidades de usuario en PostgreSQL.
- **Lottery_Repository**: Capa de acceso a datos para jugadas e historial en PostgreSQL.
- **JWT_Token**: Token de autenticación JSON Web Token emitido tras login exitoso.
- **Jugada**: Combinación de números generada para un tipo de lotería específico.
- **Tipo_Jugada**: Categoría de jugada: Loto, Pale, Tripleta o Número.
- **Resultado_Historico**: Registro de números ganadores de sorteos anteriores almacenado en la base de datos.
- **Frecuencia**: Número de veces que un número ha aparecido en los resultados históricos.
- **Admin**: Usuario con el campo `is_admin = true` en la tabla `users`, asignado exclusivamente mediante SQL directo en base de datos. Puede gestionar usuarios y consultar mensajes predefinidos en modo lectura.
- **SuperAdmin**: Usuario con el campo `is_super_admin = true` en la tabla `users`, asignado exclusivamente mediante SQL directo en base de datos. Tiene acceso completo al panel de administración, incluyendo todas las funciones de Admin más estadísticas del sistema, logs, tarifas, cuentas bancarias, CRUD de mensajes predefinidos y configuración OAuth.
- **Admin_Service**: Módulo del backend que expone los endpoints del panel de administración, protegidos por roles Admin o SuperAdmin según el recurso.
- **User_Management_Service**: Sub-módulo del Admin_Service responsable de listar, activar y desactivar usuarios.
- **System_Stats_Service**: Sub-módulo del Admin_Service responsable de calcular y retornar métricas globales del sistema (solo SuperAdmin).
- **Error_Log_Repository**: Capa de acceso a datos para la tabla `application_errors` en PostgreSQL.
- **Tariff_Repository**: Capa de acceso a datos para la configuración de tarifas en PostgreSQL.
- **Bank_Account_Repository**: Capa de acceso a datos para las cuentas bancarias de la empresa en PostgreSQL.
- **Predefined_Message_Repository**: Capa de acceso a datos para los mensajes predefinidos en PostgreSQL.
- **OAuth_Config_Repository**: Capa de acceso a datos para la configuración de proveedores OAuth en PostgreSQL.
- **Usuario_Activo**: Usuario cuyo campo `is_active = true` en la tabla `users`. Solo los usuarios activos pueden iniciar sesión.
- **Usuario_Inactivo**: Usuario cuyo campo `is_active = false` en la tabla `users`. No puede iniciar sesión aunque sus credenciales sean válidas.
- **Cuenta_Bancaria**: Registro en la tabla `company_bank_accounts` que contiene banco, número de cuenta, tipo, titular y descripción. Solo las cuentas con `is_active = true` se muestran a usuarios finales.
- **Mensaje_Predefinido**: Registro en la tabla `predefined_messages` con título, texto, tipo, rol (emisor/receptor/general) y estado activo/inactivo. Los mensajes eliminados no son recuperables.
- **OAuth_Provider**: Registro en la tabla `oauth_providers` que almacena Client ID, Client Secret, Redirect URI y estado activo/inactivo para un proveedor de autenticación social (Google o Facebook).
- **Audit_Log**: Registro en la tabla `audit_logs` que captura acciones sensibles del sistema con user_id, acción, IP y metadata.

---

## Requirements

### Requirement 1: Registro y Validación de Edad

**User Story:** As a new user, I want to register with my personal data and have my age validated, so that I can access the platform only if I meet the minimum age requirement.

#### Acceptance Criteria

1. THE Auth_Service SHALL expose a `POST /users/register` endpoint that accepts nombre completo, fecha de nacimiento, correo electrónico y número de teléfono.
2. WHEN a registration request is received, THE Auth_Service SHALL calculate the user's age from the provided date of birth.
3. IF the calculated age is less than 18 years, THEN THE Auth_Service SHALL reject the registration and return an HTTP 403 response with the message "Debes ser mayor de 18 años para registrarte".
4. WHEN the age validation passes, THE Auth_Service SHALL hash the user's password using bcrypt before storing it in the database.
5. WHEN a user is successfully registered, THE Auth_Service SHALL return an HTTP 201 response containing the user's ID and email.
6. IF the provided email already exists in the database, THEN THE Auth_Service SHALL return an HTTP 409 response with the message "El correo ya está registrado".
7. THE Auth_Service SHALL validate that the email field matches a valid email format before processing the registration.
8. THE Auth_Service SHALL validate that the phone number field contains between 8 and 15 numeric digits before processing the registration.

---

### Requirement 2: Autenticación con JWT

**User Story:** As a registered user, I want to log in with my credentials and receive a token, so that I can access protected endpoints securely.

#### Acceptance Criteria

1. THE Auth_Service SHALL expose a `POST /users/login` endpoint that accepts correo electrónico y contraseña.
2. WHEN valid credentials are provided, THE Auth_Service SHALL return an HTTP 200 response containing a JWT_Token with an expiration of 24 hours.
3. IF the provided credentials do not match any user record, THEN THE Auth_Service SHALL return an HTTP 401 response with the message "Credenciales inválidas".
4. WHILE a JWT_Token is valid and not expired, THE API_Gateway SHALL allow access to protected endpoints.
5. IF a request to a protected endpoint is received without a JWT_Token, THEN THE API_Gateway SHALL return an HTTP 401 response.
6. IF a request to a protected endpoint is received with an expired or malformed JWT_Token, THEN THE API_Gateway SHALL return an HTTP 401 response.

---

### Requirement 3: Interpretación de Sueños con IA

**User Story:** As a logged-in user, I want to describe a dream in natural language and receive suggested lottery numbers, so that I can use AI-based insights for my plays.

#### Acceptance Criteria

1. THE API_Gateway SHALL expose a `POST /dreams/interpret` endpoint protected by JWT authentication.
2. WHEN a dream interpretation request is received, THE API_Gateway SHALL forward the request payload to the Dream_Service.
3. THE Dream_Service SHALL accept a text input of between 10 and 2000 characters representing the dream description.
4. WHEN a valid dream text is received, THE Dream_Service SHALL analyze the semantic content and return a list of between 3 and 6 suggested numbers in the range 1–36.
5. IF the dream text input is fewer than 10 characters, THEN THE Dream_Service SHALL return an HTTP 400 response with the message "La descripción del sueño es demasiado corta".
6. IF the Dream_Service is unavailable, THEN THE API_Gateway SHALL return an HTTP 503 response with the message "El servicio de interpretación no está disponible".
7. WHEN a dream interpretation is completed successfully, THE Lottery_Repository SHALL store the dream text, the suggested numbers, and the user ID with a timestamp.

---

### Requirement 4: Análisis Estadístico de Resultados Históricos

**User Story:** As a logged-in user, I want to upload historical lottery results and view frequency analysis, so that I can make data-informed decisions about my plays.

#### Acceptance Criteria

1. THE API_Gateway SHALL expose a `POST /stats/upload-results` endpoint protected by JWT authentication.
2. WHEN a results upload request is received, THE Stats_Service SHALL accept a JSON array of Resultado_Historico objects, each containing a draw date and an array of winning numbers.
3. THE Stats_Service SHALL validate that each winning number in the uploaded results is an integer in the range 1–36.
4. IF any number in the uploaded results is outside the range 1–36, THEN THE Stats_Service SHALL return an HTTP 400 response listing the invalid entries.
5. WHEN results are successfully stored, THE Stats_Service SHALL calculate the Frecuencia of each number across all stored Resultado_Historico records.
6. THE Stats_Service SHALL expose a `GET /stats/frequency` endpoint that returns the Frecuencia of all numbers sorted in descending order.
7. THE Stats_Service SHALL expose a `GET /stats/trends` endpoint that returns the 5 most frequent and 5 least frequent numbers based on stored Resultado_Historico records.
8. WHEN frequency data is requested, THE Stats_Service SHALL respond within 2000 milliseconds for datasets of up to 10,000 Resultado_Historico records.

---

### Requirement 5: Generación de Jugadas Optimizadas

**User Story:** As a logged-in user, I want to generate lottery plays optimized by balance and frequency, so that I can improve my selection strategy.

#### Acceptance Criteria

1. THE API_Gateway SHALL expose a `POST /lottery/request-number` endpoint protected by JWT authentication.
2. WHEN a play generation request is received, THE Lottery_Service SHALL accept a Tipo_Jugada parameter with one of the values: Loto, Pale, Tripleta, Número.
3. WHEN Tipo_Jugada is Loto, THE Lottery_Service SHALL generate a combination of 6 unique numbers in the range 1–36.
4. WHEN Tipo_Jugada is Pale, THE Lottery_Service SHALL generate a combination of 2 unique numbers in the range 1–36.
5. WHEN Tipo_Jugada is Tripleta, THE Lottery_Service SHALL generate a combination of 3 unique numbers in the range 1–36.
6. WHEN Tipo_Jugada is Número, THE Lottery_Service SHALL generate 1 number in the range 1–36.
7. WHEN generating a Loto combination, THE Lottery_Service SHALL ensure the combination contains exactly 3 even numbers and 3 odd numbers.
8. WHEN generating a combination, THE Lottery_Service SHALL weight number selection by Frecuencia data from the Stats_Service, giving higher probability to more frequent numbers.
9. WHEN generating a combination, THE Lottery_Service SHALL reject any combination where 3 or more consecutive numbers appear in sequence (e.g., 4, 5, 6).
10. WHEN a Jugada is generated successfully, THE Lottery_Repository SHALL store the Jugada with the user ID, Tipo_Jugada, generated numbers, and a timestamp.
11. IF the Stats_Service has no stored Resultado_Historico records, THEN THE Lottery_Service SHALL generate combinations using uniform random distribution.

---

### Requirement 6: Historial de Jugadas del Usuario

**User Story:** As a logged-in user, I want to view my history of generated plays and dream interpretations, so that I can track my activity over time.

#### Acceptance Criteria

1. THE API_Gateway SHALL expose a `GET /users/history` endpoint protected by JWT authentication.
2. WHEN a history request is received, THE Lottery_Repository SHALL return all Jugadas and dream interpretations associated with the authenticated user's ID.
3. THE API_Gateway SHALL return the history records sorted by timestamp in descending order.
4. WHEN the authenticated user has no history records, THE API_Gateway SHALL return an HTTP 200 response with an empty array.
5. THE API_Gateway SHALL support pagination on the `GET /users/history` endpoint, accepting `page` and `limit` query parameters with default values of 1 and 20 respectively.

---

### Requirement 7: Seguridad y Protección de Datos

**User Story:** As a platform operator, I want all endpoints and user data to be protected, so that the application complies with security best practices.

#### Acceptance Criteria

1. THE API_Gateway SHALL enforce HTTPS for all incoming requests in production environments.
2. THE Auth_Service SHALL store user passwords exclusively as bcrypt hashes with a minimum cost factor of 10.
3. THE API_Gateway SHALL apply rate limiting of a maximum of 100 requests per minute per IP address on all endpoints.
4. THE API_Gateway SHALL sanitize all incoming request payloads to prevent SQL injection and XSS attacks before forwarding to downstream services.
5. THE Auth_Service SHALL never include the user's password hash in any API response.
6. WHERE JWT authentication is required, THE API_Gateway SHALL validate the token signature using a secret key stored as an environment variable and not hardcoded in source code.

---

### Requirement 8: Prerrequisitos e Instalación del Entorno

**User Story:** As a developer setting up the project for the first time, I want clear documentation of all required tools and installation steps, so that I can get the development environment running without prior knowledge of the stack.

#### Acceptance Criteria

1. THE System SHALL provide a `README.md` file listing all required software with minimum version numbers: Flutter (≥ 3.10), Node.js (≥ 18.0), Python (≥ 3.10), PostgreSQL (≥ 14.0), and Docker (≥ 24.0).
2. THE System SHALL provide a `docker-compose.yml` file that starts PostgreSQL and all backend services with a single `docker compose up` command.
3. WHEN the `docker compose up` command is executed, THE System SHALL initialize the PostgreSQL database schema automatically using migration scripts.
4. THE System SHALL provide environment variable template files (`.env.example`) for each service (backend, dream-service) listing all required variables with placeholder values.
5. IF a required environment variable is missing at service startup, THEN THE System SHALL log an error message identifying the missing variable and exit with a non-zero status code.

---

### Requirement 9: Roles de Administración (Admin y SuperAdmin)

**User Story:** As a platform operator, I want to assign administrative roles to specific users via direct database access, so that privileged operations are protected from unauthorized access through the application interface.

#### Acceptance Criteria

1. THE System SHALL add boolean columns `is_admin` and `is_super_admin` to the `users` table, both defaulting to `false`.
2. THE System SHALL add a boolean column `is_active` to the `users` table, defaulting to `true`.
3. THE Auth_Service SHALL assign administrative roles exclusively through direct SQL statements executed in the database, with no endpoint available for role assignment via the API.
4. WHEN a JWT_Token is issued, THE Auth_Service SHALL include the `is_admin` and `is_super_admin` fields of the authenticated user in the token payload.
5. THE Admin_Service SHALL expose all admin endpoints under the `/admin` path prefix, protected by JWT authentication.
6. WHEN a request to an Admin endpoint is received from a user whose JWT_Token does not contain `is_admin = true` or `is_super_admin = true`, THEN THE Admin_Service SHALL return an HTTP 403 response.
7. WHEN a request to a SuperAdmin-only endpoint is received from a user whose JWT_Token contains `is_admin = true` but `is_super_admin = false`, THEN THE Admin_Service SHALL return an HTTP 403 response.

---

### Requirement 10: Gestión de Usuarios (Admin y SuperAdmin)

**User Story:** As an Admin or SuperAdmin, I want to list users, view their details, and activate or deactivate accounts, so that I can manage platform access effectively.

#### Acceptance Criteria

1. THE Admin_Service SHALL expose a `GET /admin/users` endpoint accessible to users with `is_admin = true` or `is_super_admin = true`, returning a paginated list of users with fields: id, full_name, email, phone, is_active, is_admin, is_super_admin, created_at.
2. THE Admin_Service SHALL support `page`, `limit`, and optional `search` query parameters on `GET /admin/users`, where `search` filters by partial match on full_name or email.
3. THE Admin_Service SHALL expose a `GET /admin/users/:id` endpoint accessible to Admin and SuperAdmin, returning the full detail of a single user.
4. IF the requested user ID does not exist, THEN THE Admin_Service SHALL return an HTTP 404 response.
5. THE Admin_Service SHALL expose a `PATCH /admin/users/:id/status` endpoint accessible to Admin and SuperAdmin, accepting a body with `is_active: boolean` to activate or deactivate a user account.
6. WHEN a user account is deactivated via `PATCH /admin/users/:id/status`, THE User_Management_Service SHALL set `is_active = false` for that user in the database.
7. WHEN a deactivated user attempts to log in, THE Auth_Service SHALL return an HTTP 403 response with the message "Tu cuenta está desactivada. Contacta al administrador".
8. THE Admin_Service SHALL prevent an Admin or SuperAdmin from deactivating their own account via the `PATCH /admin/users/:id/status` endpoint, returning HTTP 400 if attempted.

---

### Requirement 11: Estadísticas y Métricas del Sistema (SuperAdmin)

**User Story:** As a SuperAdmin, I want to view global system metrics and activity summaries, so that I can monitor platform health and usage trends.

#### Acceptance Criteria

1. THE Admin_Service SHALL expose a `GET /admin/stats/overview` endpoint accessible exclusively to users with `is_super_admin = true`.
2. WHEN the overview endpoint is called, THE System_Stats_Service SHALL return the following metrics: total registered users, total plays generated, total dream interpretations, and total active users.
3. THE Admin_Service SHALL expose a `GET /admin/stats/activity` endpoint accessible exclusively to SuperAdmin, accepting `from` and `to` query parameters in ISO 8601 date format to filter activity by period.
4. WHEN the activity endpoint is called with valid date parameters, THE System_Stats_Service SHALL return the count of new registrations, plays, and dream interpretations within the specified period.
5. IF the `from` date is after the `to` date in the activity request, THEN THE Admin_Service SHALL return an HTTP 400 response with the message "El parámetro 'from' debe ser anterior a 'to'".
6. WHEN the activity endpoint is called without date parameters, THE System_Stats_Service SHALL return metrics for the last 30 days by default.

---

### Requirement 12: Logs y Errores del Sistema (SuperAdmin)

**User Story:** As a SuperAdmin, I want to consult recent application errors and system logs, so that I can diagnose issues and monitor platform stability.

#### Acceptance Criteria

1. THE System SHALL create an `application_errors` table in PostgreSQL with columns: id (UUID), reference_id (UUID, unique), error_code (VARCHAR), message (TEXT), stack_trace (TEXT), context (JSONB), created_at (TIMESTAMPTZ).
2. WHEN an unhandled exception occurs in the backend, THE System SHALL insert a record into `application_errors` with a unique `reference_id` UUID and include that UUID in the HTTP error response returned to the client.
3. THE Admin_Service SHALL expose a `GET /admin/logs/errors` endpoint accessible exclusively to SuperAdmin, returning the most recent 100 error records ordered by `created_at` descending.
4. THE Admin_Service SHALL support an optional `reference_id` query parameter on `GET /admin/logs/errors` to retrieve a single error record by its reference UUID.
5. IF no error record matches the provided `reference_id`, THEN THE Admin_Service SHALL return an HTTP 404 response.
6. THE System SHALL implement daily log rotation for `application_errors`, archiving records older than 30 days to a separate `application_errors_archive` table and deleting them from the main table.
7. THE Admin_Service SHALL expose a `GET /admin/logs/audit` endpoint accessible exclusively to SuperAdmin, returning the most recent 200 Audit_Log records ordered by `created_at` descending, with optional `user_id` and `action` filter parameters.

---

### Requirement 13: Configuración de Tarifas (SuperAdmin)

**User Story:** As a SuperAdmin, I want to configure the cost per play and volume discounts, so that I can adjust the platform's pricing model without code changes.

#### Acceptance Criteria

1. THE System SHALL create a `tariff_config` table in PostgreSQL with columns: id (UUID), base_cost_per_play (NUMERIC), subscription_cost (NUMERIC), discount_percentage (NUMERIC), min_plays_for_discount (INTEGER), updated_by (UUID references users), updated_at (TIMESTAMPTZ).
2. THE Admin_Service SHALL expose a `GET /admin/tariffs` endpoint accessible exclusively to SuperAdmin, returning the current tariff configuration.
3. THE Admin_Service SHALL expose a `PUT /admin/tariffs` endpoint accessible exclusively to SuperAdmin, accepting `base_cost_per_play`, `subscription_cost`, `discount_percentage`, and `min_plays_for_discount` fields.
4. WHEN a tariff update request is received, THE Admin_Service SHALL validate that `base_cost_per_play` and `subscription_cost` are positive numbers greater than 0.
5. WHEN a tariff update request is received, THE Admin_Service SHALL validate that `discount_percentage` is a number in the range [0, 100].
6. WHEN a tariff update request is received, THE Admin_Service SHALL validate that `min_plays_for_discount` is a positive integer greater than 0.
7. IF any tariff field fails validation, THEN THE Admin_Service SHALL return an HTTP 422 response listing the invalid fields.
8. WHEN a tariff configuration is updated successfully, THE Admin_Service SHALL record the change in `audit_logs` with the action `TARIFF_UPDATED` and the previous and new values in the metadata field.

---

### Requirement 14: Cuentas Bancarias de la Empresa (SuperAdmin)

**User Story:** As a SuperAdmin, I want to manage the company's bank accounts, so that users can see accurate payment information and inactive accounts are hidden from them.

#### Acceptance Criteria

1. THE System SHALL create a `company_bank_accounts` table in PostgreSQL with columns: id (UUID), bank_name (VARCHAR), account_number (VARCHAR), account_type (VARCHAR), account_holder (VARCHAR), description (TEXT), is_active (BOOLEAN DEFAULT true), created_at (TIMESTAMPTZ), updated_at (TIMESTAMPTZ).
2. THE Admin_Service SHALL expose a `GET /admin/bank-accounts` endpoint accessible exclusively to SuperAdmin, returning all bank accounts including inactive ones.
3. THE Admin_Service SHALL expose a `POST /admin/bank-accounts` endpoint accessible exclusively to SuperAdmin, accepting `bank_name`, `account_number`, `account_type`, `account_holder`, and `description` fields.
4. THE Admin_Service SHALL expose a `PUT /admin/bank-accounts/:id` endpoint accessible exclusively to SuperAdmin, accepting the same fields as the POST endpoint to update an existing account.
5. THE Admin_Service SHALL expose a `PATCH /admin/bank-accounts/:id/status` endpoint accessible exclusively to SuperAdmin, accepting `is_active: boolean` to toggle the account's active state.
6. WHEN a bank account is deactivated via the status endpoint, THE Admin_Service SHALL set `is_active = false` for that account without deleting the record.
7. THE API_Gateway SHALL expose a `GET /bank-accounts` endpoint accessible to authenticated users, returning only Cuenta_Bancaria records where `is_active = true`.
8. THE Admin_Service SHALL expose a `DELETE /admin/bank-accounts/:id` endpoint accessible exclusively to SuperAdmin, which permanently deletes the bank account record.

---

### Requirement 15: Mensajes Predefinidos (Admin lectura / SuperAdmin CRUD)

**User Story:** As an Admin, I want to view predefined messages; as a SuperAdmin, I want to create, update, and delete them, so that the platform can communicate consistently with users.

#### Acceptance Criteria

1. THE System SHALL create a `predefined_messages` table in PostgreSQL with columns: id (UUID), title (VARCHAR), body (TEXT), message_type (VARCHAR), role (VARCHAR CHECK IN ('sender', 'receiver', 'general')), is_active (BOOLEAN DEFAULT true), created_at (TIMESTAMPTZ), updated_at (TIMESTAMPTZ).
2. THE Admin_Service SHALL expose a `GET /admin/messages` endpoint accessible to Admin and SuperAdmin, returning all predefined messages including inactive ones.
3. THE Admin_Service SHALL expose a `GET /admin/messages/:id` endpoint accessible to Admin and SuperAdmin, returning the detail of a single message.
4. IF the requested message ID does not exist, THEN THE Admin_Service SHALL return an HTTP 404 response.
5. THE Admin_Service SHALL expose a `POST /admin/messages` endpoint accessible exclusively to SuperAdmin, accepting `title`, `body`, `message_type`, `role`, and `is_active` fields.
6. THE Admin_Service SHALL expose a `PUT /admin/messages/:id` endpoint accessible exclusively to SuperAdmin, accepting the same fields as the POST endpoint to update an existing message.
7. THE Admin_Service SHALL expose a `DELETE /admin/messages/:id` endpoint accessible exclusively to SuperAdmin, which permanently deletes the message record with no recovery mechanism.
8. WHEN an Admin user (with `is_admin = true` but `is_super_admin = false`) attempts to call `POST`, `PUT`, or `DELETE` on message endpoints, THEN THE Admin_Service SHALL return an HTTP 403 response.
9. THE Admin_Service SHALL expose a `PATCH /admin/messages/:id/status` endpoint accessible exclusively to SuperAdmin, accepting `is_active: boolean` to toggle the message's active state.

---

### Requirement 16: Configuración OAuth Google / Facebook (SuperAdmin)

**User Story:** As a SuperAdmin, I want to configure and toggle OAuth providers for Google and Facebook, so that users can authenticate via social login when the feature is enabled.

#### Acceptance Criteria

1. THE System SHALL create an `oauth_providers` table in PostgreSQL with columns: id (UUID), provider_name (VARCHAR CHECK IN ('google', 'facebook')), client_id (VARCHAR), client_secret (VARCHAR), redirect_uri (VARCHAR), is_active (BOOLEAN DEFAULT false), updated_by (UUID references users), updated_at (TIMESTAMPTZ).
2. THE Admin_Service SHALL expose a `GET /admin/oauth` endpoint accessible exclusively to SuperAdmin, returning all OAuth_Provider records with `client_secret` masked (replaced by `"***"`).
3. THE Admin_Service SHALL expose a `PUT /admin/oauth/:provider` endpoint accessible exclusively to SuperAdmin, accepting `client_id`, `client_secret`, `redirect_uri`, and `is_active` fields for the specified provider.
4. WHEN an OAuth configuration is updated, THE Admin_Service SHALL validate that `client_id`, `client_secret`, and `redirect_uri` are non-empty strings before persisting the change.
5. IF any required OAuth field is empty or missing, THEN THE Admin_Service SHALL return an HTTP 422 response listing the invalid fields.
6. WHEN an OAuth configuration is updated successfully, THE Admin_Service SHALL record the change in `audit_logs` with the action `OAUTH_CONFIG_UPDATED`, the provider name, and the previous and new values of `is_active` and `redirect_uri` in the metadata field (client_secret SHALL NOT be logged).
7. WHEN a user attempts to authenticate via a social provider whose `is_active = false`, THEN THE Auth_Service SHALL return an HTTP 400 response with the message "El proveedor de autenticación '{provider}' no está habilitado".
8. THE Admin_Service SHALL expose a `PATCH /admin/oauth/:provider/status` endpoint accessible exclusively to SuperAdmin, accepting `is_active: boolean` to toggle the provider without modifying other fields.
