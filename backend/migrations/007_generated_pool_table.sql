-- 007_generated_pool_table.sql
-- Tabla para almacenar el lote masivo de combinaciones pre-generadas (Pool)

CREATE TABLE IF NOT EXISTS lot_pool_combinations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lottery_id UUID REFERENCES lotteries(id) ON DELETE CASCADE,
    numbers INTEGER[] NOT NULL,
    score DOUBLE PRECISION NOT NULL,
    is_delivered BOOLEAN DEFAULT FALSE,
    delivered_to UUID REFERENCES users(id) ON DELETE SET NULL,
    delivered_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB -- Para guardar detalles del scoring (z-score, sum, etc)
);

-- Índices para búsqueda rápida de jugadas no entregadas con mayor puntuación
CREATE INDEX idx_pool_undelivered_score ON lot_pool_combinations (score DESC) WHERE is_delivered = FALSE;
CREATE INDEX idx_pool_lottery ON lot_pool_combinations (lottery_id);

-- Añadir límite de pulls a la tabla de usuarios si no existe (opcional, podemos consultarlo en tiempo real)
ALTER TABLE users ADD COLUMN IF NOT EXISTS max_pulls INTEGER DEFAULT 15;
