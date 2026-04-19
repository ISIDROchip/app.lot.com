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
  getPullCountLast30Days,
  getAllActivePullCombinations,
  getUserPullHistory,
} from '../repositories/engine.repository';
import { generatePull10 } from '../utils/combinationOptimizer';

export async function pull10(userId: string, lotteryId?: string): Promise<Pull10Result> {
  // 1. Regla: un usuario puede solicitar hasta 20 Pulls de 10 en los últimos 30 días
  const pullCountLast30Days = await getPullCountLast30Days(userId);
  const pullsInLast30Days = Math.ceil(pullCountLast30Days / 10);
  if (pullsInLast30Days >= 20) {
    throw new AppError(
      'Has alcanzado el límite de 20 Pulls de 10 en los últimos 30 días.',
      'PULL_MONTHLY_LIMIT',
      429,
    );
  }

  // 3. Cargar todos los datos del motor en paralelo
  const [
    freqRecords, engineFreqs, cycles, topPairs,
    positionFreqs, engineConfig, recentHistory,
    allActiveCombinations,
    userPullHistory,        // pulls previos del mismo usuario (todos sus contratos)
  ] = await Promise.all([
    getFrequencies(),
    getNumberFrequencies(lotteryId),
    getNumberCycles(lotteryId),
    getTopPairs(20, lotteryId),
    getPositionFrequencies(lotteryId),
    getEngineConfig(),
    getRecentHistoricalCombinations(50, lotteryId),
    getAllActivePullCombinations(),
    getUserPullHistory(userId), // garantiza que el nuevo pull no repite combinaciones previas del usuario
  ]);

  const frequencies = new Map<number, number>(freqRecords.map(r => [r.number, r.count]));
  if (engineFreqs.length > 0) {
    engineFreqs.forEach(f => frequencies.set(f.number, f.frequency));
  }

  // 4. Historial extendido:
  //    - Resultados históricos de sorteos reales
  //    - Combinaciones activas de TODOS los usuarios (anti-choque)
  //    - Pulls previos del mismo usuario (anti-repetición entre contratos)
  const extendedHistory = [
    ...recentHistory,
    ...allActiveCombinations,
    ...userPullHistory,
  ];

  const combinations = generatePull10(frequencies, extendedHistory, {
    cycles,
    topPairs,
    positionFreqs,
    config: engineConfig,
  });

  // 5. Verificación final: ninguna combinación puede existir ya en la DB
  //    de ningún usuario (pull activo de cualquier persona)
  const activeCombinationSet = new Set(allActiveCombinations.map(c => c.join(',')));
  const userHistorySet = new Set(userPullHistory.map(c => c.join(',')));

  const safeCombinations = combinations.filter(c => {
    const key = [...c].sort((a, b) => a - b).join(',');
    return !activeCombinationSet.has(key) && !userHistorySet.has(key);
  });

  // Si alguna combinación chocó, regenerar las que faltan
  let finalCombinations = [...safeCombinations];
  let retries = 0;
  while (finalCombinations.length < 10 && retries < 50) {
    const needed = 10 - finalCombinations.length;
    const extra = generatePull10(frequencies,
      [...extendedHistory, ...finalCombinations],
      { cycles, topPairs, positionFreqs, config: engineConfig },
    ).slice(0, needed);

    for (const c of extra) {
      const key = [...c].sort((a, b) => a - b).join(',');
      if (!activeCombinationSet.has(key) && !userHistorySet.has(key) &&
          !finalCombinations.some(f => f.join(',') === key)) {
        finalCombinations.push(c);
        activeCombinationSet.add(key); // mark as used immediately
      }
    }
    retries++;
  }

  // 6. Persistir cada combinación
  for (const numbers of finalCombinations) {
    await savePlay(userId, 'Loto', numbers, 'pull_10');
    await saveGeneratedCombination(numbers, 0, 0, userId, 'pull_10').catch(() => {});
  }

  return {
    combinations: finalCombinations,
    lottery_id: lotteryId ?? null,
    timestamp: new Date().toISOString(),
  };
}
