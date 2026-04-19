import { pool } from '../config/database';

export interface TariffRecord {
  id: string;
  base_cost_per_play: number;
  subscription_cost: number;
  discount_percentage: number;
  min_plays_for_discount: number;
  updated_by: string | null;
  updated_at: string;
}

export async function getCurrent(): Promise<TariffRecord | null> {
  const { rows } = await pool.query<TariffRecord>(
    'SELECT * FROM tariff_config ORDER BY updated_at DESC LIMIT 1',
  );
  return rows[0] ?? null;
}

export async function upsert(
  data: Omit<TariffRecord, 'id' | 'updated_at'>,
): Promise<TariffRecord> {
  const existing = await getCurrent();
  if (existing) {
    const { rows } = await pool.query<TariffRecord>(
      `UPDATE tariff_config SET
        base_cost_per_play = $1, subscription_cost = $2,
        discount_percentage = $3, min_plays_for_discount = $4,
        updated_by = $5, updated_at = NOW()
       WHERE id = $6 RETURNING *`,
      [data.base_cost_per_play, data.subscription_cost, data.discount_percentage, data.min_plays_for_discount, data.updated_by, existing.id],
    );
    return rows[0];
  }
  const { rows } = await pool.query<TariffRecord>(
    `INSERT INTO tariff_config (base_cost_per_play, subscription_cost, discount_percentage, min_plays_for_discount, updated_by)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [data.base_cost_per_play, data.subscription_cost, data.discount_percentage, data.min_plays_for_discount, data.updated_by],
  );
  return rows[0];
}
