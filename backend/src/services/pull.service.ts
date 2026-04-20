import { Pull10Result } from '../types';
import { AppError } from '../middlewares/errorHandler';
import { savePlay } from '../repositories/lottery.repository';
import { getFrequencies } from '../repositories/stats.repository';
import {
  getNumberFrequencies,
  getNumberCycles,
  getTopPairs,
  getPositionFrequencies,
  getEngineConfig,
  getRecentHistoricalCombinations,
  saveGeneratedCombination,
  deliverFromPool,
} from '../repositories/engine.repository';
import { pool } from '../config/database';
import { generatePull10 } from '../utils/combinationOptimizer';

export async function pull10(userId: string, lotteryId?: string): Promise<Pull10Result> {
  // 1. Regla: un usuario puede solicitar hasta 15 Pulls de 10 EN TOTAL
  const totalPullCount = await pool.query<{ count: string }>(
    `SELECT COUNT(*) AS count FROM plays WHERE user_id = $1 AND source = 'pull_10'`,
    [userId]
  );
  const totalPulls = Math.ceil(parseInt(totalPullCount.rows[0].count, 10) / 10);
  
  if (totalPulls >= 15) {
     throw new AppError(
       'Has alcanzado el límite total de 15 Pulls de 10 autorizados.',
       'PULL_TOTAL_LIMIT',
       400
     );
  }

  // 2. Entregar desde el Pool pre-generado (Capa LTFree + Luxora)
  // deliverFromPool ya se encarga de que no se repitan entre usuarios
  const combinations = await deliverFromPool(userId, 10, lotteryId);

  // 3. Persistir cada combinación en la tabla de jugadas (plays)
  for (const numbers of combinations) {
    await savePlay(userId, 'Loto', numbers, 'pull_10');
    // También guardamos una copia en lot_generated_combinations para auditoría
    await saveGeneratedCombination(numbers, 0, 0, userId, 'pull_10').catch(() => {});
  }

  return {
    combinations,
    lottery_id: lotteryId ?? null,
    timestamp: new Date().toISOString(),
  };
}
