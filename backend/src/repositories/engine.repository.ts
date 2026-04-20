/**
 * engine.repository.ts
 *
 * Acceso a las tablas del motor avanzado (migración 003).
 * Equivalente a los procedimientos almacenados de LTFree pero en PostgreSQL.
 */

import { pool } from '../config/database';

// ─────────────────────────────────────────────────────────────────────────────
// TYPES
// ─────────────────────────────────────────────────────────────────────────────

export interface NumberFrequency {
  number: number;
  frequency: number;
  lastSeen: string | null;
}

export interface NumberCycle {
  number: number;
  drawsSinceLast: number;
  totalDraws: number;
  avgCycle: number | null;
}

export interface PairFrequency {
  numberA: number;
  numberB: number;
  frequency: number;
}

export interface PositionFrequency {
  position: number;
  number: number;
  frequency: number;
}

export interface EngineConfig {
  weightFrequency: number;
  weightDispersion: number;
  weightDiversity: number;
  weightBalance: number;
  weightConsecutive: number;
  tournamentSize: number;
  hotThresholdMultiplier: number;
  cycleBoostFactor: number;
}

// ─────────────────────────────────────────────────────────────────────────────
// READ — datos que alimentan el motor
// ─────────────────────────────────────────────────────────────────────────────

export async function getNumberFrequencies(lotteryId?: string): Promise<NumberFrequency[]> {
  const { rows } = await pool.query<{ number: string; frequency: string; last_seen: string | null }>(
    `SELECT number, frequency, last_seen
     FROM lot_number_frequency
     WHERE ($1::UUID IS NULL AND lottery_id IS NULL) OR lottery_id = $1
     ORDER BY frequency DESC, number ASC`,
    [lotteryId ?? null],
  );
  return rows.map(r => ({
    number: parseInt(r.number, 10),
    frequency: parseInt(r.frequency, 10),
    lastSeen: r.last_seen,
  }));
}

export async function getNumberCycles(lotteryId?: string): Promise<NumberCycle[]> {
  const { rows } = await pool.query<{
    number: string;
    draws_since_last: string;
    total_draws: string;
    avg_cycle: string | null;
  }>(
    `SELECT number, draws_since_last, total_draws, avg_cycle
     FROM lot_number_cycles
     WHERE ($1::UUID IS NULL AND lottery_id IS NULL) OR lottery_id = $1
     ORDER BY draws_since_last DESC`,
    [lotteryId ?? null],
  );
  return rows.map(r => ({
    number: parseInt(r.number, 10),
    drawsSinceLast: parseInt(r.draws_since_last, 10),
    totalDraws: parseInt(r.total_draws, 10),
    avgCycle: r.avg_cycle ? parseFloat(r.avg_cycle) : null,
  }));
}

export async function getTopPairs(limit = 20, lotteryId?: string): Promise<PairFrequency[]> {
  const { rows } = await pool.query<{ number_a: string; number_b: string; frequency: string }>(
    `SELECT number_a, number_b, frequency
     FROM lot_pair_frequency
     WHERE ($2::UUID IS NULL AND lottery_id IS NULL) OR lottery_id = $2
     ORDER BY frequency DESC
     LIMIT $1`,
    [limit, lotteryId ?? null],
  );
  return rows.map(r => ({
    numberA: parseInt(r.number_a, 10),
    numberB: parseInt(r.number_b, 10),
    frequency: parseInt(r.frequency, 10),
  }));
}

export async function getPositionFrequencies(lotteryId?: string): Promise<PositionFrequency[]> {
  const { rows } = await pool.query<{ position: string; number: string; frequency: string }>(
    `SELECT position, number, frequency
     FROM lot_position_frequency
     WHERE ($1::UUID IS NULL AND lottery_id IS NULL) OR lottery_id = $1
     ORDER BY position ASC, frequency DESC`,
    [lotteryId ?? null],
  );
  return rows.map(r => ({
    position: parseInt(r.position, 10),
    number: parseInt(r.number, 10),
    frequency: parseInt(r.frequency, 10),
  }));
}

export async function getEngineConfig(): Promise<EngineConfig> {
  const { rows } = await pool.query<{ key: string; value: string }>(
    `SELECT key, value FROM lot_engine_config`,
  );
  const cfg = Object.fromEntries(rows.map(r => [r.key, parseFloat(r.value)]));
  return {
    weightFrequency:        cfg['weight_frequency']          ?? 0.35,
    weightDispersion:       cfg['weight_dispersion']         ?? 0.25,
    weightDiversity:        cfg['weight_diversity']          ?? 0.25,
    weightBalance:          cfg['weight_balance']            ?? 0.10,
    weightConsecutive:      cfg['weight_consecutive']        ?? 0.05,
    tournamentSize:         cfg['tournament_size']           ?? 50,
    hotThresholdMultiplier: cfg['hot_threshold_multiplier']  ?? 1.0,
    cycleBoostFactor:       cfg['cycle_boost_factor']        ?? 0.15,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// WRITE — sincronización al subir resultados históricos
// Equivalente a los procedimientos AnalizarCombinaciones y ObtenerCoincidencias de LTFree
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Sincroniza todas las tablas del motor a partir de los resultados históricos.
 * Se llama cada vez que se suben nuevos resultados con POST /stats/upload-results.
 * Equivalente a ejecutar todos los SPs de LTFree en secuencia.
 */
export async function syncEngineTablesFromHistory(lotteryId?: string): Promise<void> {
  const client = await pool.connect();
  // Filter by lottery if provided
  const lotteryFilter = lotteryId ? `AND hr.lottery_id = '${lotteryId}'` : `AND hr.lottery_id IS NULL`;
  const lotteryValue = lotteryId ?? null;

  try {
    await client.query('BEGIN');

    // 1. Recalcular lot_number_frequency desde historical_results
    await client.query(`
      INSERT INTO lot_number_frequency (lottery_id, number, frequency, last_seen, updated_at)
      SELECT
        hr.lottery_id,
        n::SMALLINT                                    AS number,
        COUNT(*)::INTEGER                              AS frequency,
        MAX(hr.draw_date)                              AS last_seen,
        NOW()                                          AS updated_at
      FROM historical_results hr, UNNEST(hr.numbers) AS n
      WHERE ($1::UUID IS NULL AND hr.lottery_id IS NULL) OR hr.lottery_id = $1
      GROUP BY hr.lottery_id, n
      ON CONFLICT (lottery_id, number) DO UPDATE
        SET frequency  = EXCLUDED.frequency,
            last_seen  = EXCLUDED.last_seen,
            updated_at = NOW()
    `, [lotteryValue]);

    // 2. Recalcular lot_number_cycles
    await client.query(`
      WITH total AS (
        SELECT lottery_id, COUNT(*) AS total_draws
        FROM historical_results
        WHERE ($1::UUID IS NULL AND lottery_id IS NULL) OR lottery_id = $1
        GROUP BY lottery_id
      ),
      last_appearance AS (
        SELECT
          hr.lottery_id,
          n::SMALLINT AS number,
          ROW_NUMBER() OVER (PARTITION BY hr.lottery_id, n ORDER BY hr.draw_date DESC) AS rn,
          ROW_NUMBER() OVER (PARTITION BY hr.lottery_id ORDER BY hr.draw_date DESC) AS draw_rank
        FROM historical_results hr, UNNEST(hr.numbers) AS n
        WHERE ($1::UUID IS NULL AND hr.lottery_id IS NULL) OR hr.lottery_id = $1
      ),
      cycle_data AS (
        SELECT
          la.lottery_id,
          la.number,
          MIN(la.draw_rank) - 1                        AS draws_since_last,
          t.total_draws::INTEGER                        AS total_draws,
          AVG(la.draw_rank) FILTER (WHERE la.rn <= 10) AS avg_cycle
        FROM last_appearance la
        JOIN total t ON t.lottery_id IS NOT DISTINCT FROM la.lottery_id
        GROUP BY la.lottery_id, la.number, t.total_draws
      )
      INSERT INTO lot_number_cycles (lottery_id, number, draws_since_last, total_draws, avg_cycle, updated_at)
      SELECT lottery_id, number, draws_since_last::INTEGER, total_draws,
             ROUND(avg_cycle::NUMERIC, 2), NOW()
      FROM cycle_data
      ON CONFLICT (lottery_id, number) DO UPDATE
        SET draws_since_last = EXCLUDED.draws_since_last,
            total_draws      = EXCLUDED.total_draws,
            avg_cycle        = EXCLUDED.avg_cycle,
            updated_at       = NOW()
    `, [lotteryValue]);

    // 3. Recalcular lot_pair_frequency
    await client.query(`
      INSERT INTO lot_pair_frequency (lottery_id, number_a, number_b, frequency, updated_at)
      SELECT
        hr.lottery_id,
        LEAST(a.n, b.n)::SMALLINT    AS number_a,
        GREATEST(a.n, b.n)::SMALLINT AS number_b,
        COUNT(*)::INTEGER             AS frequency,
        NOW()                         AS updated_at
      FROM historical_results hr
      JOIN LATERAL UNNEST(hr.numbers) AS a(n) ON TRUE
      JOIN LATERAL UNNEST(hr.numbers) AS b(n) ON a.n < b.n
      WHERE ($1::UUID IS NULL AND hr.lottery_id IS NULL) OR hr.lottery_id = $1
      GROUP BY hr.lottery_id, LEAST(a.n, b.n), GREATEST(a.n, b.n)
      ON CONFLICT (lottery_id, number_a, number_b) DO UPDATE
        SET frequency  = EXCLUDED.frequency,
            updated_at = NOW()
    `, [lotteryValue]);

    // 4. Recalcular lot_position_frequency
    await client.query(`
      INSERT INTO lot_position_frequency (lottery_id, position, number, frequency, updated_at)
      SELECT
        pos.lottery_id,
        pos.position::SMALLINT,
        pos.number::SMALLINT,
        COUNT(*)::INTEGER AS frequency,
        NOW()
      FROM (
        SELECT
          hr.lottery_id,
          ROW_NUMBER() OVER (PARTITION BY hr.id ORDER BY n ASC) AS position,
          n AS number
        FROM historical_results hr, UNNEST(hr.numbers) AS n
        WHERE ($1::UUID IS NULL AND hr.lottery_id IS NULL) OR hr.lottery_id = $1
      ) pos
      GROUP BY pos.lottery_id, pos.position, pos.number
      ON CONFLICT (lottery_id, position, number) DO UPDATE
        SET frequency  = EXCLUDED.frequency,
            updated_at = NOW()
    `, [lotteryValue]);

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Guarda una combinación generada con sus métricas.
 * Equivalente a InsertarResultadosAsync de LTFree.
 */
export async function saveGeneratedCombination(
  numbers: number[],
  score: number,
  coincidences: number,
  userId: string | null,
  source: 'engine' | 'pull_10' | 'manual' = 'engine',
): Promise<void> {
  const sorted = [...numbers].sort((a, b) => a - b);
  const evens = sorted.filter(n => n % 2 === 0).length;
  const odds = sorted.length - evens;
  const highs = sorted.filter(n => n > 20).length;
  const lows = sorted.length - highs;
  const totalSum = sorted.reduce((a, b) => a + b, 0);

  await pool.query(
    `INSERT INTO lot_generated_combinations
       (user_id, number1, number2, number3, number4, number5, number6,
        evens, odds, highs, lows, total_sum, score, coincidences, combination_str, source)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)`,
    [
      userId,
      sorted[0], sorted[1], sorted[2], sorted[3], sorted[4], sorted[5],
      evens, odds, highs, lows, totalSum,
      score, coincidences,
      sorted.join(','),
      source,
    ],
  );
}

/**
 * Obtiene las últimas N combinaciones históricas para el análisis de diversidad.
 * Equivalente a ObtenerCombinacionesLoteriaAsync de LTFree.
 */
export async function getRecentHistoricalCombinations(limit = 50, lotteryId?: string): Promise<number[][]> {
  const { rows } = await pool.query<{ numbers: number[] }>(
    `SELECT numbers
     FROM historical_results
     WHERE ($2::UUID IS NULL AND lottery_id IS NULL) OR lottery_id = $2
     ORDER BY draw_date DESC LIMIT $1`,
    [limit, lotteryId ?? null],
  );
  return rows.map(r => r.numbers);
}

/**
 * Verifica si un usuario ya tiene un Pull de 10 para el contrato específico.
 * Regla: 1 contrato = 1 pull. Si ya tiene 10 combinaciones pull_10 asociadas
 * a este contract_id, no puede pedir otro.
 */
export async function userHasActivePull(userId: string, contractId: string): Promise<boolean> {
  const { rows } = await pool.query<{ count: string }>(
    `SELECT COUNT(*) AS count
     FROM plays
     WHERE user_id = $1
       AND source = 'pull_10'
       AND created_at >= (
         SELECT signed_at FROM commitment_contracts WHERE id = $2
       )
       AND created_at <= (
         SELECT signed_at + INTERVAL '30 days' FROM commitment_contracts WHERE id = $2
       )`,
    [userId, contractId],
  );
  return parseInt(rows[0].count, 10) >= 10;
}

export async function getPullCountLast30Days(userId: string): Promise<number> {
  const { rows } = await pool.query<{ count: string }>(
    `SELECT COUNT(*) AS count
     FROM plays
     WHERE user_id = $1
       AND source = 'pull_10'
       AND created_at >= NOW() - INTERVAL '30 days'`,
    [userId],
  );
  return parseInt(rows[0].count, 10);
}

/**
 * Obtiene TODAS las combinaciones pull_10 previas del usuario (todos sus contratos).
 * Garantiza que el nuevo pull no repita combinaciones de contratos anteriores.
 */
export async function getUserPullHistory(userId: string): Promise<number[][]> {
  const { rows } = await pool.query<{ numbers: number[] }>(
    `SELECT numbers FROM plays
     WHERE user_id = $1 AND source = 'pull_10'
     ORDER BY created_at DESC`,
    [userId],
  );
  return rows.map(r => r.numbers);
}

/**
 * Obtiene TODAS las combinaciones pull_10 activas de TODOS los usuarios
 * para garantizar que no haya choques entre usuarios.
 * Solo considera pulls generados en los últimos 30 días (contratos vigentes).
 */
export async function getAllActivePullCombinations(): Promise<number[][]> {
  const { rows } = await pool.query<{ combination_str: string }>(
    `SELECT DISTINCT combination_str
     FROM lot_generated_combinations
     WHERE source = 'pull_10'
       AND created_at >= NOW() - INTERVAL '30 days'`,
  );
  return rows.map(r => r.combination_str.split(',').map(Number));
}

// ─────────────────────────────────────────────────────────────────────────────
// PRE-GENERATED POOL METHODS
// ─────────────────────────────────────────────────────────────────────────────

export async function savePoolBatch(combinations: Array<{ numbers: number[], score: number }>, lotteryId?: string): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    for (const combo of combinations) {
      await client.query(
        `INSERT INTO lot_pool_combinations (lottery_id, numbers, score) VALUES ($1, $2, $3)`,
        [lotteryId ?? null, combo.numbers, combo.score]
      );
    }
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

export async function countAvailablePool(lotteryId?: string): Promise<number> {
  const { rows } = await pool.query<{ count: string }>(
    `SELECT COUNT(*) AS count FROM lot_pool_combinations WHERE is_delivered = FALSE AND (lottery_id = $1 OR ($1 IS NULL AND lottery_id IS NULL))`,
    [lotteryId ?? null]
  );
  return parseInt(rows[0].count, 10);
}

export async function deliverFromPool(userId: string, count: number, lotteryId?: string): Promise<number[][]> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    // Select the best undelivered combinations
    const { rows } = await client.query<{ id: string, numbers: number[] }>(
      `SELECT id, numbers FROM lot_pool_combinations 
       WHERE is_delivered = FALSE 
         AND (lottery_id = $1 OR ($1 IS NULL AND lottery_id IS NULL))
       ORDER BY score DESC LIMIT $2 FOR UPDATE`,
      [lotteryId ?? null, count]
    );

    if (rows.length < count) {
      throw new Error(`No hay suficientes combinaciones disponibles en el pool (${rows.length}/${count})`);
    }

    const ids = rows.map(r => r.id);
    
    // Mark as delivered
    await client.query(
      `UPDATE lot_pool_combinations 
       SET is_delivered = TRUE, delivered_to = $1, delivered_at = NOW() 
       WHERE id = ANY($2)`,
      [userId, ids]
    );

    await client.query('COMMIT');
    return rows.map(r => r.numbers);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
