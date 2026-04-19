# Implementation Plan: Commitment Form Signature

## Overview

Plan de implementación incremental para la feature de formulario de compromiso con firma digital. El flujo sigue la cadena de dependencias: migración SQL → backend (tipos, repositorio, servicios, controlador) → Flutter (DTOs, repositorio, servicio, pantallas, router). El contrato es válido por 30 días; el reporte se genera como JSON codificado en Base64 sin dependencias PDF externas.

Stack: Node.js + Express + TypeScript (backend), Flutter/Dart (mobile), PostgreSQL.

## Tasks

- [x] 1. Migración SQL 002 — Tablas de contratos y firmas
  - [x] 1.1 Crear archivo de migración `002_commitment_form_signature.sql`
    - Crear `backend/migrations/002_commitment_form_signature.sql`
    - Definir tabla `commitment_contracts` con columnas: id (UUID PK), user_id (FK → users), first_name, last_name, address, cedula, phone, checkbox_acceptance, contract_version, ip_address (INET), status (CHECK 'pending'|'signed'|'expired'), signed_at, created_at
    - Definir tabla `commitment_signatures` con columnas: id (UUID PK), contract_id (FK → commitment_contracts ON DELETE CASCADE), signature_data (TEXT), created_at
    - Crear índices: `idx_commitment_contracts_user_id` ON (user_id, signed_at DESC), `idx_commitment_contracts_cedula`, `idx_commitment_contracts_status`, `idx_commitment_signatures_contract_id`
    - Agregar `ALTER TABLE plays DROP CONSTRAINT plays_source_check, ADD CONSTRAINT plays_source_check CHECK (source IN ('generated','dream','pull_10'))`
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 2. Backend — Tipos TypeScript y DTOs
  - [x] 2.1 Extender `src/types/index.ts` con tipos de commitment
    - Agregar: `ContractStatus`, `CommitmentContract`, `CommitmentSignature`, `ContractStatusResponse`, `Pull10Result`
    - _Requirements: 3.3, 3.4, 4.7, 6.1_

  - [x] 2.2 Crear `src/dtos/commitment.dto.ts`
    - Definir interfaces: `SignContractDto`, `ContractFieldDef`, `ContractTemplateResponse`
    - Definir interface `ContractReportPayload` con campos: report_type, generated_at, contract, user_data, clauses, checkbox_acceptance, digital_signature
    - _Requirements: 1.3, 1.4, 3.1, 5.5, 5.6_

- [x] 3. Backend — Commitment Repository
  - [x] 3.1 Crear `src/repositories/commitment.repository.ts`
    - Implementar `createContract(dto, userId, ip, version)`: INSERT en `commitment_contracts`, retornar `{ id, signed_at }`
    - Implementar `createSignature(contractId, signatureData)`: INSERT en `commitment_signatures`
    - Implementar `findLatestByUser(userId)`: SELECT más reciente por `signed_at DESC` para el usuario
    - Implementar `findValidContract(userId, currentVersion)`: SELECT contrato con status='signed', signed_at dentro de 30 días y contract_version = currentVersion
    - Implementar `findById(contractId)`: SELECT contrato con su firma (JOIN commitment_signatures)
    - Implementar `listContracts(page, limit, search?)`: SELECT paginado con filtro ILIKE opcional en cedula, first_name, last_name; excluir signature_data
    - _Requirements: 3.3, 3.4, 3.7, 4.2, 6.2, 7.1, 7.2, 9.1_

  - [ ]* 3.2 Escribir property test para round-trip de contrato (Property 3)
    - **Property 3: Round-trip de creación de contrato**
    - Usar `fast-check`: `fc.record(...)` con datos válidos → crear contrato → recuperar de DB → assert todos los campos coinciden; assert firma en `commitment_signatures` con contract_id correcto
    - Tag: `// Feature: commitment-form-signature, Property 3`
    - **Validates: Requirements 3.2, 3.3, 3.4, 3.8**

- [x] 4. Backend — Commitment Service
  - [x] 4.1 Crear `src/services/commitment.service.ts` con cláusulas hardcoded y template
    - Definir `CURRENT_CONTRACT_VERSION = 'v1.0'` y `CLAUSES_V1` con el texto legal del 30 %
    - Implementar `getTemplate()`: retornar `ContractTemplateResponse` con fields y clauses
    - Implementar `getStatus(userId)`: llamar a `findLatestByUser`, evaluar ventana de 30 días y versión activa, retornar `ContractStatusResponse` con status 'none' | 'signed' | 'expired' | 'outdated'
    - _Requirements: 1.1, 1.3, 1.4, 1.5, 3.7, 3.8, 6.1, 6.2, 6.3, 6.4, 6.5, 10.1, 10.2, 10.4, 10.5_

  - [ ]* 4.2 Escribir property test para ventana de validez de 30 días (Property 5)
    - **Property 5: Ventana de validez de 30 días**
    - Usar `fast-check`: `fc.date()` dentro de los últimos 30 días → assert `can_pull = true`; `fc.date()` con más de 30 días → assert `can_pull = false, status = 'expired'`
    - Tag: `// Feature: commitment-form-signature, Property 5`
    - **Validates: Requirements 3.7, 6.4, 6.5**

  - [ ]* 4.3 Escribir property test para versionado de contrato (Property 13)
    - **Property 13: Versionado de contrato**
    - Usar `fast-check`: `fc.string()` distinto de `CURRENT_CONTRACT_VERSION` como contract_version → assert `status = 'outdated', can_pull = false`
    - Tag: `// Feature: commitment-form-signature, Property 13`
    - **Validates: Requirements 10.3, 10.5**

  - [ ]* 4.4 Escribir property test para contrato más reciente en status (Property 14)
    - **Property 14: Contrato más reciente en status**
    - Usar `fast-check`: N contratos con `fc.date()` distintos → assert que `getStatus` evalúa el de `signed_at` más reciente
    - Tag: `// Feature: commitment-form-signature, Property 14`
    - **Validates: Requirements 6.2**

  - [x] 4.5 Implementar `sign(dto, userId, ip)` en commitment.service.ts
    - Validar todos los campos del `SignContractDto` según reglas de Requirement 2 (first_name, last_name, address, cedula, phone, digital_signature, checkbox_acceptance)
    - Retornar HTTP 422 con lista de campos inválidos si alguno falla
    - Llamar a `createContract()` y `createSignature()` del repositorio
    - Registrar en `audit_logs` con `action = 'CONTRACT_SIGNED'` y `contract_id` en metadata
    - Retornar `{ contract_id, signed_at }`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 3.1, 3.2, 3.5, 3.6, 3.8, 9.4_

  - [ ]* 4.6 Escribir property test para validación de campos del formulario (Property 1)
    - **Property 1: Validación de campos del formulario**
    - Usar `fast-check`: `fc.string()` para cada campo con valores fuera de rango → assert HTTP 422 con lista de campos; valores dentro de rango → assert aceptación
    - Tag: `// Feature: commitment-form-signature, Property 1`
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6**

  - [ ]* 4.7 Escribir property test para validación de firma digital (Property 2)
    - **Property 2: Validación de firma digital**
    - Usar `fast-check`: `fc.base64String()` con tamaño decodificado < 1 KB → assert HTTP 422; tamaño ≥ 1 KB → assert aceptación
    - Tag: `// Feature: commitment-form-signature, Property 2`
    - **Validates: Requirements 2.7**

  - [x] 4.8 Implementar `generateReport(contractId, requestingUserId)` en commitment.service.ts
    - Verificar que el contrato pertenece al `requestingUserId`, retornar HTTP 403 si no
    - Retornar HTTP 404 si el contrato no existe
    - Construir `ContractReportPayload` con datos del contrato, cláusulas activas y firma digital
    - Codificar el payload como `Buffer.from(JSON.stringify(payload)).toString('base64')`
    - Registrar en `audit_logs` con `action = 'CONTRACT_REPORT_ACCESSED'`, contract_id y user_id en metadata
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 9.3, 9.5_

  - [ ]* 4.9 Escribir property test para completitud del reporte (Property 10)
    - **Property 10: Completitud del reporte de contrato**
    - Usar `fast-check`: generar contratos aleatorios → assert reporte decodificado contiene user_data, clauses, digital_signature, signed_at, contract_id
    - Tag: `// Feature: commitment-form-signature, Property 10`
    - **Validates: Requirements 5.5, 5.6**

  - [ ]* 4.10 Escribir property test para auditoría de creación (Property 4)
    - **Property 4: Auditoría de creación de contrato**
    - Usar `fast-check`: crear contrato → assert exactamente una entrada en `audit_logs` con `action = 'CONTRACT_SIGNED'` y contract_id en metadata
    - Tag: `// Feature: commitment-form-signature, Property 4`
    - **Validates: Requirements 3.6**

  - [ ]* 4.11 Escribir property test para auditoría de acceso a reporte (Property 12)
    - **Property 12: Auditoría de acceso a reporte**
    - Usar `fast-check`: acceder a reporte → assert exactamente una entrada en `audit_logs` con `action = 'CONTRACT_REPORT_ACCESSED'`, contract_id y user_id en metadata
    - Tag: `// Feature: commitment-form-signature, Property 12`
    - **Validates: Requirements 9.5**

- [x] 5. Backend — Pull Service
  - [x] 5.1 Crear `src/services/pull.service.ts`
    - Implementar `pull10(userId)`:
      - Llamar a `findValidContract(userId, CURRENT_CONTRACT_VERSION)` del repositorio
      - Retornar HTTP 403 con mensaje "Debes firmar el contrato de compromiso antes de solicitar el Pull de 10" si no hay contrato válido
      - Obtener frecuencias históricas con `getFrequencies()`
      - Llamar a `generateCombination('Loto', frequencies)` × 10 generando combinaciones únicas
      - Persistir cada combinación con `savePlay(userId, 'Loto', numbers, 'pull_10')`
      - Retornar `{ combinations, contract_id, timestamp }`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8_

  - [ ]* 5.2 Escribir property test para guard de acceso al Pull de 10 (Property 6)
    - **Property 6: Guard de acceso al Pull de 10**
    - Usar `fast-check`: estados de contrato (none, expired, outdated, valid) → assert HTTP 403 para todos excepto valid; assert HTTP 201 para valid
    - Tag: `// Feature: commitment-form-signature, Property 6`
    - **Validates: Requirements 4.2, 4.3**

  - [ ]* 5.3 Escribir property test para correctitud del Pull de 10 (Property 7)
    - **Property 7: Correctitud del Pull de 10**
    - Usar `fast-check`: frecuencias históricas aleatorias → assert 10 combinaciones únicas, cada una con 6 números únicos en [1,36], exactamente 3 pares y 3 impares, sin 3+ consecutivos
    - Tag: `// Feature: commitment-form-signature, Property 7`
    - **Validates: Requirements 4.4, 4.6**

  - [ ]* 5.4 Escribir property test para persistencia del Pull de 10 (Property 8)
    - **Property 8: Persistencia del Pull de 10**
    - Usar `fast-check`: generar pull-10 → assert exactamente 10 registros en `plays` con user_id correcto, play_type='Loto', source='pull_10', números coincidentes con la respuesta
    - Tag: `// Feature: commitment-form-signature, Property 8`
    - **Validates: Requirements 4.5**

- [x] 6. Backend — Commitment Controller y registro en app.ts
  - [x] 6.1 Crear `src/controllers/commitment.controller.ts`
    - Implementar handler `GET /commitment/form` → `commitmentService.getTemplate()`
    - Implementar handler `POST /commitment/sign` → `commitmentService.sign(dto, userId, ip)`
    - Implementar handler `GET /commitment/status` → `commitmentService.getStatus(userId)`
    - Implementar handler `GET /commitment/report/:contract_id` → `commitmentService.generateReport(contractId, userId)`
    - Implementar handler `POST /lottery/pull-10` → `pullService.pull10(userId)`
    - Proteger todos los handlers con `authMiddleware`
    - Exportar `commitmentRouter` y `pull10Router`
    - _Requirements: 1.1, 1.2, 3.1, 4.1, 5.1, 6.1, 9.2_

  - [x] 6.2 Agregar rutas admin de commitment en `src/controllers/admin.controller.ts`
    - Agregar handler `GET /admin/commitment/contracts` con paginación y búsqueda → `commitmentRepository.listContracts()`
    - Agregar handler `GET /admin/commitment/contracts/:id` → `commitmentRepository.findById()`
    - Agregar handler `GET /admin/commitment/contracts/:id/report` → `commitmentService.generateReport(contractId, adminUserId)` (sin verificación de ownership para admin)
    - Proteger con `authMiddleware` + `adminMiddleware`
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [ ]* 6.3 Escribir property test para autorización de acceso a contrato (Property 9)
    - **Property 9: Autorización de acceso a contrato**
    - Usar `fast-check`: pares (usuario_A, contrato de usuario_B) → assert HTTP 403 en GET /commitment/report/:id y GET /commitment/status para usuario_A
    - Tag: `// Feature: commitment-form-signature, Property 9`
    - **Validates: Requirements 5.2, 5.3, 9.3**

  - [ ]* 6.4 Escribir property test para exclusión de firma en lista admin (Property 11)
    - **Property 11: Exclusión de firma en respuestas de lista**
    - Usar `fast-check`: generar N contratos → GET /admin/commitment/contracts → assert ningún elemento contiene `signature_data`
    - Tag: `// Feature: commitment-form-signature, Property 11`
    - **Validates: Requirements 9.1**

  - [x] 6.5 Registrar routers en `src/app.ts`
    - Importar `commitmentRouter` y `pull10Router` desde `commitment.controller.ts`
    - Montar `app.use('/commitment', commitmentRouter)` y `app.use('/lottery', pull10Router)`
    - _Requirements: 1.1, 3.1, 4.1, 5.1, 6.1_

- [ ] 7. Checkpoint — Backend commitment completo
  - Verificar que todos los endpoints responden correctamente con DB activa: GET /commitment/form, POST /commitment/sign, GET /commitment/status, GET /commitment/report/:id, POST /lottery/pull-10.
  - Verificar que POST /lottery/request-number sigue funcionando sin contrato (no-regresión).
  - Asegurar que todos los tests pasen. Consultar al usuario si surgen dudas.

- [x] 8. Flutter — DTOs y modelos de commitment
  - [x] 8.1 Crear `flutter_app/lib/features/commitment/data/commitment_dto.dart`
    - Implementar clases con `fromJson`/`toJson`: `ContractTemplate`, `ContractFieldDef`, `ContractClause`, `SignContractRequest`, `ContractStatusResponse`, `Pull10Response`
    - _Requirements: 1.2, 1.3, 3.5, 4.7, 6.1_

- [x] 9. Flutter — Commitment Repository y Service
  - [x] 9.1 Crear `flutter_app/lib/features/commitment/data/commitment_repository.dart`
    - Implementar `getTemplate()`: GET /commitment/form via `ApiClient`
    - Implementar `sign(SignContractRequest)`: POST /commitment/sign
    - Implementar `getStatus()`: GET /commitment/status
    - Implementar `getReport(contractId)`: GET /commitment/report/:contract_id
    - Implementar `pull10()`: POST /lottery/pull-10
    - _Requirements: 1.1, 3.1, 4.1, 5.1, 6.1_

  - [x] 9.2 Crear `flutter_app/lib/features/commitment/domain/commitment_service.dart`
    - Implementar `checkStatus()`: llamar a `getStatus()`, retornar `ContractStatusResponse`
    - Implementar `submitForm(fields, signatureBase64, checkboxAccepted)`: validar campos en cliente, llamar a `sign()`
    - Implementar `requestPull10()`: llamar a `pull10()`, retornar `Pull10Response`
    - Manejar errores de red con timeout de 5 s y mensajes de SnackBar definidos en el diseño
    - _Requirements: 1.2, 2.1, 2.2, 2.3, 2.4, 2.5, 4.1, 4.3_

- [x] 10. Flutter — CommitmentFormScreen (formulario + canvas de firma)
  - [x] 10.1 Crear `flutter_app/lib/features/commitment/presentation/commitment_form_screen.dart`
    - Implementar campos de texto para first_name, last_name, address, cedula, phone con validación inline bajo cada campo
    - Implementar sección de cláusulas legales con texto scrollable mostrando `CLAUSES_V1`
    - Implementar canvas de firma digital con `CustomPainter` y `GestureDetector` para capturar trazos del dedo; botón "Limpiar firma"
    - Implementar checkbox de aceptación de cláusulas
    - Al presionar "Firmar y continuar": validar canvas no vacío (SnackBar "Por favor dibuja tu firma"), validar checkbox (SnackBar "Debes aceptar las cláusulas"), exportar canvas como PNG Base64 con `toImage()` + `toByteData()`
    - Llamar a `commitmentService.submitForm()` y navegar a `/pull-10` en caso de éxito
    - Aplicar tema Luxora (colores `LuxoraColors`, bordes redondeados, fondo `background`)
    - _Requirements: 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 2.4, 2.5, 2.7, 2.8, 2.9, 3.5_

- [x] 11. Flutter — Pull10Screen (pantalla de 10 combinaciones)
  - [x] 11.1 Crear `flutter_app/lib/features/commitment/presentation/pull10_screen.dart`
    - Al inicializar: llamar a `commitmentService.requestPull10()`; si retorna HTTP 403, navegar a `/commitment-form`
    - Mostrar 10 filas, cada una con 6 `_NumberBall` (reutilizar el widget existente de `lottery_screen.dart`)
    - Mostrar `contract_id` y timestamp del contrato usado
    - Mostrar indicador de carga mientras se generan las combinaciones
    - Manejar error de red con SnackBar y botón Reintentar
    - _Requirements: 4.1, 4.4, 4.7_

- [x] 12. Flutter — Actualizar router y LotteryScreen
  - [x] 12.1 Agregar rutas de commitment en `flutter_app/lib/core/router/app_router.dart`
    - Importar `CommitmentFormScreen` y `Pull10Screen`
    - Agregar `GoRoute(path: '/commitment-form', builder: ...)` y `GoRoute(path: '/pull-10', builder: ...)`
    - _Requirements: 1.2, 4.1_

  - [x] 12.2 Agregar entrada al Pull de 10 en `LotteryScreen`
    - Agregar botón o ítem de navegación "Pull de 10" en la barra de navegación inferior de `lottery_screen.dart`
    - Al presionar: llamar a `commitmentService.checkStatus()`; si `can_pull = true` navegar a `/pull-10`; si `can_pull = false` navegar a `/commitment-form`
    - _Requirements: 1.2, 4.2, 4.3, 4.8_

- [ ] 13. Checkpoint final — Flujo completo commitment
  - Verificar flujo completo: LotteryScreen → Pull de 10 → CommitmentFormScreen → firma → Pull10Screen con 10 combinaciones.
  - Verificar que contrato válido (< 30 días, versión activa) omite el formulario y va directo a Pull10Screen.
  - Verificar que las demás modalidades (Loto, Pale, Tripleta, Número) siguen funcionando sin contrato.
  - Asegurar que todos los tests pasen. Consultar al usuario si surgen dudas.

## Notes

- Las tareas marcadas con `*` son opcionales y pueden omitirse para un MVP más rápido
- Cada tarea referencia requisitos específicos para trazabilidad
- Los property tests usan `fast-check` con mínimo 100 iteraciones (`numRuns: 100`)
- El reporte se genera como JSON codificado en Base64 — sin librerías PDF externas
- El contrato es válido por 30 días; pasado ese plazo o con versión desactualizada se requiere re-firma
- Las 14 propiedades de corrección del design.md están cubiertas por los property tests opcionales de las tareas 3.2, 4.2–4.11, 5.2–5.4, 6.3–6.4
