import axios from 'axios';
import { config } from '../config/env';
import * as statsRepo from '../repositories/stats.repository';
import * as engineRepo from '../repositories/engine.repository';
import { FrequencyRecord } from '../types';
import { AppError } from '../middlewares/errorHandler';

export interface HistoricalResultInput {
  drawDate: string;
  numbers: number[];
}

export async function uploadResults(results: HistoricalResultInput[], uploadedBy?: string): Promise<number> {
  // Validate all numbers are in range [1, 40]
  const invalidEntries: { index: number; numbers: number[] }[] = [];
  results.forEach((r, i) => {
    const invalid = r.numbers.filter(n => !Number.isInteger(n) || n < 1 || n > 40);
    if (invalid.length > 0) invalidEntries.push({ index: i, numbers: invalid });
  });

  if (invalidEntries.length > 0) {
    const err = new AppError(
      `Números fuera del rango [1,40] encontrados`,
      'INVALID_NUMBER_RANGE',
      400,
    ) as AppError & { invalidEntries: typeof invalidEntries };
    err.invalidEntries = invalidEntries;
    throw err;
  }

  const stored = await statsRepo.insertResults(results.map(r => ({ ...r, uploadedBy })));

  // Sync all engine tables after inserting new results
  // Equivalent to running all LTFree stored procedures in sequence
  await engineRepo.syncEngineTablesFromHistory();

  return stored;
}

export async function generatePoolBatch(amount = 1000, lotteryId?: string): Promise<{ total: number }> {
  // 1. Gather all stats needed for the AI engine
  const [frequencies, cycles, posFreqs, engineConfig] = await Promise.all([
    engineRepo.getNumberFrequencies(lotteryId),
    engineRepo.getNumberCycles(lotteryId),
    engineRepo.getPositionFrequencies(lotteryId),
    engineRepo.getEngineConfig(),
  ]);

  // Convert frequencies to a simple map number -> frequency
  const freqMap: Record<number, number> = {};
  frequencies.forEach(f => freqMap[f.number] = f.frequency);

  // Prepare profile data (z-score + weights)
  const values = Object.values(freqMap);
  const mean = values.length > 0 ? values.reduce((a, b) => a + b, 0) / values.length : 0;
  const std = values.length > 0 ? Math.sqrt(values.reduce((s, x) => s + (x - mean) ** 2, 0) / values.length) || 1 : 1;

  const profiles: Record<number, any> = {};
  frequencies.forEach(f => {
    const z = (f.frequency - (mean * engineConfig.hotThresholdMultiplier)) / std;
    profiles[f.number] = {
      z_score: z,
      weight: f.frequency > mean ? 1 + Math.min(z * 0.5, 1) : Math.max(0.1, 1 + z * 0.2),
      cycle_boost: 0 // Will be added from cycles if needed by Python
    };
  });

  // Add cycle boost to profiles
  const maxCycle = Math.max(...cycles.map(c => c.drawsSinceLast), 1);
  cycles.forEach(c => {
    if (profiles[c.number]) {
      profiles[c.number].cycle_boost = (c.drawsSinceLast / maxCycle) * engineConfig.cycleBoostFactor;
      profiles[c.number].weight += profiles[c.number].cycle_boost;
    }
  });

  // 2. Call AI Service
  const response = await axios.post<{ numbers: number[], score: number }[]>(
    `${config.aiServiceUrl}/engine/generate-batch`,
    {
      amount,
      stats: { profiles }
    }
  );

  const batch = response.data;

  // 3. Save to pool
  await engineRepo.savePoolBatch(batch, lotteryId);

  return { total: batch.length };
}

export async function getFrequencies(): Promise<FrequencyRecord[]> {
  return statsRepo.getFrequencies();
}

export async function getTrends(): Promise<{ mostFrequent: number[]; leastFrequent: number[] }> {
  return statsRepo.getTrends();
}
