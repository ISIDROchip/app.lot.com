# Design Document — Commitment Form Signature

## Overview

La feature **Commitment Form Signature** agrega un flujo de contrato legal al Pull de 10 combinaciones de Luxora Smart Lottery App. Antes de recibir 10 combinaciones Loto optimizadas, el usuario debe completar un formulario con sus datos personales, dibujar su firma digital con el dedo y aceptar las cláusulas legales que lo comprometen a pagar el 30 % de cualquier ganancia obtenida con esas combinaciones.

El contrato firmado es válido por 30 días. Pasado ese plazo, o si el usuario acepta una versión de cláusulas diferente a la activa, debe re-firmar. Las demás modalidades de juego (Loto, Pale, Tripleta, Número individual) permanecen sin cambios y no requieren contrato.

### Principios de diseño

- **Contrato como prerequisito**: el Pull de 10 es un endpoint separado que verifica la existencia de un contrato válido antes de generar combinaciones.
- **Reporte sin dependencias externas**: el Contract_Report se genera como JSON estructurado codificado en Base64, sin librerías PDF externas.
- **Cláusulas hardcoded v1.0**: el texto legal está embebido en el servicio; el versionado permite actualizaciones futuras sin migración de datos.
- **Consistencia con el diseño existente**: se reutilizan los patrones de repositorio, middleware y auditoría ya establecidos en el proyecto.

---

## Architecture

### Diagrama de flujo — Pull de 10

```
Flutter (CommitmentScreen)
  │
  ├─ GET /commitment/status  ──► CommitmentController
  │                                └─ CommitmentService.getStatus(userId)
  │                                     └─ CommitmentRepository.findLatestByUser()
  │
  ├─ GET /commitment/form    ──► CommitmentController
  │                                └─ CommitmentService.getTemplate()
  │                                     └─ CLAUSES_V1 (hardcoded)
  │
  ├─ POST /commitment/sign   ──► CommitmentController
  │                                └─ CommitmentService.sign(dto, userId, ip)
  │                                     ├─ validate(dto)
  │                                     ├─ CommitmentRepository.createContract()
  │                                     ├─ CommitmentRepository.createSignature()
  │                                     └─ auditLog(CONTRACT_SIGNED)
  │
  └─ POST /lottery/pull-10   ──► CommitmentController (pull)
                                   └─ PullService.pull10(userId)
                                        ├─ CommitmentRepository.findValidContract()
                                        │    └─ 403 si no existe
                                        ├─ generateCombination() × 10
                                        └─ LotteryRepository.savePlay() × 10 (source='pull_10')
```

### Integración con el sistema existente

| Componente existente | Uso en esta feature |
|---|---|
| `authMiddleware` | Protege todos los endpoints `/commitment/*` y `/lottery/pull-10` |
| `adminMiddleware` | Protege endpoints `/admin/commitment/*` |
| `combinationOptimizer.ts` | Reutilizado por `PullService` para generar las 10 combinaciones |
| `lottery.repository.ts` → `savePlay()` | Almacena cada una de las 10 jugadas con `source = 'pull_10'` |
| `audit_logs` table | Registra `CONTRACT_SIGNED` y `CONTRACT_REPORT_ACCESSED` |
| `sanitize` middleware | Sanitiza los campos del formulario antes de llegar al controlador |
| `pool` (pg) | Acceso a PostgreSQL desde los nuevos repositorios |

---

## Components and Interfaces

### Estructura de archivos nuevos

```
backend/
├── src/
│   ├── controllers/
│   │   └── commitment.controller.ts   # Endpoints commitment + pull-10
│   ├── services/
│   │   ├── commitment.service.ts      # Lógica de negocio, validación, reporte
│   │   └── pull.service.ts            # Genera 10 combinaciones con guard de contrato
│   ├── repositories/
│   │   └── commitment.repository.ts   # CRUD commitment_contracts + commitment_signatures
│   └── dtos/
│       └── commitment.dto.ts          # SignContractDto, ContractStatusDto
├── migrations/
│   └── 002_commitment_form_signature.sql

flutter_app/
└── lib/
    └── features/
        └── commitment/
            ├── data/
            │   ├── commitment_repository.dart
            │   └── commitment_dto.dart
            ├── domain/
            │   └── commitment_service.dart
            └── presentation/
                ├── commitment_form_screen.dart   # Formulario + canvas firma
                └── pull10_screen.dart            # Pantalla con 10 bolas
```

### Contratos de API

#### Commitment

```
GET /commitment/form                              [authMiddleware]
200: {
  contract_version: "v1.0",
  fields: [
    { name: "first_name",  label: "Nombre",    type: "text",   required: true },
    { name: "last_name",   label: "Apellido",  type: "text",   required: true },
    { name: "address",     label: "Dirección", type: "text",   required: true },
    { name: "cedula",      label: "Cédula",    type: "text",   required: true },
    { name: "phone",       label: "Teléfono",  type: "phone",  required: true }
  ],
  clauses: [
    { id: "c1", version: "v1.0", text: "..." }
  ]
}

POST /commitment/sign                             [authMiddleware]
Body: {
  first_name: string,
  last_name: string,
  address: string,
  cedula: string,
  phone: string,
  digital_signature: string,   // Base64 PNG
  checkbox_acceptance: boolean
}
201: { contract_id: string, signed_at: string }
422: { error: string, fields: { field: string, message: string }[] }

GET /commitment/status                            [authMiddleware]
200 (sin contrato):  { status: "none",     can_pull: false }
200 (válido):        { status: "signed",   can_pull: true,  contract_id: string, signed_at: string, contract_version: string }
200 (expirado):      { status: "expired",  can_pull: false, contract_version: string }
200 (desactualizado):{ status: "outdated", can_pull: false, contract_version: string }

GET /commitment/report/:contract_id               [authMiddleware]
200: { report: string }   // Base64-encoded JSON
403: { error: "No tienes permiso para acceder a este contrato" }
404: { error: "Contrato no encontrado" }

POST /lottery/pull-10                             [authMiddleware]
201: {
  combinations: number[][],   // 10 arrays de 6 números
  contract_id: string,
  timestamp: string
}
403: { error: "Debes firmar el contrato de compromiso antes de solicitar el Pull de 10" }
```

#### Admin — Commitment

```
GET /admin/commitment/contracts                   [adminMiddleware]
Query: ?page=1&limit=20&search=string
200: { data: ContractRecord[], total: number, page: number, limit: number }

GET /admin/commitment/contracts/:id               [adminMiddleware]
200: { id, user_id, first_name, last_name, address, cedula, phone,
       checkbox_acceptance, contract_version, status, signed_at, created_at,
       signature: { id, signature_data, created_at } }
404: { error: "Contrato no encontrado" }

GET /admin/commitment/contracts/:id/report        [adminMiddleware]
200: { report: string }   // Base64-encoded JSON
404: { error: "Contrato no encontrado" }
```

### Cláusulas legales hardcoded v1.0

```typescript
// commitment.service.ts — CLAUSES_V1
export const CURRENT_CONTRACT_VERSION = 'v1.0';

export const CLAUSES_V1 = [
  {
    id: 'c1',
    version: 'v1.0',
    text: `El usuario se compromete irrevocablemente a pagar el treinta por ciento (30 %) 
del monto neto de cualquier premio obtenido mediante las combinaciones generadas 
en el Pull de 10 de Luxora Smart Lottery. Este compromiso aplica a cada combinación 
individualmente y al conjunto de combinaciones del Pull. El pago deberá realizarse 
dentro de los cinco (5) días hábiles siguientes a la fecha de cobro del premio, 
mediante transferencia a las cuentas bancarias oficiales de Luxora indicadas en la 
aplicación. El incumplimiento de este compromiso podrá resultar en la suspensión 
del acceso al servicio Pull de 10.`,
  },
];
```

### Generación del Contract_Report (Base64 JSON)

El reporte no usa librerías PDF externas. Se genera un objeto JSON estructurado y se codifica en Base64:

```typescript
interface ContractReportPayload {
  report_type: 'commitment_contract';
  generated_at: string;           // ISO 8601
  contract: {
    id: string;
    contract_version: string;
    status: string;
    signed_at: string;
    ip_address: string | null;
  };
  user_data: {
    first_name: string;
    last_name: string;
    address: string;
    cedula: string;
    phone: string;
  };
  clauses: Array<{ id: string; version: string; text: string }>;
  checkbox_acceptance: boolean;
  digital_signature: string;      // Base64 PNG
}

// Generación:
const payload: ContractReportPayload = { ... };
const report = Buffer.from(JSON.stringify(payload)).toString('base64');
```

---

## Data Models

### Migración SQL — 002_commitment_form_signature.sql

```sql
-- Tabla: commitment_contracts
CREATE TABLE commitment_contracts (
    id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    first_name        VARCHAR(60)  NOT NULL,
    last_name         VARCHAR(60)  NOT NULL,
    address           VARCHAR(255) NOT NULL,
    cedula            VARCHAR(20)  NOT NULL,
    phone             VARCHAR(15)  NOT NULL,
    checkbox_acceptance BOOLEAN    NOT NULL,
    contract_version  VARCHAR(20)  NOT NULL,
    ip_address        INET,
    status            VARCHAR(20)  NOT NULL DEFAULT 'signed'
                          CHECK (status IN ('pending','signed','expired')),
    signed_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Tabla: commitment_signatures
CREATE TABLE commitment_signatures (
    id              UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id     UUID  NOT NULL REFERENCES commitment_contracts(id) ON DELETE CASCADE,
    signature_data  TEXT  NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_commitment_contracts_user_id
    ON commitment_contracts(user_id, signed_at DESC);
CREATE INDEX idx_commitment_contracts_cedula
    ON commitment_contracts(cedula);
CREATE INDEX idx_commitment_contracts_status
    ON commitment_contracts(status);
CREATE INDEX idx_commitment_signatures_contract_id
    ON commitment_signatures(contract_id);

-- Actualizar CHECK de source en plays para incluir 'pull_10'
ALTER TABLE plays
    DROP CONSTRAINT plays_source_check,
    ADD CONSTRAINT plays_source_check
        CHECK (source IN ('generated','dream','pull_10'));
```

### Tipos TypeScript nuevos

```typescript
// Añadir a src/types/index.ts

export type ContractStatus = 'none' | 'signed' | 'expired' | 'outdated';

export interface CommitmentContract {
  id: string;
  user_id: string;
  first_name: string;
  last_name: string;
  address: string;
  cedula: string;
  phone: string;
  checkbox_acceptance: boolean;
  contract_version: string;
  ip_address: string | null;
  status: 'pending' | 'signed' | 'expired';
  signed_at: string;
  created_at: string;
}

export interface CommitmentSignature {
  id: string;
  contract_id: string;
  signature_data: string;
  created_at: string;
}

export interface ContractStatusResponse {
  status: ContractStatus;
  can_pull: boolean;
  contract_id?: string;
  signed_at?: string;
  contract_version?: string;
}

export interface Pull10Result {
  combinations: number[][];
  contract_id: string;
  timestamp: string;
}
```

### DTOs — commitment.dto.ts

```typescript
export interface SignContractDto {
  first_name: string;
  last_name: string;
  address: string;
  cedula: string;
  phone: string;
  digital_signature: string;
  checkbox_acceptance: boolean;
}

export interface ContractFieldDef {
  name: string;
  label: string;
  type: 'text' | 'phone';
  required: boolean;
}

export interface ContractTemplateResponse {
  contract_version: string;
  fields: ContractFieldDef[];
  clauses: Array<{ id: string; version: string; text: string }>;
}
```

### Modelos Flutter

```dart
// commitment_dto.dart

class ContractTemplate {
  final String contractVersion;
  final List<ContractFieldDef> fields;
  final List<ContractClause> clauses;
  // fromJson factory
}

class SignContractRequest {
  final String firstName;
  final String lastName;
  final String address;
  final String cedula;
  final String phone;
  final String digitalSignature;   // Base64 PNG
  final bool checkboxAcceptance;
  // toJson()
}

class ContractStatusResponse {
  final String status;             // none | signed | expired | outdated
  final bool canPull;
  final String? contractId;
  final String? signedAt;
  final String? contractVersion;
  // fromJson factory
}

class Pull10Response {
  final List<List<int>> combinations;
  final String contractId;
  final String timestamp;
  // fromJson factory
}
```

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — esencialmente, una declaración formal sobre lo que el sistema debe hacer. Las propiedades sirven como puente entre las especificaciones legibles por humanos y las garantías de corrección verificables por máquina.*

### Reflexión de propiedades (eliminación de redundancia)

Antes de listar las propiedades finales se revisaron los candidatos del prework:

- Las propiedades de validación de campos (2.1, 2.2, 2.3, 2.4, 2.5) son reglas independientes sobre distintos campos — se mantienen separadas pero se consolidan en una sola propiedad de validación de formulario completo.
- La propiedad 2.6 (respuesta 422 con lista de campos) es consecuencia directa de 2.1-2.5 — se consolida.
- Las propiedades 3.2, 3.3, 3.4 (creación y almacenamiento) se consolidan en una sola propiedad de round-trip de contrato.
- Las propiedades 6.4 y 6.5 (30 días válido / expirado) son complementarias y se consolidan en una sola propiedad de ventana de validez.
- Las propiedades 10.3 y 10.5 (versión desactualizada) son la misma propiedad expresada de dos formas — se consolidan.
- Las propiedades 5.2 y 9.3 (autorización por user_id) son la misma regla aplicada a dos endpoints — se consolidan en una propiedad de autorización de contrato.

---

### Property 1: Validación de campos del formulario

*For any* combinación de valores para los campos `first_name`, `last_name`, `address`, `cedula` y `phone`, el Commitment_Service SHALL aceptar únicamente los valores que cumplan todas las reglas de formato simultáneamente, y SHALL rechazar con HTTP 422 listando cada campo inválido cuando al menos uno no cumpla su regla.

Reglas: `first_name` y `last_name` en [2,60] chars alfabéticos con acentos y espacios; `address` en [10,255] chars; `cedula` en [6,20] alfanumérico; `phone` en [8,15] dígitos numéricos.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6**

---

### Property 2: Validación de firma digital

*For any* cadena presentada como `digital_signature`, el Commitment_Service SHALL aceptarla únicamente si es una cadena Base64 válida cuyo contenido decodificado tiene un tamaño mínimo de 1 KB, y SHALL rechazar con HTTP 422 cualquier cadena que no cumpla esta condición.

**Validates: Requirements 2.7**

---

### Property 3: Round-trip de creación de contrato

*For any* conjunto válido de datos de formulario y firma digital, al crear un contrato mediante `POST /commitment/sign` y luego recuperarlo de la base de datos, todos los campos almacenados (first_name, last_name, address, cedula, phone, checkbox_acceptance, contract_version, status, signed_at) SHALL coincidir exactamente con los valores enviados, y la firma digital SHALL estar almacenada en `commitment_signatures` con el `contract_id` correcto.

**Validates: Requirements 3.2, 3.3, 3.4, 3.8**

---

### Property 4: Auditoría de creación de contrato

*For any* creación exitosa de contrato, el sistema SHALL insertar exactamente una entrada en `audit_logs` con `action = 'CONTRACT_SIGNED'` y el `contract_id` en el campo `metadata`, asociada al `user_id` del usuario autenticado.

**Validates: Requirements 3.6**

---

### Property 5: Ventana de validez de 30 días

*For any* contrato con `status = 'signed'` y un `signed_at` arbitrario, el Commitment_Service SHALL determinar `can_pull = true` si y solo si `NOW() - signed_at < 30 días`, y SHALL determinar `can_pull = false` con `status = 'expired'` en caso contrario.

**Validates: Requirements 3.7, 6.4, 6.5**

---

### Property 6: Guard de acceso al Pull de 10

*For any* estado de usuario (sin contrato, contrato expirado, contrato con versión desactualizada, contrato válido), el Pull_Service SHALL permitir la generación únicamente cuando el usuario tiene un contrato con `status = 'signed'`, `contract_version` igual a la versión activa, y `signed_at` dentro de los últimos 30 días; en cualquier otro caso SHALL retornar HTTP 403.

**Validates: Requirements 4.2, 4.3**

---

### Property 7: Correctitud del Pull de 10

*For any* usuario con contrato válido y cualquier conjunto de datos de frecuencias históricas, el Pull_Service SHALL generar exactamente 10 combinaciones únicas de tipo Loto, donde cada combinación contiene exactamente 6 números únicos en el rango [1,36], con exactamente 3 pares y 3 impares, y sin 3 o más números consecutivos.

**Validates: Requirements 4.4, 4.6**

---

### Property 8: Persistencia del Pull de 10

*For any* generación exitosa de Pull de 10, el sistema SHALL almacenar exactamente 10 registros en la tabla `plays` con `user_id` del usuario autenticado, `play_type = 'Loto'`, y `source = 'pull_10'`, y los números de cada registro SHALL coincidir con los retornados en la respuesta.

**Validates: Requirements 4.5**

---

### Property 9: Autorización de acceso a contrato

*For any* par (usuario_A, contrato perteneciente a usuario_B) donde usuario_A ≠ usuario_B, cualquier intento de usuario_A de acceder al contrato o su reporte SHALL retornar HTTP 403, independientemente del contract_id utilizado.

**Validates: Requirements 5.2, 5.3, 9.3**

---

### Property 10: Completitud del reporte de contrato

*For any* contrato válido, el reporte generado por `GET /commitment/report/:contract_id` SHALL ser una cadena Base64 que al decodificarse produce un JSON válido conteniendo: datos personales del usuario, todas las cláusulas con su versión, la imagen de firma digital, el `signed_at`, y el `contract_id`.

**Validates: Requirements 5.5, 5.6**

---

### Property 11: Exclusión de firma en respuestas de lista

*For any* respuesta del endpoint `GET /admin/commitment/contracts`, ningún elemento del array `data` SHALL contener el campo `signature_data` ni ninguna referencia a la firma digital.

**Validates: Requirements 9.1**

---

### Property 12: Auditoría de acceso a reporte

*For any* acceso exitoso a un reporte de contrato mediante `GET /commitment/report/:contract_id`, el sistema SHALL insertar exactamente una entrada en `audit_logs` con `action = 'CONTRACT_REPORT_ACCESSED'`, el `contract_id` y el `user_id` del solicitante en `metadata`.

**Validates: Requirements 9.5**

---

### Property 13: Versionado de contrato

*For any* contrato cuyo `contract_version` difiera de la versión activa actual (`CURRENT_CONTRACT_VERSION`), el endpoint `GET /commitment/status` SHALL retornar `{ "status": "outdated", "can_pull": false }`, independientemente de la fecha de firma.

**Validates: Requirements 10.3, 10.5**

---

### Property 14: Contrato más reciente en status

*For any* usuario con N contratos firmados en distintos momentos, el endpoint `GET /commitment/status` SHALL evaluar el contrato con el `signed_at` más reciente para determinar el estado, ignorando los contratos anteriores.

**Validates: Requirements 6.2**

---

## Error Handling

### Errores del backend

| Situación | HTTP | Cuerpo |
|---|---|---|
| Campo de formulario inválido | 422 | `{ error: "Validación fallida", fields: [{ field, message }] }` |
| `checkbox_acceptance` = false | 422 | `{ error: "Debes aceptar las cláusulas del contrato para continuar" }` |
| Sin contrato válido para pull-10 | 403 | `{ error: "Debes firmar el contrato de compromiso antes de solicitar el Pull de 10" }` |
| Contrato no pertenece al usuario | 403 | `{ error: "No tienes permiso para acceder a este contrato" }` |
| Contrato no encontrado | 404 | `{ error: "Contrato no encontrado" }` |
| Error interno al generar reporte | 500 | Manejado por `errorHandler` global |
| JWT ausente o inválido | 401 | Manejado por `authMiddleware` existente |

### Errores del Flutter

| Situación | Comportamiento UI |
|---|---|
| Campos inválidos | Mostrar error inline bajo cada campo |
| Canvas de firma vacío | Mostrar SnackBar: "Por favor dibuja tu firma" |
| Checkbox no marcado | Mostrar SnackBar: "Debes aceptar las cláusulas" |
| Error de red | Mostrar SnackBar con mensaje de error y botón Reintentar |
| 403 en pull-10 | Navegar a CommitmentFormScreen |
| Timeout (>5s) | Mostrar SnackBar: "Tiempo de espera agotado. Intenta de nuevo" |

---

## Testing Strategy

### Enfoque dual

Se utilizan dos tipos de pruebas complementarias:

- **Unit tests**: verifican ejemplos concretos, casos límite y condiciones de error.
- **Property-based tests**: verifican propiedades universales sobre rangos amplios de entradas.

### Librería PBT

Se utiliza **fast-check** (npm) para el backend TypeScript. Cada property test se configura con mínimo 100 iteraciones.

```typescript
// Ejemplo de configuración
fc.assert(fc.property(arb, (input) => { ... }), { numRuns: 100 });
```

### Mapeo de propiedades a tests

| Property | Tipo de test | Descripción |
|---|---|---|
| Property 1 | PBT | `fc.string()` para cada campo, verificar aceptación/rechazo |
| Property 2 | PBT | `fc.base64String()` de tamaños variables, verificar validación |
| Property 3 | PBT | `fc.record(...)` con datos válidos, crear y recuperar contrato |
| Property 4 | PBT | Crear contrato, verificar entrada en audit_logs |
| Property 5 | PBT | `fc.date()` dentro/fuera de 30 días, verificar can_pull |
| Property 6 | PBT | Generar estados de contrato aleatorios, verificar guard |
| Property 7 | PBT | Generar frecuencias aleatorias, verificar 10 combinaciones válidas |
| Property 8 | PBT | Generar pull-10, verificar 10 plays en DB con source='pull_10' |
| Property 9 | PBT | Generar pares usuario/contrato, verificar autorización |
| Property 10 | PBT | Generar contratos aleatorios, verificar completitud del reporte |
| Property 11 | PBT | Generar lista de contratos, verificar ausencia de signature_data |
| Property 12 | PBT | Acceder a reporte, verificar entrada en audit_logs |
| Property 13 | PBT | Generar versiones de contrato, verificar detección de outdated |
| Property 14 | PBT | Generar N contratos con timestamps aleatorios, verificar más reciente |

### Tag format para property tests

```typescript
// Feature: commitment-form-signature, Property 1: Validación de campos del formulario
// Feature: commitment-form-signature, Property 5: Ventana de validez de 30 días
```

### Unit tests adicionales

- Smoke tests para cada endpoint (JWT requerido, estructura de respuesta).
- Tests de integración para los endpoints admin con datos de ejemplo.
- Test de no-regresión: los endpoints `/lottery/request-number` siguen funcionando sin contrato.
- Test de sanitización: payloads con XSS/SQLi son rechazados por el middleware existente.

### Tests Flutter

- Widget tests para `CommitmentFormScreen`: validación inline de campos, estado del canvas, estado del checkbox.
- Widget test para `Pull10Screen`: renderizado de 10 bolas con números correctos.
- Integration test del flujo completo: status → form → sign → pull-10.
