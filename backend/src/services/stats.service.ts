import * as statsRepo from '../repositories/stats.repository';
import { syncEngineTablesFromHistory } from '../repositories/engine.repository';
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
  await syncEngineTablesFromHistory();

  return stored;
}

export async function getFrequencies(): Promise<FrequencyRecord[]> {
  return statsRepo.getFrequencies();
}

export async function getTrends(): Promise<{ mostFrequent: number[]; leastFrequent: number[] }> {
  return statsRepo.getTrends();
}
