-- Migration 003: Advanced Engine Tables
-- Tablas que alimentan el motor estadístico avanzado de generación de combinaciones.
-- Equivalente PostgreSQL de las tablas de LTFree (SQL Server).

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. lot_number_frequency
--    Equivalente a: lotResult (LTFree)
--    Propósito: frecuencia total de aparición de cada número en el historial.
--    Alimenta: buildProfiles() → z-score → pesos de selección
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE lot_number_frequency (
    number      SMALLINT    NOT NULL CHECK (number >= 1 AND number <= 40),
    frequency   INTEGER     NOT NULL DEFAULT 0,
    last_seen   DATE,                          -- último sorteo donde apareció
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (number)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. lot_number_cycles
--    Nueva tabla (no existe en LTFree — mejora pendiente sección 11.1)
--    Propósito: rastrear cuántos sorteos han pasado desde que cada número
--    apareció por última vez ("ciclo de ausencia").
--    Alimenta: factor de boost para números "vencidos"
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE lot_number_cycles (
    number              SMALLINT    NOT NULL CHECK (number >= 1 AND number <= 40),
    draws_since_last    INTEGER     NOT NULL DEFAULT 0,  -- sorteos sin aparecer
    total_draws         INTEGER     NOT NULL DEFAULT 0,  -- total de sorteos analizados
    avg_cycle           NUMERIC(6,2),                    -- ciclo promedio de aparición
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (number)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. lot_pair_frequency
--    Nueva tabla (no existe en LTFree — mejora pendiente sección 11.2)
--    Propósito: frecuencia de co-aparición de pares de números.
--    Alimenta: análisis de pares frecuentes en el motor
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE lot_pair_frequency (
    number_a    SMALLINT    NOT NULL CHECK (number_a >= 1 AND number_a <= 40),
    number_b    SMALLINT    NOT NULL CHECK (number_b >= 1 AND number_b <= 40),
    frequency   INTEGER     NOT NULL DEFAULT 0,  -- veces que aparecieron juntos
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (number_a, number_b),
    CHECK (number_a < number_b)  -- evitar duplicados (a,b) y (b,a)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. lot_position_frequency
--    Nueva tabla (no existe en LTFree — mejora pendiente sección 11.3)
--    Propósito: frecuencia de aparición de cada número en cada posición
--    (posición 1-6 en la combinación ordenada ASC).
--    Alimenta: selección guiada por posición en el motor
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE lot_position_frequency (
    position    SMALLINT    NOT NULL CHECK (position >= 1 AND position <= 6),
    number      SMALLINT    NOT NULL CHECK (number >= 1 AND number <= 40),
    frequency   INTEGER     NOT NULL DEFAULT 0,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (position, number)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. lot_generated_combinations
--    Equivalente a: gt3 (LTFree)
--    Propósito: almacenar combinaciones generadas con sus métricas de calidad.
--    Alimenta: análisis de coincidencias, scoring histórico
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE lot_generated_combinations (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID        REFERENCES users(id) ON DELETE SET NULL,
    number1             SMALLINT    NOT NULL,
    number2             SMALLINT    NOT NULL,
    number3             SMALLINT    NOT NULL,
    number4             SMALLINT    NOT NULL,
    number5             SMALLINT    NOT NULL,
    number6             SMALLINT    NOT NULL,
    evens               SMALLINT    NOT NULL,   -- cantidad de pares
    odds                SMALLINT    NOT NULL,   -- cantidad de impares
    highs               SMALLINT    NOT NULL,   -- números > 20
    lows                SMALLINT    NOT NULL,   -- números <= 20
    total_sum           SMALLINT    NOT NULL,   -- suma total
    score               NUMERIC(8,2),           -- puntuación del motor
    coincidences        INTEGER     NOT NULL DEFAULT 0,  -- coincidencias con historial
    combination_str     VARCHAR(30) NOT NULL,   -- "n1,n2,n3,n4,n5,n6"
    source              VARCHAR(20) NOT NULL DEFAULT 'engine'
                            CHECK (source IN ('engine','pull_10','manual')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. lot_combination_analysis
--    Equivalente a: AnalisisCombinaciones (LTFree)
--    Propósito: resultado de comparar combinaciones generadas contra el historial.
--    Alimenta: scoring de diversidad (distancia de Hamming)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE lot_combination_analysis (
    id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    combination_principal   VARCHAR(30) NOT NULL,  -- combinación generada
    combination_compared    VARCHAR(30) NOT NULL,  -- combinación histórica
    coincidences            SMALLINT    NOT NULL,  -- números en común
    hamming_distance        SMALLINT    NOT NULL,  -- 6 - coincidences
    analyzed_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. lot_coincidence_results
--    Equivalente a: ResultadosCoincidencias (LTFree)
--    Propósito: combinaciones con ≥3 coincidencias contra una jugada saliente.
--    Alimenta: validación de calidad del motor
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE lot_coincidence_results (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    number1             SMALLINT,
    number2             SMALLINT,
    number3             SMALLINT,
    number4             SMALLINT,
    number5             SMALLINT,
    number6             SMALLINT,
    total_coincidences  SMALLINT    NOT NULL,
    winning_draw        VARCHAR(30) NOT NULL,   -- jugada saliente comparada
    analyzed_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. lot_engine_config
--    Nueva tabla — configuración dinámica del motor
--    Propósito: permitir ajustar los pesos del scoring sin redeployar
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE lot_engine_config (
    key         VARCHAR(60)     PRIMARY KEY,
    value       NUMERIC(8,4)    NOT NULL,
    description TEXT,
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- Valores por defecto de los pesos del scoring (deben coincidir con DEFAULT_WEIGHTS en combinationOptimizer.ts)
INSERT INTO lot_engine_config (key, value, description) VALUES
    ('weight_frequency',   0.35, 'Peso del factor de frecuencia histórica'),
    ('weight_dispersion',  0.25, 'Peso del factor de dispersión estadística'),
    ('weight_diversity',   0.25, 'Peso del factor de diversidad (distancia de Hamming)'),
    ('weight_balance',     0.10, 'Peso del factor de balance par/impar'),
    ('weight_consecutive', 0.05, 'Peso de la penalización por consecutivos'),
    ('tournament_size',    50,   'Número de candidatos en el torneo de selección'),
    ('hot_threshold_multiplier', 1.0, 'Multiplicador del umbral caliente/frío (1.0 = media)'),
    ('cycle_boost_factor', 0.15, 'Factor de boost para números vencidos (ciclos)');

-- ─────────────────────────────────────────────────────────────────────────────
-- ÍNDICES
-- ─────────────────────────────────────────────────────────────────────────────

CREATE INDEX idx_lot_number_frequency_freq
    ON lot_number_frequency(frequency DESC);

CREATE INDEX idx_lot_number_cycles_draws
    ON lot_number_cycles(draws_since_last DESC);

CREATE INDEX idx_lot_pair_frequency_freq
    ON lot_pair_frequency(frequency DESC);

CREATE INDEX idx_lot_position_frequency_pos_freq
    ON lot_position_frequency(position, frequency DESC);

CREATE INDEX idx_lot_generated_combinations_user
    ON lot_generated_combinations(user_id, created_at DESC);

CREATE INDEX idx_lot_generated_combinations_score
    ON lot_generated_combinations(score DESC);

CREATE INDEX idx_lot_generated_combinations_str
    ON lot_generated_combinations(combination_str);

CREATE INDEX idx_lot_combination_analysis_principal
    ON lot_combination_analysis(combination_principal);

CREATE INDEX idx_lot_coincidence_results_coincidences
    ON lot_coincidence_results(total_coincidences DESC);
