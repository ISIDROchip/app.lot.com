import { pool } from '../config/database';
import { FrequencyRecord } from '../types';

export interface HistoricalResultInput {
  drawDate: string;
  numbers: number[];
  uploadedBy?: string;
}

export async function insertResults(results: HistoricalResultInput[]): Promise<number> {
  if (results.length === 0) return 0;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    for (const r of results) {
      await client.query(
        'INSERT INTO historical_results (draw_date, numbers, uploaded_by) VALUES ($1, $2, $3)',
        [r.drawDate, r.numbers, r.uploadedBy ?? null],
      );
    }
    await client.query('COMMIT');
    return results.length;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

export async function getFrequencies(): Promise<FrequencyRecord[]> {
  const { rows } = await pool.query<{ number: string; count: string }>(
    `SELECT n AS number, COUNT(*) AS count
     FROM historical_results, UNNEST(numbers) AS n
     GROUP BY n
     ORDER BY count DESC, n ASC`,
  );
  return rows.map(r => ({ number: parseInt(r.number, 10), count: parseInt(r.count, 10) }));
}

export async function getTrends(): Promise<{ mostFrequent: number[]; leastFrequent: number[] }> {
  const frequencies = await getFrequencies();
  const mostFrequent = frequencies.slice(0, 5).map(r => r.number);
  const leastFrequent = frequencies.slice(-5).map(r => r.number);
  return { mostFrequent, leastFrequent };
}

// ── Advanced Statistics (LTFree equivalent) ───────────────────────────────

export interface AdvancedStats {
  totalDraws: number;
  mean: number;
  stdDev: number;
  median: number;
  mode: number;
  hotNumbers: Array<{ number: number; frequency: number; zScore: number }>;
  coldNumbers: Array<{ number: number; frequency: number; zScore: number }>;
  topPairs: Array<{ numberA: number; numberB: number; frequency: number }>;
  positionFrequency: Array<{ position: number; number: number; frequency: number }>;
  cycles: Array<{ number: number; drawsSinceLast: number; avgCycle: number | null }>;
  evenOddRatio: { evens: number; odds: number };
  sumDistribution: Array<{ range: string; count: number }>;
  segmentAnalysis: Array<{ segment: string; frequency: number }>;
}

export async function getAdvancedStats(lotteryId?: string): Promise<AdvancedStats> {
  const lotteryFilter = lotteryId
    ? `AND lottery_id = '${lotteryId}'`
    : `AND lottery_id IS NULL`;

  // Total draws
  const { rows: totalRows } = await pool.query<{ total: string }>(
    `SELECT COUNT(*) AS total FROM historical_results WHERE 1=1 ${lotteryFilter}`,
  );
  const totalDraws = parseInt(totalRows[0].total, 10);

  // Frequencies with stats
  const { rows: freqRows } = await pool.query<{
    number: string; frequency: string;
  }>(
    `SELECT n::INTEGER AS number, COUNT(*)::INTEGER AS frequency
     FROM historical_results, UNNEST(numbers) AS n
     WHERE 1=1 ${lotteryFilter}
     GROUP BY n ORDER BY frequency DESC`,
  );

  const freqs = freqRows.map(r => ({
    number: parseInt(r.number, 10),
    frequency: parseInt(r.frequency, 10),
  }));

  // Calculate mean, stddev, median, mode
  const values = freqs.map(f => f.frequency);
  const mean = values.length > 0 ? values.reduce((a, b) => a + b, 0) / values.length : 0;
  const stdDev = values.length > 0
    ? Math.sqrt(values.reduce((s, v) => s + (v - mean) ** 2, 0) / values.length)
    : 0;
  const sorted = [...values].sort((a, b) => a - b);
  const median = sorted.length > 0
    ? sorted.length % 2 === 0
      ? (sorted[sorted.length / 2 - 1] + sorted[sorted.length / 2]) / 2
      : sorted[Math.floor(sorted.length / 2)]
    : 0;
  const modeEntry = freqs.reduce((a, b) => b.frequency > a.frequency ? b : a, freqs[0]);
  const mode = modeEntry?.number ?? 0;

  // Hot/cold with z-score
  const withZScore = freqs.map(f => ({
    number: f.number,
    frequency: f.frequency,
    zScore: stdDev > 0 ? parseFloat(((f.frequency - mean) / stdDev).toFixed(3)) : 0,
  }));
  const hotNumbers = withZScore.filter(f => f.zScore > 0).slice(0, 10);
  const coldNumbers = withZScore.filter(f => f.zScore <= 0).slice(-10).reverse();

  // Top pairs
  const { rows: pairRows } = await pool.query<{
    number_a: string; number_b: string; frequency: string;
  }>(
    `SELECT number_a, number_b, frequency
     FROM lot_pair_frequency
     WHERE ($1::UUID IS NULL AND lottery_id IS NULL) OR lottery_id = $1
     ORDER BY frequency DESC LIMIT 10`,
    [lotteryId ?? null],
  );
  const topPairs = pairRows.map(r => ({
    numberA: parseInt(r.number_a, 10),
    numberB: parseInt(r.number_b, 10),
    frequency: parseInt(r.frequency, 10),
  }));

  // Position frequency (top 3 per position)
  const { rows: posRows } = await pool.query<{
    position: string; number: string; frequency: string;
  }>(
    `SELECT position, number, frequency
     FROM lot_position_frequency
     WHERE ($1::UUID IS NULL AND lottery_id IS NULL) OR lottery_id = $1
     ORDER BY position ASC, frequency DESC`,
    [lotteryId ?? null],
  );
  const positionFrequency = posRows
    .reduce((acc: typeof posRows, row) => {
      const pos = row.position;
      const existing = acc.filter(r => r.position === pos);
      if (existing.length < 3) acc.push(row);
      return acc;
    }, [])
    .map(r => ({
      position: parseInt(r.position, 10),
      number: parseInt(r.number, 10),
      frequency: parseInt(r.frequency, 10),
    }));

  // Cycles
  const { rows: cycleRows } = await pool.query<{
    number: string; draws_since_last: string; avg_cycle: string | null;
  }>(
    `SELECT number, draws_since_last, avg_cycle
     FROM lot_number_cycles
     WHERE ($1::UUID IS NULL AND lottery_id IS NULL) OR lottery_id = $1
     ORDER BY draws_since_last DESC LIMIT 10`,
    [lotteryId ?? null],
  );
  const cycles = cycleRows.map(r => ({
    number: parseInt(r.number, 10),
    drawsSinceLast: parseInt(r.draws_since_last, 10),
    avgCycle: r.avg_cycle ? parseFloat(r.avg_cycle) : null,
  }));

  // New: Even/Odd and Sum Analysis
  const { rows: drawRows } = await pool.query<{ numbers: number[] }>(
    `SELECT numbers FROM historical_results WHERE 1=1 ${lotteryFilter}`,
  );
  
  let totalEvens = 0;
  let totalOdds = 0;
  let totalNumbers = 0;
  const sums: number[] = [];

  for (const draw of drawRows) {
    for (const n of draw.numbers) {
      if (n % 2 === 0) totalEvens++; else totalOdds++;
      totalNumbers++;
    }
    sums.push(draw.numbers.reduce((a, b) => a + Number(b), 0));
  }

  const evenOddRatio = {
    evens: totalNumbers > 0 ? Math.round((totalEvens / totalNumbers) * 100) : 0,
    odds: totalNumbers > 0 ? Math.round((totalOdds / totalNumbers) * 100) : 0,
  };

  // Sum distribution in ranges of 20
  const sumDist: Record<string, number> = {};
  for (const s of sums) {
    const rangeStart = Math.floor(s / 20) * 20;
    const range = `${rangeStart}-${rangeStart + 19}`;
    sumDist[range] = (sumDist[range] || 0) + 1;
  }
  const sumDistribution = Object.entries(sumDist)
    .map(([range, count]) => ({ range, count }))
    .sort((a, b) => parseInt(a.range) - parseInt(b.range));

  // Segment analysis (1-10, 11-20, 21-30, 31-40)
  const segments = [
    { name: '1-10', count: 0 },
    { name: '11-20', count: 0 },
    { name: '21-30', count: 0 },
    { name: '31-40', count: 0 },
  ];
  for (const f of freqs) {
    if (f.number <= 10) segments[0].count += f.frequency;
    else if (f.number <= 20) segments[1].count += f.frequency;
    else if (f.number <= 30) segments[2].count += f.frequency;
    else segments[3].count += f.frequency;
  }
  const segmentAnalysis = segments.map(s => ({ segment: s.name, frequency: s.count }));

  return { 
    totalDraws, 
    mean: parseFloat(mean.toFixed(2)), 
    stdDev: parseFloat(stdDev.toFixed(2)), 
    median, 
    mode, 
    hotNumbers, 
    coldNumbers, 
    topPairs, 
    positionFrequency, 
    cycles,
    evenOddRatio,
    sumDistribution,
    segmentAnalysis
  };
}
