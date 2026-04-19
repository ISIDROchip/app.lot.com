import { TipoJugada, JugadaResult, HistoryRecord } from '../types';
import { generateCombination } from '../utils/combinationOptimizer';
import { getFrequencies } from '../repositories/stats.repository';
import { savePlay, getHistory } from '../repositories/lottery.repository';
import {
  getNumberFrequencies,
  getNumberCycles,
  getTopPairs,
  getPositionFrequencies,
  getEngineConfig,
  getRecentHistoricalCombinations,
  saveGeneratedCombination,
} from '../repositories/engine.repository';
import { pool } from '../config/database';
import { AppError } from '../middlewares/errorHandler';

// ── Daily limits per play type ─────────────────────────────────────────────
// Loto: 1 per day | Pale, Tripleta, Número: 10 per day

const DAILY_LIMITS: Record<TipoJugada, number> = {
  'Loto':     1,
  'Pale':     10,
  'Tripleta': 10,
  'Número':   10,
};

async function getDailyCount(userId: string, tipo: TipoJugada): Promise<number> {
  const { rows } = await pool.query<{ count: string }>(
    `SELECT COUNT(*) AS count
     FROM plays
     WHERE user_id = $1
       AND play_type = $2
       AND source = 'generated'
       AND created_at >= CURRENT_DATE
       AND created_at < CURRENT_DATE + INTERVAL '1 day'`,
    [userId, tipo],
  );
  return parseInt(rows[0].count, 10);
}

// ── Generate ───────────────────────────────────────────────────────────────

export async function generate(tipo: TipoJugada, userId: string, lotteryId?: string): Promise<JugadaResult> {
  // Check daily limit
  const dailyCount = await getDailyCount(userId, tipo);
  const limit = DAILY_LIMITS[tipo];

  if (dailyCount >= limit) {
    const msg = tipo === 'Loto'
      ? 'Ya generaste tu jugada Loto de hoy. Vuelve mañana.'
      : `Ya alcanzaste el límite de ${limit} jugadas de ${tipo} por día.`;
    throw new AppError(msg, 'DAILY_LIMIT_REACHED', 429);
  }

  // Load frequencies
  const freqRecords = await getFrequencies();
  const frequencies = new Map<number, number>(freqRecords.map(r => [r.number, r.count]));

  const [engineFreqs, cycles, topPairs, positionFreqs, engineConfig, recentHistory] =
    await Promise.all([
      getNumberFrequencies(lotteryId),
      getNumberCycles(lotteryId),
      getTopPairs(20, lotteryId),
      getPositionFrequencies(lotteryId),
      getEngineConfig(),
      getRecentHistoricalCombinations(50, lotteryId),
    ]);

  if (engineFreqs.length > 0) {
    engineFreqs.forEach(f => frequencies.set(f.number, f.frequency));
  }

  const numbers = generateCombination(tipo, frequencies, recentHistory, {
    cycles,
    topPairs,
    positionFreqs,
    config: engineConfig,
  });

  const play = await savePlay(userId, tipo, numbers);

  if (tipo === 'Loto') {
    const coincidences = recentHistory.reduce(
      (max, previous) => Math.max(max, previous.filter(n => numbers.includes(n)).length),
      0,
    );

    await saveGeneratedCombination(numbers, 0, coincidences, userId, 'engine').catch(() => {});
  }

  return {
    id: play.id,
    tipo,
    numbers,
    timestamp: play.created_at,
    remaining: limit - dailyCount - 1,  // how many left today
  };
}

export async function getHistoryForUser(
  userId: string,
  page: number,
  limit: number,
): Promise<{ data: HistoryRecord[]; total: number }> {
  return getHistory(userId, page, limit);
}

// ── Get daily usage ────────────────────────────────────────────────────────

export async function getDailyUsage(userId: string): Promise<Record<TipoJugada, { used: number; limit: number; remaining: number }>> {
  const tipos: TipoJugada[] = ['Loto', 'Pale', 'Tripleta', 'Número'];
  const counts = await Promise.all(tipos.map(t => getDailyCount(userId, t)));

  return Object.fromEntries(
    tipos.map((t, i) => [t, {
      used: counts[i],
      limit: DAILY_LIMITS[t],
      remaining: Math.max(0, DAILY_LIMITS[t] - counts[i]),
    }]),
  ) as Record<TipoJugada, { used: number; limit: number; remaining: number }>;
}
