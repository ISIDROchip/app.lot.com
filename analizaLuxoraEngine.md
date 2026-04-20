# Análisis del Motor Luxora — Arquitectura de Optimización Inteligente

Este documento detalla la lógica interna del motor de Luxora, que representa una evolución moderna del sistema LTFree, optimizado para alto rendimiento y mayor precisión estadística.

## 1. Filosofía del Motor
A diferencia de LTFree (que es reactivo y basado en filtros rígidos), **Luxora** es un motor **proactivo y basado en puntuación (scoring)**. En lugar de solo descartar lo que no cumple, busca activamente la combinación "perfecta" mediante un algoritmo de **Búsqueda por Torneo**.

## 2. Componentes Principales (`combinationOptimizer.ts`)

### A. Perfiles de Números (Dynamic Weighting)
Cada número del 1 al 40 recibe un peso dinámico calculado mediante:
*   **Z-Score**: Qué tan lejos está la frecuencia del número respecto a la media.
*   **Cycle Boost**: Un multiplicador de "urgencia" para números que llevan muchos sorteos sin salir (basado en `lot_number_cycles`).
*   **Hot Threshold**: Umbral dinámico para clasificar números calientes.

### B. Selección Guiada por Posición
Utiliza la tabla `lot_position_frequency` para identificar qué números tienen mayor probabilidad en cada una de las 6 posiciones. Esto reemplaza los rangos fijos de LTFree por **rangos basados en datos reales**.

### C. Selección por Torneo (Tournament Selection)
1.  Genera hasta **50 candidatos** (configurables) que cumplen las reglas básicas.
2.  Calcula un **Score Multi-Criterio** para cada uno.
3.  Elige el candidato con la puntuación más alta.

## 3. El Sistema de Scoring (Multi-Criterio)
El éxito de una combinación se mide por una suma ponderada de 5 factores:

| Factor | Descripción | Peso Típico |
| :--- | :--- | :--- |
| **Frecuencia** | Preferencia por números con buen historial (Z-Score). | 35% |
| **Dispersión** | Qué tan bien distribuidos están los números (Desviación Estándar). | 25% |
| **Diversidad** | Distancia de Hamming respecto al historial (evita repetir jugadas pasadas). | 25% |
| **Balance** | Cumplimiento estricto de paridad (3 pares / 3 impares) y bonos por pares frecuentes. | 10% |
| **Penalización** | Resta puntos por cada par de números consecutivos. | -5% |

## 4. Reglas Estructurales (Hard Constraints)
Incluso con scoring, Luxora mantiene filtros de seguridad infranqueables:
*   **Suma Total**: Entre 100 y 180.
*   **Pares Fijos**: Exactamente 3 pares y 3 impares.
*   **Consecutivos**: Prohibido más de 2 números seguidos.
*   **Regla de Mitades**: La suma de los 3 primeros debe ser menor a la de los 3 últimos (mantiene tendencia ascendente).
*   **Rango por Posición**: Filtro de seguridad para evitar números ilógicos (ej. un 40 en 1ra posición).

## 5. Ventajas sobre LTFree
1.  **Configurabilidad**: Los pesos del scoring se pueden ajustar desde la base de datos sin tocar el código.
2.  **Diversidad Proactiva**: El uso de la Distancia de Hamming asegura que las jugadas sugeridas no sean "más de lo mismo".
3.  **Memoria de Ciclos**: El "Cycle Boost" es una mejora crítica que prioriza números que "ya les toca salir", algo que LTFree trataba de forma manual.
4.  **Generación Pull-10**: Luxora puede generar bloques de 10 jugadas únicas que no se solapan entre sí, optimizando la cobertura del espacio muestral para el usuario.

## 6. Futuras Mejoras Identificadas
*   **Entrenamiento Continuo**: Integrar el feedback de sorteos reales para auto-ajustar los pesos de scoring mediante el servicio de AI.
*   **Análisis de Segmentos**: Incorporar el nuevo análisis de franjas (1-10, 11-20...) directamente en el generador de candidatos.
