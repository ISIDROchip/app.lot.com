import { pool } from '../config/database';
import { v4 as uuidv4 } from 'uuid';

export interface ErrorLogInput {
  errorCode?: string;
  message: string;
  stackTrace?: string;
  context?: Record<string, unknown>;
}

export async function insertError(input: ErrorLogInput): Promise<string> {
  const referenceId = uuidv4();
  await pool.query(
    `INSERT INTO application_errors (reference_id, error_code, message, stack_trace, context)
     VALUES ($1, $2, $3, $4, $5)`,
    [referenceId, input.errorCode ?? null, input.message, input.stackTrace ?? null, JSON.stringify(input.context ?? {})],
  );
  return referenceId;
}

export async function findRecent(limit = 100) {
  const { rows } = await pool.query(
    'SELECT * FROM application_errors ORDER BY created_at DESC LIMIT $1',
    [limit],
  );
  return rows;
}

export async function findByReferenceId(referenceId: string) {
  const { rows } = await pool.query(
    'SELECT * FROM application_errors WHERE reference_id = $1 LIMIT 1',
    [referenceId],
  );
  return rows[0] ?? null;
}

export async function archiveOlderThan(days: number): Promise<void> {
  await pool.query(`
    WITH moved AS (
      DELETE FROM application_errors
      WHERE created_at < NOW() - INTERVAL '${days} days'
      RETURNING *
    )
    INSERT INTO application_errors_archive SELECT * FROM moved
  `);
}
