import { pool } from '../config/database';

export interface UserRecord {
  id: string;
  full_name: string;
  email: string;
  phone: string;
  password_hash: string;
  birth_date: Date;
  is_admin: boolean;
  is_super_admin: boolean;
  is_active: boolean;
  created_at: Date;
  updated_at: Date;
}

export interface CreateUserInput {
  fullName: string;
  email: string;
  phone: string;
  passwordHash: string;
  birthDate: Date;
}

export async function create(input: CreateUserInput): Promise<UserRecord> {
  const { rows } = await pool.query<UserRecord>(
    `INSERT INTO users (full_name, email, phone, password_hash, birth_date)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [input.fullName, input.email, input.phone, input.passwordHash, input.birthDate],
  );
  return rows[0];
}

export async function findByEmail(email: string): Promise<UserRecord | null> {
  const { rows } = await pool.query<UserRecord>(
    'SELECT * FROM users WHERE email = $1 LIMIT 1',
    [email],
  );
  return rows[0] ?? null;
}

export async function findById(id: string): Promise<UserRecord | null> {
  const { rows } = await pool.query<UserRecord>(
    'SELECT * FROM users WHERE id = $1 LIMIT 1',
    [id],
  );
  return rows[0] ?? null;
}
