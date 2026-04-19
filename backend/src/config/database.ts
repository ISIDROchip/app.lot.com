import { Pool } from 'pg';
import { config } from './env';

export const pool = new Pool({ connectionString: config.databaseUrl });

export async function connectDB(): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('SELECT 1');
    console.log('[DB] Connection established successfully');
  } finally {
    client.release();
  }
}
