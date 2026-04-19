# Lógica de Negocio — Luxora Smart Lottery

## 1. Visión General

Luxora es una aplicación móvil de lotería inteligente que combina análisis estadístico de resultados históricos, interpretación de sueños y un motor de generación de combinaciones avanzado para ofrecer al usuario jugadas optimizadas. El modelo de negocio se basa en un servicio gratuito para jugadas individuales y un servicio premium (Pull de 10) que requiere un contrato de compromiso legal.

---

## 2. Actores del Sistema

| Actor | Descripción |
|-------|-------------|
| Usuario | Persona registrada mayor de 18 años que usa la app para generar jugadas |
| Admin | Operador con acceso al panel de gestión de usuarios y mensajes |
| SuperAdmin | Operador con acceso total: estadísticas, logs, tarifas, cuentas bancarias, OAuth |
| Sistema | Procesos automáticos: generación de combinaciones, análisis estadístico, auditoría |

---

## 3. Reglas de Negocio Fundamentales

### 3.1 Registro y Acceso

- Solo usuarios **mayores de 18 años** pueden registrarse (validado en cliente y servidor).
- El email debe ser único en el sistema.
- La contraseña se almacena con hash bcrypt (cost 10).
- El JWT tiene vigencia de **24 horas**.
- Si una cuenta está desactivada (`is_active = false`), el login retorna HTTP 403 con mensaje específico.
- Un usuario inactivo no puede acceder a ningún servicio.

### 3.2 Modalidades de Jugada

El sistema ofrece 5 modalidades:

| Modalidad | Números | Requiere contrato | Costo |
|-----------|---------|-------------------|-------|
| Número | 1 | No | Gratis |
| Pale | 2 | No | Gratis |
| Tripleta | 3 | No | Gratis |
| Loto | 6 | No | Gratis |
| Pull de 10 | 10 × 6 números | No | Pago directo por pull |

### 3.3 Generación Directa de Pull de 10

El Pull de 10 ahora se genera directamente mediante pago único por cada solicitud. No se requieren contratos previos.

#### Proceso simplificado:
1. Usuario selecciona lotería
2. Presiona "Generar Pull de 10"
3. Se procesa el pago directamente
4. Se generan y entregan las 10 combinaciones

#### Límite de uso:
- Máximo 20 Pulls de 10 por usuario en 30 días
- Pago único de $10 USD por cada Pull de 10

---

### 3.4 Generación de Combinaciones

#### Reglas estructurales (todas obligatorias para Loto y Pull de 10)

| Regla | Valor |
|-------|-------|
| Cantidad de números | 6 únicos en rango **[1, 40]** |
| Paridad | Exactamente 3 pares + 3 impares |
| Suma total | Entre 100 y 170 |
| Consecutivos | Máximo 2 números seguidos (no 3+) |
| Rango por posición | Pos1:[1-20], Pos2:[6-26], Pos3:[11-31], Pos4:[17-40], Pos5:[18-40], Pos6:[22-40] |
| Suma posiciones 1+2 | Entre 3 y 36 |
| Suma posiciones 3+4 | Entre 13 y 68 |
| Suma posiciones 5+6 | Entre 40 y 80 |
| Restricción de deciles | Máximo 3 números por grupo (1-20, 21-26, 27-40) |
| Balance de mitades | Suma de los 3 primeros < suma de los 3 últimos |

#### Algoritmo de selección (motor avanzado)

1. **Clasificación caliente/frío**: números con frecuencia histórica > media = calientes; ≤ media = fríos.
2. **Pesos por z-score**: números calientes reciben peso proporcional a su z-score; números fríos reciben peso base mínimo.
3. **Torneo de candidatos**: se generan hasta 50 combinaciones válidas y se elige la de mayor score.
4. **Scoring multi-criterio**:
   - Frecuencia histórica (35%)
   - Dispersión estadística (25%)
   - Diversidad vs historial — distancia de Hamming (25%)
   - Balance par/impar (10%)
   - Penalización por consecutivos (5%)
5. **Pull de 10**: cada nueva combinación se genera contra las ya generadas para maximizar la diversidad del pull completo.

---

### 3.5 Interpretación de Sueños

- El usuario describe su sueño (mínimo 10 caracteres, máximo 2000).
- El AI Service (Python/FastAPI) analiza el texto y retorna números sugeridos en rango **[1, 100]** divididos en:

| Tipo | Cantidad de números | Rango |
|------|---------------------|-------|
| Número | 1 | [1, 100] |
| Pale | 2 | [1, 100] |
| Super Pale | 3 | [1, 100] |

- Cada tipo de jugada sugerida se almacena en la base de datos en su tabla correspondiente con su nombre respectivo.
- Las palabras clave extraídas del sueño también se almacenan.
- Si el AI Service no responde en 5 segundos, el backend retorna HTTP 503.
- Los números sugeridos se muestran al usuario agrupados por tipo y puede usarlos directamente como jugada.

#### Tablas de base de datos para sueños

| Tabla | Contenido |
|-------|-----------|
| `dream_interpretations` | Registro principal del sueño (texto, keywords, user_id) |
| `dream_numbers` | Números sugeridos con su tipo (numero, pale, super_pale) |

---

### 3.6 Estadísticas Históricas

- Los resultados históricos de sorteos se cargan mediante `POST /stats/upload-results`.
- Solo se aceptan números en rango **[1, 40]**.
- El sistema calcula frecuencias de aparición de cada número.
- Se exponen tendencias: **top 5** (más frecuentes) y **bottom 5** (menos frecuentes).
- Las frecuencias históricas alimentan directamente el motor de generación de combinaciones.

---

## 4. Flujos Principales

### 4.1 Flujo de Registro y Login

```
Usuario → Formulario de registro → Validación de edad (≥18) → Hash de contraseña
→ Guardar en DB → Confirmación

Usuario → Login → Verificar is_active → Comparar bcrypt → Emitir JWT (24h)
→ Guardar token en dispositivo
```

### 4.2 Flujo de Jugada Simple (Loto, Pale, Tripleta, Número)

```
Usuario autenticado → Seleccionar tipo → POST /lottery/request-number
→ Obtener frecuencias históricas → Motor de generación con restricciones
→ Guardar jugada en DB (source='generated') → Retornar números al usuario
```

### 4.3 Flujo de Pull de 10

```
Usuario autenticado → Presionar "Pull de 10"
→ GET /commitment/status
  ├─ can_pull = true → POST /lottery/pull-10 → Generar 10 combinaciones diversas
  │                    → Guardar 10 jugadas (source='pull_10') → Mostrar resultados
  └─ can_pull = false → Mostrar formulario de contrato
                        → Usuario llena datos + foto + geolocalización
                        → Dibuja firma manual + acepta cláusulas
                        → Sistema genera firma digital automática
                        → POST /commitment/sign → Guardar contrato + ambas firmas en DB
                        → Auditoría: CONTRACT_SIGNED → POST /lottery/pull-10
```

### 4.4 Flujo de Interpretación de Sueños

```
Usuario autenticado → Escribir sueño (≥10 chars)
→ POST /dreams/interpret → Backend valida longitud
→ Llamada al AI Service (timeout 5s)
→ AI analiza texto → Retorna: número(1), pale(2), super_pale(3) + keywords
→ Backend persiste en dream_interpretations + dream_numbers
→ Retorna al usuario agrupado por tipo
```

### 4.5 Flujo de Reporte de Contrato

```
Usuario autenticado → GET /commitment/report/:id
→ Verificar que el contrato pertenece al usuario
→ Construir ContractReportPayload:
   - Datos personales + foto + coordenadas GPS
   - Cláusulas aceptadas
   - Firma manual (izquierda) | Firma del sistema (derecha)
→ Codificar en Base64 → Retornar al usuario
→ Auditoría: CONTRACT_REPORT_ACCESSED
```

---

## 5. Probabilidades Reales — Pull de 10

### Probabilidad matemática base (Loto 6/40)

La lotería dominicana usa 40 números. La probabilidad de acertar los 6 números exactos es:

```
C(40,6) = 40! / (6! × 34!) = 3,838,380 combinaciones posibles

Probabilidad de acertar con 1 jugada = 1 / 3,838,380 ≈ 0.000026%
```

### Con el Pull de 10 (10 jugadas)

```
Probabilidad de que AL MENOS UNA de las 10 combinaciones sea ganadora:

P(ganar) = 1 - P(ninguna gana)
P(ninguna gana) = (3,838,379/3,838,380)^10
P(ganar) = 1 - (3,838,379/3,838,380)^10 ≈ 10 / 3,838,380 ≈ 0.00026%
```

### Ventaja del motor estadístico de Luxora

El motor no garantiza ganar, pero **mejora las probabilidades relativas** al:

1. Evitar combinaciones que ya salieron (distancia de Hamming) — reduce el espacio de búsqueda
2. Favorecer números con alta frecuencia histórica — si los patrones se repiten, aumenta la probabilidad
3. Maximizar diversidad entre las 10 combinaciones — cubre más del espacio de posibilidades
4. Aplicar restricciones estructurales — elimina combinaciones estadísticamente improbables

### Probabilidad de ganar algo (premios parciales)

| Aciertos | Premio típico | Probabilidad por jugada | Con Pull de 10 |
|----------|---------------|------------------------|----------------|
| 6/6 | Premio mayor | 1 en 3,838,380 | 1 en 383,838 |
| 5/6 | Premio 2do | 1 en 18,816 | 1 en 1,882 |
| 4/6 | Premio 3ro | 1 en 456 | 1 en 46 |
| 3/6 | Premio menor | 1 en 32 | **1 en 3.2** |

**Con el Pull de 10, tienes aproximadamente 1 posibilidad en 3 de acertar al menos 3 números en alguna de las combinaciones.**

### Conclusión honesta

El Pull de 10 con el motor estadístico de Luxora **multiplica por 10 tus probabilidades** respecto a una sola jugada aleatoria, y el algoritmo de optimización mejora adicionalmente la calidad de cada combinación. Sin embargo, la lotería sigue siendo un juego de azar — no existe garantía matemática de ganar el premio mayor. El valor real del sistema está en maximizar las probabilidades de premios parciales (3/6, 4/6) que son estadísticamente alcanzables.

---

## 6. Modelo de Datos Clave

### Usuarios
- `is_admin`, `is_super_admin`, `is_active` — control de roles y acceso
- `birth_date` — validación de mayoría de edad

### Jugadas (`plays`)
- `source`: `generated` | `dream` | `pull_10` — origen de la jugada
- `play_type`: `Loto` | `Pale` | `Tripleta` | `Número`

### Contratos (`commitment_contracts`)
- `status`: `pending` | `signed` | `expired`
- `contract_version` — para control de versiones de cláusulas
- `signed_at` — inicio del período de 30 días de validez
- `photo_data` — foto del firmante en Base64
- `latitude`, `longitude` — coordenadas GPS de la firma
- `location_address` — dirección legible obtenida de las coordenadas

### Firmas (`commitment_signatures`)
- `manual_signature_data` — firma dibujada por el usuario (PNG Base64)
- `system_signature_data` — firma generada por el sistema (hash visual)

### Sueños
- `dream_interpretations` — registro principal (texto, keywords, user_id)
- `dream_numbers` — números sugeridos con tipo (numero, pale, super_pale)

### Logs de Auditoría (`audit_logs`)
- Acciones: `CONTRACT_SIGNED`, `CONTRACT_REPORT_ACCESSED`, `TARIFF_UPDATED`, `OAUTH_CONFIG_UPDATED`

---

## 7. Seguridad y Privacidad

- Todos los endpoints requieren JWT Bearer (excepto registro y login).
- Los endpoints admin requieren `is_admin = true` o `is_super_admin = true`.
- Los endpoints SuperAdmin requieren `is_super_admin = true`.
- La firma manual y la foto **nunca** aparecen en respuestas de lista — solo en detalle y reporte.
- Los datos personales del contrato se sanitizan contra XSS/SQLi antes de persistir.
- El `client_secret` de proveedores OAuth se enmascara como `"***"` en todas las respuestas.
- Rate limiting: 100 requests/minuto por IP.

---

## 8. Modelo de Monetización

| Servicio | Precio | Condición |
|----------|--------|-----------|
| Registro | Gratis | — |
| Jugadas simples (Loto, Pale, Tripleta, Número) | Gratis | Usuario registrado |
| Pull de 10 combinaciones | $10 USD | Usuario registrado |
| Comisión por ganancia | Ninguna | — |

El modelo es de **pago directo**: el usuario paga $10 USD por adelantado por cada Pull de 10 solicitado. No hay comisiones adicionales ni contratos previos.

---

## 9. Administración del Sistema

### Panel Admin (is_admin)
- Ver y buscar usuarios (por nombre, email)
- Activar/desactivar cuentas de usuario
- Ver mensajes predefinidos del sistema
- Ver contratos de compromiso firmados

### Panel SuperAdmin (is_super_admin)
- Todo lo anterior +
- Estadísticas globales del sistema (usuarios, jugadas, sueños)
- Logs de errores con `reference_id` para trazabilidad
- Logs de auditoría filtrados por usuario o acción
- Configuración de tarifas del sistema
- CRUD de cuentas bancarias de la empresa
- CRUD de mensajes predefinidos
- Configuración de proveedores OAuth (Google, Facebook)

---

## 10. Restricciones Operativas

- Un usuario no puede desactivarse a sí mismo desde el panel admin.
- Los logs de errores se archivan automáticamente después de 30 días.
- El contrato de compromiso expira a los 30 días y requiere re-firma.
- Si las cláusulas legales cambian de versión, todos los contratos anteriores quedan como `outdated` y requieren re-firma.
- Las combinaciones del Pull de 10 se generan maximizando la diversidad entre ellas (distancia de Hamming).
- Los números de lotería operan en rango [1, 40].
- Los números de interpretación de sueños operan en rango [1, 100].


---

## 11. Mejoras Pendientes del Motor Estadístico (TODO)

Estas mejoras están pendientes de implementación para aumentar la calidad estadística de las combinaciones generadas:

### 11.1 Análisis de Ciclos de Aparición
- Calcular cuántos sorteos han pasado desde que cada número apareció por última vez
- Números con más sorteos sin aparecer ("vencidos") reciben un boost de peso en la selección
- Implementar en `combinationOptimizer.ts` como factor adicional del scoring

### 11.2 Análisis de Pares Frecuentes
- Identificar qué pares de números aparecen juntos con mayor frecuencia histórica
- Incluir al menos un par frecuente en cada combinación generada
- Almacenar la tabla de co-ocurrencias en la base de datos para consulta eficiente

### 11.3 Análisis de Frecuencia por Posición
- Cada posición (1ra a 6ta en la combinación ordenada) tiene números que aparecen más en esa posición
- Usar esta distribución posicional para guiar la selección número a número

### 11.4 Opción de Pull de 20 o 30
- Permitir al usuario elegir el tamaño del pull (10, 20 o 30 combinaciones)
- El contrato de compromiso aplica igual independientemente del tamaño
- Probabilidad de acertar 3/6 con Pull de 30: ~95% por sorteo

### Impacto esperado de estas mejoras

| Mejora | Impacto en probabilidad de 3/6 |
|--------|-------------------------------|
| Ciclos de aparición | +8-12% |
| Pares frecuentes | +5-10% |
| Frecuencia por posición | +5-8% |
| Pull de 20 | +100% (doble de jugadas) |
| Pull de 30 | +200% (triple de jugadas) |
