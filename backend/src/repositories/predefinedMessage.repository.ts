import { pool } from '../config/database';
import { CreateMessageDto, UpdateMessageDto } from '../dtos/admin.dto';

export interface PredefinedMessageRecord {
  id: string;
  title: string;
  body: string;
  message_type: string;
  role: 'sender' | 'receiver' | 'general';
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export async function findAll(): Promise<PredefinedMessageRecord[]> {
  const { rows } = await pool.query<PredefinedMessageRecord>(
    'SELECT * FROM predefined_messages ORDER BY created_at DESC',
  );
  return rows;
}

export async function findById(id: string): Promise<PredefinedMessageRecord | null> {
  const { rows } = await pool.query<PredefinedMessageRecord>(
    'SELECT * FROM predefined_messages WHERE id = $1 LIMIT 1',
    [id],
  );
  return rows[0] ?? null;
}

export async function create(data: CreateMessageDto): Promise<PredefinedMessageRecord> {
  const { rows } = await pool.query<PredefinedMessageRecord>(
    `INSERT INTO predefined_messages (title, body, message_type, role, is_active)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [data.title, data.body, data.message_type, data.role, data.is_active ?? true],
  );
  return rows[0];
}

export async function update(id: string, data: UpdateMessageDto): Promise<PredefinedMessageRecord | null> {
  const { rows } = await pool.query<PredefinedMessageRecord>(
    `UPDATE predefined_messages SET
       title = $1, body = $2, message_type = $3, role = $4, is_active = $5, updated_at = NOW()
     WHERE id = $6 RETURNING *`,
    [data.title, data.body, data.message_type, data.role, data.is_active ?? true, id],
  );
  return rows[0] ?? null;
}

export async function setStatus(id: string, is_active: boolean): Promise<PredefinedMessageRecord | null> {
  const { rows } = await pool.query<PredefinedMessageRecord>(
    'UPDATE predefined_messages SET is_active = $1, updated_at = NOW() WHERE id = $2 RETURNING *',
    [is_active, id],
  );
  return rows[0] ?? null;
}

export async function deleteById(id: string): Promise<boolean> {
  const { rowCount } = await pool.query(
    'DELETE FROM predefined_messages WHERE id = $1',
    [id],
  );
  return (rowCount ?? 0) > 0;
}
