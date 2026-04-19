/**
 * combinationOptimizer.ts — Luxora Smart Lottery
 *
 * Motor de generación de combinaciones de alta calidad.
 * Inspirado en LTFree (C#) y mejorado con:
 *   1. Restricciones estructurales (suma, posición, deciles, paridad)
 *   2. Selección ponderada por frecuencia histórica con z-score
 *   3. Ciclos de aparición — boost para números "vencidos"
 *   4. Pares frecuentes — incluir al menos un par de alta co-ocurrencia
 *   5. Frecuencia por posición — guiar selección número a número
 *   6. Diversificación por distancia de Hamming vs historial
 *   7. Scoring multi-criterio con pesos configurables desde DB
 *   8. Búsqueda por torneo: genera K candidatos y elige el de mayor score
 */

import { TipoJugada } from '../types';
import type {
  NumberCycle,
  PairFrequency,
  PositionFrequency,
  EngineConfig,
} from '../repositories/engine.repository';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS (defaults — overridden by DB config when available)
// ─────────────────────────────────────────────────────────────────────────────

const RANGE = 40;
const LOTO_SIZE = 6;
const DEFAULT_TOURNAMENT_SIZE = 50;
const MAX_ATTEMPTS = 5000;

const POSITION_RANGES: [number, number][] = [
  [1, 20],
  [6, 26],
  [11, 31],
  [17, 40],
  [18, 40],
  [22, 40],
];

const SUM_MIN = 100;
const SUM_MAX = 180; // adjusted for range 1-40

const PAIR_SUM_RULES: [number, number, number, number][] = [
  [0, 1, 3, 36],
  [2, 3, 13, 68],
  [4, 5, 40, 80],
];

// ─────────────────────────────────────────────────────────────────────────────
// ADVANCED ENGINE INPUT
// ─────────────────────────────────────────────────────────────────────────────

export interface AdvancedEngineData {
  cycles?: NumberCycle[];
  topPairs?: PairFrequency[];
  positionFreqs?: PositionFrequency[];
  config?: EngineConfig;
}

// ─────────────────────────────────────────────────────────────────────────────
// MATH HELPERS
// ─────────────────────────────────────────────────────────────────────────────

function mean(v: number[]): number {
  if (v.length === 0) return 0;
  return v.reduce((a, b) => a + b, 0) / v.length;
}

function stdDev(v: number[]): number {
  if (v.length === 0) return 1;
  const m = mean(v);
  return Math.sqrt(v.reduce((s, x) => s + (x - m) ** 2, 0) / v.length) || 1;
}

// ─────────────────────────────────────────────────────────────────────────────
// WEIGHTED SAMPLING (without replacement)
// ─────────────────────────────────────────────────────────────────────────────

function weightedSample(candidates: number[], weights: number[], n: number): number[] {
  const result: number[] = [];
  const rem = [...candidates];
  const remW = [...weights];

  for (let i = 0; i < n; i++) {
    if (rem.length === 0) break;
    const total = remW.reduce((a, b) => a + b, 0);
    let rand = Math.random() * total;
    let idx = 0;
    while (idx < remW.length - 1 && rand > remW[idx]) {
      rand -= remW[idx];
      idx++;
    }
    result.push(rem[idx]);
    rem.splice(idx, 1);
    remW.splice(idx, 1);
  }
  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// NUMBER PROFILES (z-score + cycle boost + position boost)
// ─────────────────────────────────────────────────────────────────────────────

interface NumberProfile {
  number: number;
  frequency: number;
  zScore: number;
  cycleBoost: number;   // boost for numbers overdue
  weight: number;
}

function buildProfiles(
  frequencies: Map<number, number>,
  cycles: NumberCycle[],
  cycleBoostFactor: number,
  hotThresholdMultiplier: number,
): NumberProfile[] {
  const all = Array.from({ length: RANGE }, (_, i) => i + 1);
  const freqs = all.map(n => frequencies.get(n) ?? 0);
  const m = mean(freqs) * hotThresholdMultiplier;
  const sd = stdDev(freqs);

  // Build cycle map
  const cycleMap = new Map(cycles.map(c => [c.number, c]));
  const maxCycle = Math.max(...cycles.map(c => c.drawsSinceLast), 1);

  return all.map((n, i) => {
    const freq = freqs[i];
    const z = (freq - m) / sd;

    // Base weight from frequency
    const baseWeight = freq > m
      ? 1 + Math.min(z * 0.5, 1)
      : Math.max(0.1, 1 + z * 0.2);

    // Cycle boost: numbers that haven't appeared in many draws get a boost
    const cycle = cycleMap.get(n);
    const cycleBoost = cycle
      ? (cycle.drawsSinceLast / maxCycle) * cycleBoostFactor
      : 0;

    return {
      number: n,
      frequency: freq,
      zScore: z,
      cycleBoost,
      weight: Math.max(baseWeight + cycleBoost, 0.05),
    };
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// POSITION-GUIDED SELECTION (from lot_position_frequency)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * For each position (1-6), returns the top N numbers by historical frequency.
 * Equivalent to LTFree's rangosPorPosicion but data-driven.
 */
function buildPositionCandidates(
  positionFreqs: PositionFrequency[],
  topN = 15,
): Map<number, number[]> {
  const map = new Map<number, number[]>();
  for (let pos = 1; pos <= LOTO_SIZE; pos++) {
    const forPos = positionFreqs
      .filter(p => p.position === pos)
      .sort((a, b) => b.frequency - a.frequency)
      .slice(0, topN)
      .map(p => p.number);
    if (forPos.length > 0) map.set(pos, forPos);
  }
  return map;
}

// ─────────────────────────────────────────────────────────────────────────────
// STRUCTURAL VALIDATORS
// ─────────────────────────────────────────────────────────────────────────────

function hasConsecutiveRun(sorted: number[], runLen = 3): boolean {
  let streak = 1;
  for (let i = 1; i < sorted.length; i++) {
    streak = sorted[i] === sorted[i - 1] + 1 ? streak + 1 : 1;
    if (streak >= runLen) return true;
  }
  return false;
}

function sumInRange(sorted: number[]): boolean {
  const s = sorted.reduce((a, b) => a + b, 0);
  return s >= SUM_MIN && s <= SUM_MAX;
}

function meetsPositionRanges(sorted: number[]): boolean {
  return sorted.every((n, i) => n >= POSITION_RANGES[i][0] && n <= POSITION_RANGES[i][1]);
}

function meetsPairSums(sorted: number[]): boolean {
  return PAIR_SUM_RULES.every(([i, j, lo, hi]) => {
    const s = sorted[i] + sorted[j];
    return s >= lo && s <= hi;
  });
}

function meetsDecileRestriction(nums: number[]): boolean {
  const counts = [0, 0, 0];
  for (const n of nums) {
    if (n <= 20) counts[0]++;
    else if (n <= 26) counts[1]++;
    else counts[2]++;
  }
  return counts.every(c => c <= 3);
}

function firstHalfLessThanSecond(sorted: number[]): boolean {
  return (sorted[0] + sorted[1] + sorted[2]) < (sorted[3] + sorted[4] + sorted[5]);
}

function isValidLoto(combo: number[]): boolean {
  if (combo.length !== LOTO_SIZE) return false;
  const sorted = [...combo].sort((a, b) => a - b);
  if (new Set(sorted).size !== LOTO_SIZE) return false;
  if (sorted[0] < 1 || sorted[LOTO_SIZE - 1] > RANGE) return false;
  if (sorted.filter(n => n % 2 === 0).length !== 3) return false;
  if (hasConsecutiveRun(sorted)) return false;
  if (!sumInRange(sorted)) return false;
  if (!meetsPositionRanges(sorted)) return false;
  if (!meetsPairSums(sorted)) return false;
  if (!meetsDecileRestriction(sorted)) return false;
  if (!firstHalfLessThanSecond(sorted)) return false;
  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// HAMMING DISTANCE
// ─────────────────────────────────────────────────────────────────────────────

function hammingDistance(a: number[], b: number[]): number {
  const setA = new Set(a);
  return LOTO_SIZE - [...new Set(b)].filter(x => setA.has(x)).length;
}

function minHammingToHistory(combo: number[], history: number[][]): number {
  if (history.length === 0) return LOTO_SIZE;
  return Math.min(...history.map(h => hammingDistance(combo, h)));
}

// ─────────────────────────────────────────────────────────────────────────────
// PAIR BONUS (from lot_pair_frequency)
// ─────────────────────────────────────────────────────────────────────────────

function pairBonus(combo: number[], topPairs: PairFrequency[]): number {
  if (topPairs.length === 0) return 0;
  const set = new Set(combo);
  const maxPairFreq = topPairs[0].frequency || 1;
  let bonus = 0;
  for (const pair of topPairs.slice(0, 10)) {
    if (set.has(pair.numberA) && set.has(pair.numberB)) {
      bonus += pair.frequency / maxPairFreq;
    }
  }
  return Math.min(bonus, 1); // cap at 1
}

// ─────────────────────────────────────────────────────────────────────────────
// MULTI-CRITERIA SCORING
// ─────────────────────────────────────────────────────────────────────────────

function scoreCombination(
  combo: number[],
  profiles: NumberProfile[],
  history: number[][],
  topPairs: PairFrequency[],
  config: EngineConfig,
): number {
  const sorted = [...combo].sort((a, b) => a - b);
  const profileMap = new Map(profiles.map(p => [p.number, p]));

  const freqScore = mean(sorted.map(n => profileMap.get(n)?.zScore ?? 0));
  const dispScore = stdDev(sorted) / RANGE;
  const hammingScore = minHammingToHistory(sorted, history) / LOTO_SIZE;
  const balanceScore = sorted.filter(n => n % 2 === 0).length === 3 ? 1 : 0;
  const pairScore = pairBonus(sorted, topPairs);

  let consecutivePairs = 0;
  for (let i = 1; i < sorted.length; i++) {
    if (sorted[i] === sorted[i - 1] + 1) consecutivePairs++;
  }
  const consecutivePenalty = consecutivePairs / LOTO_SIZE;

  return (
    config.weightFrequency   * freqScore +
    config.weightDispersion  * dispScore +
    config.weightDiversity   * hammingScore +
    config.weightBalance     * (balanceScore + pairScore * 0.5) -
    config.weightConsecutive * consecutivePenalty
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CANDIDATE GENERATOR
// ─────────────────────────────────────────────────────────────────────────────

function generateLotoCandidate(
  profiles: NumberProfile[],
  positionCandidates: Map<number, number[]>,
): number[] | null {
  const pares = profiles.filter(p => p.number % 2 === 0);
  const impares = profiles.filter(p => p.number % 2 !== 0);

  try {
    // Try position-guided generation first (if we have position data)
    if (positionCandidates.size === LOTO_SIZE) {
      const combo: number[] = [];
      const used = new Set<number>();

      for (let pos = 1; pos <= LOTO_SIZE; pos++) {
        const candidates = (positionCandidates.get(pos) ?? []).filter(n => !used.has(n));
        if (candidates.length === 0) break;
        const weights = candidates.map(n => profiles.find(p => p.number === n)?.weight ?? 0.1);
        const [selected] = weightedSample(candidates, weights, 1);
        combo.push(selected);
        used.add(selected);
      }

      if (combo.length === LOTO_SIZE && isValidLoto(combo)) {
        return combo.sort((a, b) => a - b);
      }
    }

    // Fallback: parity-balanced weighted sampling
    const selectedPares = weightedSample(
      pares.map(p => p.number),
      pares.map(p => p.weight),
      3,
    );
    const selectedImpares = weightedSample(
      impares.map(p => p.number),
      impares.map(p => p.weight),
      3,
    );
    const combo = [...selectedPares, ...selectedImpares];
    return isValidLoto(combo) ? combo.sort((a, b) => a - b) : null;
  } catch {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOURNAMENT SELECTION
// ─────────────────────────────────────────────────────────────────────────────

function generateLoto(
  profiles: NumberProfile[],
  history: number[][],
  topPairs: PairFrequency[],
  positionCandidates: Map<number, number[]>,
  config: EngineConfig,
): number[] {
  const tournamentSize = config.tournamentSize ?? DEFAULT_TOURNAMENT_SIZE;
  const candidates: Array<{ combo: number[]; score: number }> = [];

  for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
    const combo = generateLotoCandidate(profiles, positionCandidates);
    if (!combo) continue;

    const score = scoreCombination(combo, profiles, history, topPairs, config);
    candidates.push({ combo, score });

    if (candidates.length >= tournamentSize) break;
  }

  if (candidates.length === 0) {
    // Fallback: basic rules only
    const all = profiles.map(p => p.number);
    const allW = profiles.map(p => p.weight);
    for (let i = 0; i < MAX_ATTEMPTS; i++) {
      const combo = weightedSample(all, allW, LOTO_SIZE).sort((a, b) => a - b);
      if (combo.filter(n => n % 2 === 0).length === 3 && !hasConsecutiveRun(combo)) return combo;
    }
    throw new Error('No se pudo generar combinación válida');
  }

  candidates.sort((a, b) => b.score - a.score);
  return candidates[0].combo;
}

// ─────────────────────────────────────────────────────────────────────────────
// DEFAULT ENGINE CONFIG (used when DB config is not available)
// ─────────────────────────────────────────────────────────────────────────────

const DEFAULT_CONFIG: EngineConfig = {
  weightFrequency: 0.35,
  weightDispersion: 0.25,
  weightDiversity: 0.25,
  weightBalance: 0.10,
  weightConsecutive: 0.05,
  tournamentSize: DEFAULT_TOURNAMENT_SIZE,
  hotThresholdMultiplier: 1.0,
  cycleBoostFactor: 0.15,
};

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC API
// ─────────────────────────────────────────────────────────────────────────────

export function generateCombination(
  tipo: TipoJugada,
  frequencies: Map<number, number>,
  history: number[][] = [],
  advanced: AdvancedEngineData = {},
): number[] {
  const candidates = Array.from({ length: RANGE }, (_, i) => i + 1);
  const weights = candidates.map(n => frequencies.get(n) ?? 1);

  if (tipo === 'Número') return weightedSample(candidates, weights, 1);
  if (tipo === 'Pale')   return weightedSample(candidates, weights, 2).sort((a, b) => a - b);
  if (tipo === 'Tripleta') return weightedSample(candidates, weights, 3).sort((a, b) => a - b);

  // Loto: full advanced engine
  const config = advanced.config ?? DEFAULT_CONFIG;
  const profiles = buildProfiles(
    frequencies,
    advanced.cycles ?? [],
    config.cycleBoostFactor,
    config.hotThresholdMultiplier,
  );
  const positionCandidates = buildPositionCandidates(advanced.positionFreqs ?? []);

  return generateLoto(profiles, history, advanced.topPairs ?? [], positionCandidates, config);
}

// ─────────────────────────────────────────────────────────────────────────────
// PULL-10 GENERATOR
// ─────────────────────────────────────────────────────────────────────────────

export function generatePull10(
  frequencies: Map<number, number>,
  history: number[][] = [],
  advanced: AdvancedEngineData = {},
): number[][] {
  const config = advanced.config ?? DEFAULT_CONFIG;
  const profiles = buildProfiles(
    frequencies,
    advanced.cycles ?? [],
    config.cycleBoostFactor,
    config.hotThresholdMultiplier,
  );
  const positionCandidates = buildPositionCandidates(advanced.positionFreqs ?? []);
  const pull: number[][] = [];

  while (pull.length < 10) {
    const extendedHistory = [...history, ...pull];
    const combo = generateLoto(
      profiles,
      extendedHistory,
      advanced.topPairs ?? [],
      positionCandidates,
      config,
    );
    if (!pull.some(p => p.join(',') === combo.join(','))) {
      pull.push(combo);
    }
  }

  return pull;
}
