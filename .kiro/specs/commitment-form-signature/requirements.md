# Requirements Document

## Introduction

La feature **Commitment Form Signature** agrega un formulario de compromiso legal que el usuario debe firmar digitalmente antes de recibir un "Pull de 10 combinaciones" de lotería. El formulario captura datos personales del usuario (nombre, apellido, dirección, cédula, teléfono), presenta cláusulas legales donde el usuario se compromete a pagar el 30 % de las ganancias si alguna de las combinaciones resulta ganadora, y recoge dos modalidades de firma: firma digital dibujada con el dedo en pantalla y aceptación mediante checkbox. Una vez firmado, el sistema genera un reporte del contrato almacenado en base de datos y disponible como documento en Base64. Las demás opciones de la app (Loto, Pale, Tripleta, Número individual) permanecen gratuitas y no requieren este contrato.

---

## Glossary

- **Commitment_Service**: Módulo del backend Node.js/Express responsable de crear, validar, almacenar y recuperar contratos de compromiso.
- **Commitment_Repository**: Capa de acceso a datos para las tablas `commitment_contracts` y `commitment_signatures` en PostgreSQL.
- **Contract**: Registro completo de un contrato de compromiso firmado, que incluye datos personales, cláusulas aceptadas, firma digital y estado.
- **Digital_Signature**: Imagen de la firma dibujada por el usuario en pantalla, almacenada como cadena Base64 (PNG).
- **Checkbox_Acceptance**: Confirmación booleana de que el usuario leyó y aceptó las cláusulas legales.
- **Pull_Service**: Módulo del backend responsable de generar el pull de 10 combinaciones de lotería.
- **Pull_de_10**: Conjunto de 10 combinaciones de lotería generadas para un usuario, disponible únicamente tras la firma de un Contract válido.
- **Contract_Report**: Documento PDF/Base64 generado a partir de un Contract firmado, que incluye todos los datos del formulario, las cláusulas y la imagen de la firma.
- **Contract_Status**: Estado del contrato: `pending` (creado pero no firmado), `signed` (firmado y válido), `expired` (superó el tiempo límite sin firma).
- **Cedula**: Número de identificación nacional del usuario (documento de identidad).
- **Clause**: Texto legal individual dentro del contrato que el usuario debe aceptar.
- **API_Gateway**: Capa de entrada del backend Node.js/Express que enruta peticiones a los módulos correspondientes.
- **Auth_Service**: Módulo del backend responsable de autenticación JWT (ya existente).
- **JWT_Token**: Token de autenticación JSON Web Token emitido tras login exitoso (ya existente).
- **Lottery_Service**: Módulo del backend que genera combinaciones de jugadas (ya existente).
- **User_Repository**: Capa de acceso a datos para entidades de usuario en PostgreSQL (ya existente).

---

## Requirements

### Requirement 1: Presentación del Formulario de Compromiso

**User Story:** As a logged-in user, I want to see the commitment form before requesting a Pull de 10, so that I understand the legal terms I am agreeing to.

#### Acceptance Criteria

1. THE API_Gateway SHALL expose a `GET /commitment/form` endpoint protected by JWT authentication that returns the current contract template including all Clauses and field definitions.
2. WHEN a user navigates to the Pull de 10 option in the app, THE App SHALL display the commitment form before allowing the generation request.
3. THE Commitment_Service SHALL return the contract template with the following required fields: first name, last name, address, cedula, and phone number.
4. THE Commitment_Service SHALL include in the contract template the clause stating that the user accepts the terms of the Pull de 10 service, with a limit of 20 pulls per 30 days, and that each pull requires identity verification via cedula and corresponding payment.
5. WHEN the contract template is requested, THE Commitment_Service SHALL respond within 1000 milliseconds.

---

### Requirement 2: Validación de Datos del Formulario

**User Story:** As a platform operator, I want all personal data fields to be validated before a contract is created, so that incomplete or malformed contracts are never stored.

#### Acceptance Criteria

1. THE Commitment_Service SHALL validate that the `first_name` field contains between 2 and 60 characters and only alphabetic characters including accented letters and spaces.
2. THE Commitment_Service SHALL validate that the `last_name` field contains between 2 and 60 characters and only alphabetic characters including accented letters and spaces.
3. THE Commitment_Service SHALL validate that the `address` field contains between 10 and 255 characters.
4. THE Commitment_Service SHALL validate that the `cedula` field contains between 6 and 20 alphanumeric characters.
5. THE Commitment_Service SHALL validate that the `phone` field contains between 8 and 15 numeric digits.
6. IF any required field fails validation, THEN THE Commitment_Service SHALL return an HTTP 422 response listing each invalid field with a descriptive error message.
7. THE Commitment_Service SHALL validate that the `digital_signature` field is a non-empty Base64-encoded PNG string with a minimum decoded size of 1 KB.
8. THE Commitment_Service SHALL validate that the `checkbox_acceptance` field is `true` before creating a Contract.
9. IF `checkbox_acceptance` is `false` or absent, THEN THE Commitment_Service SHALL return an HTTP 422 response with the message "Debes aceptar las cláusulas del contrato para continuar".

---

### Requirement 3: Creación y Almacenamiento del Contrato

**User Story:** As a logged-in user, I want my signed commitment contract to be stored securely, so that there is a permanent legal record of my agreement.

#### Acceptance Criteria

1. THE API_Gateway SHALL expose a `POST /commitment/sign` endpoint protected by JWT authentication that accepts the personal data fields, digital signature, and checkbox acceptance.
2. WHEN a valid contract submission is received, THE Commitment_Service SHALL create a Contract record with `status = 'signed'` and associate it with the authenticated user's ID.
3. THE Commitment_Repository SHALL store the Contract in the `commitment_contracts` table with columns: id, user_id, first_name, last_name, address, cedula, phone, checkbox_acceptance, contract_version, ip_address, signed_at, created_at.
4. THE Commitment_Repository SHALL store the Digital_Signature in the `commitment_signatures` table with columns: id, contract_id, signature_data (TEXT/Base64), created_at.
5. WHEN a Contract is successfully created, THE Commitment_Service SHALL return an HTTP 201 response containing the contract_id and signed_at timestamp.
6. THE Commitment_Service SHALL record the contract creation in `audit_logs` with the action `CONTRACT_SIGNED` and the contract_id in the metadata field.
7. WHILE a user already has a Contract with `status = 'signed'` created within the last 30 days, THE Commitment_Service SHALL allow the user to request a new Pull de 10 without re-signing.
8. THE Commitment_Service SHALL store the `contract_version` field to track which version of the legal clauses the user accepted.

---

### Requirement 4: Control de Acceso al Pull de 10

**User Story:** As a platform operator, I want the Pull de 10 to be accessible only to users who have a valid signed contract, so that the legal commitment is enforced before generating combinations.

#### Acceptance Criteria

1. THE API_Gateway SHALL expose a `POST /lottery/pull-10` endpoint protected by JWT authentication for generating the Pull de 10.
2. WHEN a Pull de 10 request is received, THE Pull_Service SHALL verify that the authenticated user has a Contract with `status = 'signed'` before generating combinations.
3. IF the authenticated user does not have a Contract with `status = 'signed'`, THEN THE Pull_Service SHALL return an HTTP 403 response with the message "Debes firmar el contrato de compromiso antes de solicitar el Pull de 10".
4. WHEN the user has a valid signed Contract, THE Pull_Service SHALL generate exactly 10 unique lottery combinations of type Loto (6 numbers each, range 1–36).
5. WHEN a Pull de 10 is generated successfully, THE Lottery_Repository SHALL store each of the 10 combinations as individual plays associated with the user_id and with `source = 'pull_10'`.
6. THE Pull_Service SHALL apply the same combination optimization rules as the existing Lottery_Service (balance par/impar, sin secuencias consecutivas, ponderación por frecuencia).
7. WHEN a Pull de 10 is generated, THE Pull_Service SHALL return an HTTP 201 response containing the array of 10 combinations, the contract_id used, and the timestamp.
8. THE Lottery_Service SHALL continue to generate Loto, Pale, Tripleta, and Número individual plays without requiring a signed Contract.

---

### Requirement 5: Generación del Reporte del Contrato

**User Story:** As a logged-in user, I want to download or view my signed contract as a document, so that I have a personal copy of my legal commitment.

#### Acceptance Criteria

1. THE API_Gateway SHALL expose a `GET /commitment/report/:contract_id` endpoint protected by JWT authentication that returns the Contract_Report for the specified contract.
2. WHEN a report request is received, THE Commitment_Service SHALL verify that the contract_id belongs to the authenticated user before returning the report.
3. IF the contract_id does not belong to the authenticated user, THEN THE Commitment_Service SHALL return an HTTP 403 response.
4. IF the contract_id does not exist, THEN THE Commitment_Service SHALL return an HTTP 404 response.
5. WHEN a valid report request is received, THE Commitment_Service SHALL generate a Contract_Report containing: user personal data, all Clauses with their accepted version, the Digital_Signature image, the signed_at timestamp, and the contract_id.
6. THE Commitment_Service SHALL return the Contract_Report as a Base64-encoded PDF string in the response body.
7. THE Commitment_Service SHALL respond to report requests within 3000 milliseconds for contracts with a single Digital_Signature.

---

### Requirement 6: Consulta del Estado del Contrato

**User Story:** As a logged-in user, I want to check whether I have a valid signed contract, so that I know if I can request a Pull de 10 without re-signing.

#### Acceptance Criteria

1. THE API_Gateway SHALL expose a `GET /commitment/status` endpoint protected by JWT authentication that returns the current contract status for the authenticated user.
2. WHEN a status request is received, THE Commitment_Service SHALL return the most recent Contract associated with the authenticated user's ID.
3. WHEN the user has no Contract record, THE Commitment_Service SHALL return an HTTP 200 response with `{ "status": "none", "can_pull": false }`.
4. WHEN the user has a Contract with `status = 'signed'` created within the last 30 days, THE Commitment_Service SHALL return `{ "status": "signed", "can_pull": true, "contract_id": "...", "signed_at": "..." }`.
5. WHEN the user has a Contract with `status = 'signed'` created more than 30 days ago, THE Commitment_Service SHALL return `{ "status": "expired", "can_pull": false }`.

---

### Requirement 7: Gestión de Contratos (Admin y SuperAdmin)

**User Story:** As an Admin or SuperAdmin, I want to view and search commitment contracts, so that I can audit legal agreements and resolve disputes.

#### Acceptance Criteria

1. THE Admin_Service SHALL expose a `GET /admin/commitment/contracts` endpoint accessible to users with `is_admin = true` or `is_super_admin = true`, returning a paginated list of contracts with fields: id, user_id, first_name, last_name, cedula, contract_version, status, signed_at, created_at.
2. THE Admin_Service SHALL support `page`, `limit`, and optional `search` query parameters on `GET /admin/commitment/contracts`, where `search` filters by partial match on cedula, first_name, or last_name.
3. THE Admin_Service SHALL expose a `GET /admin/commitment/contracts/:id` endpoint accessible to Admin and SuperAdmin, returning the full detail of a single Contract including the Digital_Signature.
4. IF the requested contract ID does not exist, THEN THE Admin_Service SHALL return an HTTP 404 response.
5. THE Admin_Service SHALL expose a `GET /admin/commitment/contracts/:id/report` endpoint accessible to Admin and SuperAdmin, returning the Contract_Report as a Base64-encoded PDF string.

---

### Requirement 8: Esquema de Base de Datos

**User Story:** As a developer, I want the commitment feature to use a well-structured PostgreSQL schema consistent with the existing database design, so that the data is reliable and queryable.

#### Acceptance Criteria

1. THE System SHALL create a `commitment_contracts` table in PostgreSQL with columns: id (UUID PK DEFAULT gen_random_uuid()), user_id (UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE), first_name (VARCHAR(60) NOT NULL), last_name (VARCHAR(60) NOT NULL), address (VARCHAR(255) NOT NULL), cedula (VARCHAR(20) NOT NULL), phone (VARCHAR(15) NOT NULL), checkbox_acceptance (BOOLEAN NOT NULL), contract_version (VARCHAR(20) NOT NULL), ip_address (INET), status (VARCHAR(20) NOT NULL DEFAULT 'signed' CHECK IN ('pending','signed','expired')), signed_at (TIMESTAMPTZ NOT NULL DEFAULT NOW()), created_at (TIMESTAMPTZ NOT NULL DEFAULT NOW()).
2. THE System SHALL create a `commitment_signatures` table in PostgreSQL with columns: id (UUID PK DEFAULT gen_random_uuid()), contract_id (UUID NOT NULL REFERENCES commitment_contracts(id) ON DELETE CASCADE), signature_data (TEXT NOT NULL), created_at (TIMESTAMPTZ NOT NULL DEFAULT NOW()).
3. THE System SHALL create the following indexes: `idx_commitment_contracts_user_id` ON commitment_contracts(user_id, signed_at DESC), `idx_commitment_contracts_cedula` ON commitment_contracts(cedula), `idx_commitment_contracts_status` ON commitment_contracts(status), `idx_commitment_signatures_contract_id` ON commitment_signatures(contract_id).
4. THE System SHALL add a migration file `002_commitment_form_signature.sql` containing the DDL statements for the two new tables and their indexes.
5. WHEN the migration is applied, THE System SHALL NOT modify any existing tables from migration `001_initial_schema.sql`.

---

### Requirement 9: Seguridad y Privacidad del Contrato

**User Story:** As a platform operator, I want contract data and signatures to be protected, so that sensitive personal information is not exposed to unauthorized parties.

#### Acceptance Criteria

1. THE Commitment_Service SHALL never include the `signature_data` field in list responses; it SHALL only be returned in single-contract detail and report endpoints.
2. THE API_Gateway SHALL enforce JWT authentication on all `/commitment/*` endpoints.
3. WHEN a user requests a contract or report, THE Commitment_Service SHALL verify that the `user_id` in the JWT matches the `user_id` of the requested Contract before returning data.
4. THE Commitment_Service SHALL sanitize all personal data fields (first_name, last_name, address, cedula, phone) to prevent XSS and SQL injection before persisting.
5. THE Commitment_Service SHALL record in `audit_logs` every access to a Contract_Report with the action `CONTRACT_REPORT_ACCESSED`, the contract_id, and the requesting user_id in the metadata.

---

### Requirement 10: Versionado de Cláusulas Legales

**User Story:** As a platform operator, I want to version the legal clauses, so that I can update the contract terms and know which version each user accepted.

#### Acceptance Criteria

1. THE Commitment_Service SHALL maintain a `contract_version` identifier (e.g., `"v1.0"`) embedded in the contract template returned by `GET /commitment/form`.
2. WHEN a Contract is created, THE Commitment_Service SHALL store the `contract_version` value from the template active at the time of signing.
3. WHEN the contract template is updated to a new version, THE Commitment_Service SHALL require users to re-sign if their existing Contract references a previous `contract_version`.
4. THE Commitment_Service SHALL expose the current `contract_version` in the response of `GET /commitment/status` so the App can determine if re-signing is required.
5. WHEN a user's Contract `contract_version` does not match the current active version, THE Commitment_Service SHALL return `{ "status": "outdated", "can_pull": false }` in the `GET /commitment/status` response.
