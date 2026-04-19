import { pool } from '../config/database';
import { CreateBankAccountDto, UpdateBankAccountDto } from '../dtos/admin.dto';

export interface BankAccountRecord {
  id: string;
  bank_name: string;
  account_number: string;
  account_type: string;
  account_holder: string;
  description: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export async function findAll(): Promise<BankAccountRecord[]> {
  const { rows } = await pool.query<BankAccountRecord>(
    'SELECT * FROM company_bank_accounts ORDER BY created_at DESC',
  );
  return rows;
}

export async function findActive(): Promise<BankAccountRecord[]> {
  const { rows } = await pool.query<BankAccountRecord>(
    'SELECT * FROM company_bank_accounts WHERE is_active = true ORDER BY created_at DESC',
  );
  return rows;
}

export async function findById(id: string): Promise<BankAccountRecord | null> {
  const { rows } = await pool.query<BankAccountRecord>(
    'SELECT * FROM company_bank_accounts WHERE id = $1 LIMIT 1',
    [id],
  );
  return rows[0] ?? null;
}

export async function create(data: CreateBankAccountDto): Promise<BankAccountRecord> {
  const { rows } = await pool.query<BankAccountRecord>(
    `INSERT INTO company_bank_accounts (bank_name, account_number, account_type, account_holder, description)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [data.bank_name, data.account_number, data.account_type, data.account_holder, data.description ?? null],
  );
  return rows[0];
}

export async function update(id: string, data: UpdateBankAccountDto): Promise<BankAccountRecord | null> {
  const { rows } = await pool.query<BankAccountRecord>(
    `UPDATE company_bank_accounts SET
       bank_name = $1, account_number = $2, account_type = $3,
       account_holder = $4, description = $5, updated_at = NOW()
     WHERE id = $6 RETURNING *`,
    [data.bank_name, data.account_number, data.account_type, data.account_holder, data.description ?? null, id],
  );
  return rows[0] ?? null;
}

export async function setStatus(id: string, is_active: boolean): Promise<BankAccountRecord | null> {
  const { rows } = await pool.query<BankAccountRecord>(
    'UPDATE company_bank_accounts SET is_active = $1, updated_at = NOW() WHERE id = $2 RETURNING *',
    [is_active, id],
  );
  return rows[0] ?? null;
}

export async function deleteById(id: string): Promise<boolean> {
  const { rowCount } = await pool.query(
    'DELETE FROM company_bank_accounts WHERE id = $1',
    [id],
  );
  return (rowCount ?? 0) > 0;
}
