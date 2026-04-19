# Alcance del Panel Admin — Mobile vs Web

## Panel de administración completo (Web-only)

El panel de administración completo (Requisitos 9–16) está diseñado para uso **web/desktop** exclusivamente. Las siguientes funcionalidades **no están implementadas** en la app Flutter mobile:

- Gestión de usuarios (listar, activar/desactivar)
- Estadísticas del sistema (overview, actividad)
- Logs de errores y auditoría
- Configuración de tarifas
- CRUD de mensajes predefinidos
- Configuración de proveedores OAuth

## Funcionalidades admin implementadas en mobile

La app Flutter mobile implementa únicamente:

1. **Visualización de cuentas bancarias activas** (`GET /bank-accounts`)
   - Pantalla: `payments/presentation/bank_accounts_screen.dart`
   - Muestra banco, número de cuenta, titular y tipo de cuenta
   - Solo cuentas con `is_active = true`
   - _Requirements: 14.7_

2. **Manejo de cuenta desactivada en login**
   - Pantalla: `auth/presentation/login_screen.dart`
   - Detecta HTTP 403 con mensaje que contiene "desactivada"
   - Muestra mensaje específico: "Tu cuenta está desactivada. Contacta al administrador"
   - Distinto del error de credenciales inválidas (HTTP 401)
   - _Requirements: 10.7_
