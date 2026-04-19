import * as repo from '../repositories/oauthProvider.repository';
import { pool } from '../config/database';
import { AppError } from '../middlewares/errorHandler';
import { UpdateOAuthProviderDto } from '../dtos/admin.dto';

export async function getProviders() {
  const providers = await repo.findAll();
  return providers.map((p) => ({ ...p, client_secret: '***' }));
}

export async function updateProvider(
  name: string,
  data: UpdateOAuthProviderDto,
  adminId: string,
) {
  if (!data.client_id?.trim())
    throw new AppError('client_id no puede estar vacío', 'VALIDATION_ERROR', 422);
  if (!data.client_secret?.trim())
    throw new AppError('client_secret no puede estar vacío', 'VALIDATION_ERROR', 422);
  if (!data.redirect_uri?.trim())
    throw new AppError('redirect_uri no puede estar vacío', 'VALIDATION_ERROR', 422);

  const updated = await repo.upsert(name, data, adminId);

  await pool.query(
    `INSERT INTO audit_logs (user_id, action, metadata) VALUES ($1, $2, $3)`,
    [
      adminId,
      'OAUTH_CONFIG_UPDATED',
      JSON.stringify({
        provider: name,
        client_id: data.client_id,
        redirect_uri: data.redirect_uri,
        is_active: data.is_active,
      }),
    ],
  );

  const { client_secret: _secret, ...safe } = updated;
  return safe;
}

export async function setProviderStatus(name: string, is_active: boolean) {
  const result = await repo.setStatus(name, is_active);
  if (!result) throw new AppError('Proveedor OAuth no encontrado', 'NOT_FOUND', 404);
  return { provider_name: result.provider_name, is_active: result.is_active };
}
