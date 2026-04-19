import { pool } from '../config/database';
import { AdminUserRecord } from '../types';

export async function listUsers(
  page: number,
  limit: number,
  search?: string,
): Promise<{ data: AdminUserRecord[]; total: number }> {
  const offset = (page - 1) * limit;
  const searchParam = search ? `%${search}%` : null;

  const whereClause = searchParam
    ? 'WHERE full_name ILIKE $3 OR email ILIKE $3'
    : '';
  const params = searchParam ? [limit, offset, searchParam] : [limit, offset];

  const { rows } = await pool.query<AdminUserRecord>(
    `SELECT id, full_name, email, phone, is_active, is_admin, is_super_admin, created_at
     FROM users ${whereClause}
     ORDER BY created_at DESC
     LIMIT $1 OFFSET $2`,
    params,
  );

  const { rows: countRows } = await pool.query<{ total: string }>(
    `SELECT COUNT(*) AS total FROM users ${whereClause}`,
    searchParam ? [searchParam] : [],
  );

  return { data: rows, total: parseInt(countRows[0].total, 10) };
}

export async function findUserById(id: string): Promise<AdminUserRecord | null> {
  const { rows } = await pool.query<AdminUserRecord>(
    `SELECT id, full_name, email, phone, is_active, is_admin, is_super_admin, created_at
     FROM users WHERE id = $1 LIMIT 1`,
    [id],
  );
  return rows[0] ?? null;
}

export async function setUserStatus(id: string, isActive: boolean): Promise<void> {
  await pool.query(
    'UPDATE users SET is_active = $1, updated_at = NOW() WHERE id = $2',
    [isActive, id],
  );
}
