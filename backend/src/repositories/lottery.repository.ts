import { pool } from '../config/database';
import { HistoryRecord, TipoJugada } from '../types';

export async function savePlay(
  userId: string,
  tipo: TipoJugada,
  numbers: number[],
  source: 'generated' | 'dream' | 'pull_10' = 'generated',
): Promise<{ id: string; created_at: string }> {
  const { rows } = await pool.query<{ id: string; created_at: string }>(
    `INSERT INTO plays (user_id, play_type, numbers, source)
     VALUES ($1, $2, $3, $4)
     RETURNING id, created_at`,
    [userId, tipo, numbers, source],
  );
  return rows[0];
}

export async function saveDreamInterpretation(
  userId: string,
  dreamText: string,
  numbers: number[],
  keywords: string[],
): Promise<{ id: string; created_at: string }> {
  const { rows } = await pool.query<{ id: string; created_at: string }>(
    `INSERT INTO dream_interpretations (user_id, dream_text, suggested_numbers, keywords)
     VALUES ($1, $2, $3, $4)
     RETURNING id, created_at`,
    [userId, dreamText, numbers, keywords],
  );
  return rows[0];
}

export async function getLastDreamInterpretation(userId: string): Promise<string | null> {
  const { rows } = await pool.query<{ created_at: string }>(
    `SELECT created_at FROM dream_interpretations 
     WHERE user_id = $1 
     ORDER BY created_at DESC 
     LIMIT 1`,
    [userId],
  );
  return rows[0]?.created_at || null;
}

export async function getHistory(
  userId: string,
  page: number,
  limit: number,
): Promise<{ data: HistoryRecord[]; total: number }> {
  const offset = (page - 1) * limit;

  const { rows } = await pool.query<{ id: string; type: string; numbers: number[]; created_at: string; meta: Record<string, unknown> }>(
    `SELECT id, 'play' AS type, numbers, created_at, '{}'::jsonb AS meta
     FROM plays WHERE user_id = $1
     UNION ALL
     SELECT id, 'dream' AS type, suggested_numbers AS numbers, created_at, '{}'::jsonb AS meta
     FROM dream_interpretations WHERE user_id = $1
     ORDER BY created_at DESC
     LIMIT $2 OFFSET $3`,
    [userId, limit, offset],
  );

  const { rows: countRows } = await pool.query<{ total: string }>(
    `SELECT (
       SELECT COUNT(*) FROM plays WHERE user_id = $1
     ) + (
       SELECT COUNT(*) FROM dream_interpretations WHERE user_id = $1
     ) AS total`,
    [userId],
  );

  const total = parseInt(countRows[0].total, 10);
  const data: HistoryRecord[] = rows.map(r => ({
    id: r.id,
    type: r.type as 'play' | 'dream',
    numbers: r.numbers,
    createdAt: r.created_at,
    meta: r.meta,
  }));

  return { data, total };
}

// ── History grouped by contract ────────────────────────────────────────────

export interface ContractGroup {
  contractId: string;
  signedAt: string;
  expiresAt: string;
  isActive: boolean;
  plays: Array<{
    id: string;
    numbers: number[];
    createdAt: string;
    matchedNumbers: number[];   // numbers that appeared in a real draw
    isWinner: boolean;          // all 6 matched
  }>;
}

export async function getHistoryGroupedByContract(userId: string): Promise<ContractGroup[]> {
  // 1. Get all pull_10 plays for this user grouped by contract period
  const { rows: contracts } = await pool.query<{
    id: string;
    signed_at: string;
  }>(
    `SELECT id, signed_at
     FROM commitment_contracts
     WHERE user_id = $1
     ORDER BY signed_at DESC`,
    [userId],
  );

  if (contracts.length === 0) return [];

  // 2. Get the last real draw result for matching
  const { rows: lastDraws } = await pool.query<{ numbers: number[]; draw_date: string }>(
    `SELECT numbers, draw_date
     FROM historical_results
     ORDER BY draw_date DESC
     LIMIT 10`,
  );
  const allDrawnNumbers = new Set(lastDraws.flatMap(d => d.numbers));

  const groups: ContractGroup[] = [];

  for (const contract of contracts) {
    const signedAt = new Date(contract.signed_at);
    const expiresAt = new Date(signedAt.getTime() + 30 * 24 * 60 * 60 * 1000);
    const isActive = new Date() < expiresAt;

    // Get plays generated during this contract period
    const { rows: plays } = await pool.query<{
      id: string;
      numbers: number[];
      created_at: string;
    }>(
      `SELECT id, numbers, created_at
       FROM plays
       WHERE user_id = $1
         AND source = 'pull_10'
         AND created_at >= $2
         AND created_at <= $3
       ORDER BY created_at ASC`,
      [userId, contract.signed_at, expiresAt.toISOString()],
    );

    if (plays.length === 0) continue;

    groups.push({
      contractId: contract.id,
      signedAt: contract.signed_at,
      expiresAt: expiresAt.toISOString(),
      isActive,
      plays: plays.map(p => {
        const matchedNumbers = p.numbers.filter(n => allDrawnNumbers.has(n));
        return {
          id: p.id,
          numbers: p.numbers,
          createdAt: p.created_at,
          matchedNumbers,
          isWinner: matchedNumbers.length === 6,
        };
      }),
    });
  }

  return groups;
}
