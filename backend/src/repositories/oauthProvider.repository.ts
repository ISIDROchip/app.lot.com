import { pool } from '../config/database';
import { UpdateOAuthProviderDto } from '../dtos/admin.dto';

export interface OAuthProviderRecord {
  id: string;
  provider_name: string;
  client_id: string;
  client_secret: string;
  redirect_uri: string;
  is_active: boolean;
  updated_by: string | null;
  updated_at: string;
}

export async function findAll(): Promise<OAuthProviderRecord[]> {
  const { rows } = await pool.query<OAuthProviderRecord>(
    'SELECT * FROM oauth_providers ORDER BY provider_name',
  );
  return rows;
}

export async function findByProvider(name: string): Promise<OAuthProviderRecord | null> {
  const { rows } = await pool.query<OAuthProviderRecord>(
    'SELECT * FROM oauth_providers WHERE provider_name = $1 LIMIT 1',
    [name],
  );
  return rows[0] ?? null;
}

export async function upsert(
  provider: string,
  data: UpdateOAuthProviderDto,
  updatedBy: string,
): Promise<OAuthProviderRecord> {
  const existing = await findByProvider(provider);
  if (existing) {
    const { rows } = await pool.query<OAuthProviderRecord>(
      `UPDATE oauth_providers SET
         client_id = $1, client_secret = $2, redirect_uri = $3,
         is_active = $4, updated_by = $5, updated_at = NOW()
       WHERE provider_name = $6 RETURNING *`,
      [data.client_id, data.client_secret, data.redirect_uri, data.is_active, updatedBy, provider],
    );
    return rows[0];
  }
  const { rows } = await pool.query<OAuthProviderRecord>(
    `INSERT INTO oauth_providers (provider_name, client_id, client_secret, redirect_uri, is_active, updated_by)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [provider, data.client_id, data.client_secret, data.redirect_uri, data.is_active, updatedBy],
  );
  return rows[0];
}

export async function setStatus(provider: string, is_active: boolean): Promise<OAuthProviderRecord | null> {
  const { rows } = await pool.query<OAuthProviderRecord>(
    'UPDATE oauth_providers SET is_active = $1, updated_at = NOW() WHERE provider_name = $2 RETURNING *',
    [is_active, provider],
  );
  return rows[0] ?? null;
}
