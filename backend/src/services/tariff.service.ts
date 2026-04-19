import * as tariffRepo from '../repositories/tariff.repository';
import { pool } from '../config/database';
import { AppError } from '../middlewares/errorHandler';
import { UpdateTariffDto } from '../dtos/admin.dto';

export async function getTariff() {
  return tariffRepo.getCurrent();
}

export async function updateTariff(data: UpdateTariffDto, adminId: string) {
  if (data.base_cost_per_play <= 0)
    throw new AppError('base_cost_per_play debe ser mayor a 0', 'VALIDATION_ERROR', 422);
  if (data.subscription_cost <= 0)
    throw new AppError('subscription_cost debe ser mayor a 0', 'VALIDATION_ERROR', 422);
  if (data.discount_percentage < 0 || data.discount_percentage > 100)
    throw new AppError('discount_percentage debe estar entre 0 y 100', 'VALIDATION_ERROR', 422);
  if (data.min_plays_for_discount <= 0)
    throw new AppError('min_plays_for_discount debe ser mayor a 0', 'VALIDATION_ERROR', 422);

  const previous = await tariffRepo.getCurrent();
  const updated = await tariffRepo.upsert({ ...data, updated_by: adminId });

  await pool.query(
    `INSERT INTO audit_logs (user_id, action, metadata) VALUES ($1, $2, $3)`,
    [adminId, 'TARIFF_UPDATED', JSON.stringify({ previous, updated })],
  );

  return updated;
}
