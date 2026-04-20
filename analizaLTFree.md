# Análisis de Proyecto LTFree — Motor de Inteligencia de Lotería

Este documento detalla el análisis técnico de la carpeta `LTFree`, que contiene el núcleo lógico original (en C#) sobre el cual se basa el motor de optimización de combinaciones de Luxora.

## 1. Descripción General
**LTFree** es una aplicación de consola desarrollada en .NET 6 que utiliza análisis estadístico avanzado, simulación Monte Carlo y Machine Learning (ML.NET) para generar combinaciones "inteligentes" de lotería basadas en resultados históricos almacenados en SQL Server.

## 2. Estructura del Proyecto
*   **Program.cs**: Orquestador principal. Gestiona el flujo de: limpieza de datos -> cálculo de frecuencias -> clasificación de números -> generación de combinaciones -> filtrado por reglas -> persistencia en base de datos.
*   **DataLoader.cs**: Capa de acceso a datos para leer los sorteos históricos.
*   **LotEstadisticas.cs**: Implementa los cálculos matemáticos de Media, Mediana, Moda y Desviación Estándar.
*   **Estadistica/LotoPredictor.cs**: Módulo de IA que utiliza regresión SDCA para predecir la frecuencia de aparición de números.
*   **database.sql**: Contiene la definición de tablas y procedimientos almacenados (SQL Server).

## 3. Lógica de Negocio y Reglas de Oro
El corazón de LTFree es el método `CumpleRestricciones()`, que valida que cada jugada generada sea estadísticamente probable.

### Restricciones Técnicas (Filtros):
| Filtro | Valor / Lógica |
| :--- | :--- |
| **Suma Total** | La suma de los 6 números debe estar entre **100 y 170**. |
| **Consecutivos** | Máximo **2 números consecutivos** (ej. 10, 11 es válido; 10, 11, 12 NO). |
| **Rangos por Posición** | Cada posición (1ra a 6ta) tiene un rango específico (ej. Pos1: 1-20, Pos6: 22-40). |
| **Sumas Parciales** | Sumas de pares de números (1+2, 3+4, 5+6) deben caer en rangos específicos. |
| **Decenios** | Máximo 3 números por cada bloque de decenios definidos. |
| **Simetría** | La suma de los 3 primeros números debe ser menor que la de los 3 últimos. |

### Estrategia de Selección:
1.  **Clasificación**: Separa los números en **Calientes** (Frecuencia > 8) y **Fríos** (Frecuencia <= 8).
2.  **Composición**: Por defecto intenta mezclar **2 números pares** y **4 impares**.
3.  **Probabilidad Ponderada**: Usa el *Z-Score* para darle más peso a los números que están cerca de la desviación estándar ideal.

## 4. Base de Datos (SQL Server)
*   **Tablas de Resultados**: `Resultados` (histórico) y `lotResult` (frecuencias).
*   **Tablas de Análisis**: 
    *   `gt3`: Almacena las combinaciones generadas con su puntuación.
    *   `CumplenConReglas`: Tabla final con las jugadas que pasaron todos los filtros.
*   **Procedimientos Almacenados**: `AnalizarCombinaciones` y `ObtenerCoincidencias` utilizan cursores para comparar jugadas generadas contra el historial masivo.

## 5. Módulo de IA (ML.NET)
*   Utiliza un algoritmo de **Regresión Estocástica (SDCA)**.
*   Intenta predecir la "fuerza" de un número basado en su comportamiento histórico.
*   *Observación*: El código original tiene una nota indicando que solo usa 1 "feature" (el número), lo cual es una oportunidad de mejora para Luxora usando múltiples variables.

## 6. Conclusiones para la Integración en Luxora
El motor de Luxora ya ha portado gran parte de estas reglas al entorno **Node.js/TypeScript** (`combinationOptimizer.ts`), pero existen oportunidades adicionales:
1.  **Migración de Procedimientos**: Los análisis de coincidencias masivas pueden optimizarse en PostgreSQL.
2.  **IA Potenciada**: Sustituir el modelo básico de ML.NET por el servicio de Python + OpenAI ya integrado en Luxora para una predicción más semántica y de patrones complejos.
3.  **Visualización**: Las métricas de scoring de LTFree pueden exponerse en el frontend de Flutter para dar transparencia al usuario sobre por qué se eligieron esos números.
