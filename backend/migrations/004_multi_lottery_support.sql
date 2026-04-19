-- Migration 004: Multi-Lottery Support
-- Agrega soporte para múltiples loterías en el sistema.
-- Todas las tablas de resultados, análisis y jugadas se asocian a una lotería específica.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. lotteries — catálogo de loterías disponibles
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE lotteries (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(100) NOT NULL,           -- ej: "Loto Más", "Leidsa", "Nacional"
    short_name      VARCHAR(30)  NOT NULL UNIQUE,    -- ej: "loto_mas", "leidsa", "nacional"
    country         VARCHAR(60)  NOT NULL DEFAULT 'República Dominicana',
    numbers_count   SMALLINT     NOT NULL DEFAULT 6, -- cuántos números por jugada
    number_range    SMALLINT     NOT NULL DEFAULT 40,-- rango máximo [1, number_range]
    draw_days       SMALLINT[]   NOT NULL DEFAULT '{3,6}', -- días de sorteo (0=Dom..6=Sab)
    scraper_url     VARCHAR(500),                    -- URL base para el scraper
    is_active       BOOLEAN      NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Loterías dominicanas predefinidas
INSERT INTO lotteries (name, short_name, numbers_count, number_range, draw_days, scraper_url) VALUES
    ('Loto Más',        'loto_mas',     6, 40, '{3,6}',
     'https://loteriasdominicanas.com/leidsa/loto-mas'),
    ('Loto Real',       'loto_real',    6, 32, '{0,3,6}',
     'https://loteriasdominicanas.com/loteria-real/loto-real'),
    ('Super Kino TV',   'super_kino',   5, 30, '{1,2,3,4,5}',
     'https://loteriasdominicanas.com/leidsa/super-kino-tv'),
    ('Quiniela Pale',   'quiniela_pale',2, 100, '{1,2,3,4,5,6,0}',
     'https://loteriasdominicanas.com/loteria-nacional/quiniela-pale'),
    ('Lotería Nacional','lot_nacional',  6, 38, '{0,3,6}',
     'https://loteriasdominicanas.com/loteria-nacional');

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Agregar lottery_id a historical_results
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE historical_results
    ADD COLUMN lottery_id UUID REFERENCES lotteries(id) ON DELETE SET NULL;

CREATE INDEX idx_historical_results_lottery_id
    ON historical_results(lottery_id, draw_date DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Agregar lottery_id a plays
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE plays
    ADD COLUMN lottery_id UUID REFERENCES lotteries(id) ON DELETE SET NULL;

CREATE INDEX idx_plays_lottery_id
    ON plays(lottery_id, user_id, created_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Agregar lottery_id a las tablas del motor avanzado
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE lot_number_frequency
    ADD COLUMN lottery_id UUID REFERENCES lotteries(id) ON DELETE CASCADE;

ALTER TABLE lot_number_cycles
    ADD COLUMN lottery_id UUID REFERENCES lotteries(id) ON DELETE CASCADE;

ALTER TABLE lot_pair_frequency
    ADD COLUMN lottery_id UUID REFERENCES lotteries(id) ON DELETE CASCADE;

ALTER TABLE lot_position_frequency
    ADD COLUMN lottery_id UUID REFERENCES lotteries(id) ON DELETE CASCADE;

ALTER TABLE lot_generated_combinations
    ADD COLUMN lottery_id UUID REFERENCES lotteries(id) ON DELETE SET NULL;

-- Actualizar PKs de las tablas del motor para incluir lottery_id
ALTER TABLE lot_number_frequency  DROP CONSTRAINT lot_number_frequency_pkey;
ALTER TABLE lot_number_frequency  ADD PRIMARY KEY (lottery_id, number);

ALTER TABLE lot_number_cycles     DROP CONSTRAINT lot_number_cycles_pkey;
ALTER TABLE lot_number_cycles     ADD PRIMARY KEY (lottery_id, number);

ALTER TABLE lot_pair_frequency    DROP CONSTRAINT lot_pair_frequency_pkey;
ALTER TABLE lot_pair_frequency    ADD PRIMARY KEY (lottery_id, number_a, number_b);

ALTER TABLE lot_position_frequency DROP CONSTRAINT lot_position_frequency_pkey;
ALTER TABLE lot_position_frequency ADD PRIMARY KEY (lottery_id, position, number);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Agregar lottery_id a dream_interpretations
--    (los sueños pueden interpretarse para una lotería específica)
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE dream_interpretations
    ADD COLUMN lottery_id UUID REFERENCES lotteries(id) ON DELETE SET NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Índices adicionales
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX idx_lotteries_short_name ON lotteries(short_name);
CREATE INDEX idx_lotteries_is_active  ON lotteries(is_active);
