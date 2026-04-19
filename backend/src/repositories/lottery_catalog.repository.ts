/**
 * lottery_catalog.repository.ts
 * CRUD para el catálogo de loterías disponibles en el sistema.
 */

import { pool } from '../config/database';
import { Lottery } from '../types';

export async function findAll(): Promise<Lottery[]> {
  const { rows } = await pool.query<Lottery>(
    `SELECT id, name, short_name, country, numbers_count, number_range,
            draw_days, scraper_url, is_active, created_at
     FROM lotteries ORDER BY name ASC`,
  );
  return rows;
}

export async function findActive(): Promise<Lottery[]> {
  const { rows } = await pool.query<Lottery>(
    `SELECT id, name, short_name, country, numbers_count, number_range,
            draw_days, scraper_url, is_active, created_at
     FROM lotteries WHERE is_active = true ORDER BY name ASC`,
  );
  return rows;
}

export async function findById(id: string): Promise<Lottery | null> {
  const { rows } = await pool.query<Lottery>(
    `SELECT id, name, short_name, country, numbers_count, number_range,
            draw_days, scraper_url, is_active, created_at
     FROM lotteries WHERE id = $1`,
    [id],
  );
  return rows[0] ?? null;
}

export async function findByShortName(shortName: string): Promise<Lottery | null> {
  const { rows } = await pool.query<Lottery>(
    `SELECT id, name, short_name, country, numbers_count, number_range,
            draw_days, scraper_url, is_active, created_at
     FROM lotteries WHERE short_name = $1`,
    [shortName],
  );
  return rows[0] ?? null;
}

export async function create(data: Omit<Lottery, 'id' | 'created_at'>): Promise<Lottery> {
  const { rows } = await pool.query<Lottery>(
    `INSERT INTO lotteries (name, short_name, country, numbers_count, number_range,
                            draw_days, scraper_url, is_active)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
     RETURNING *`,
    [data.name, data.short_name, data.country, data.numbers_count,
     data.number_range, data.draw_days, data.scraper_url, data.is_active],
  );
  return rows[0];
}

export async function update(id: string, data: Partial<Omit<Lottery, 'id' | 'created_at'>>): Promise<Lottery | null> {
  const fields = Object.keys(data);
  if (fields.length === 0) return findById(id);

  const sets = fields.map((f, i) => `${f} = $${i + 2}`).join(', ');
  const values = fields.map(f => (data as Record<string, unknown>)[f]);

  const { rows } = await pool.query<Lottery>(
    `UPDATE lotteries SET ${sets} WHERE id = $1 RETURNING *`,
    [id, ...values],
  );
  return rows[0] ?? null;
}

export async function setStatus(id: string, isActive: boolean): Promise<Lottery | null> {
  const { rows } = await pool.query<Lottery>(
    `UPDATE lotteries SET is_active = $2 WHERE id = $1 RETURNING *`,
    [id, isActive],
  );
  return rows[0] ?? null;
}
