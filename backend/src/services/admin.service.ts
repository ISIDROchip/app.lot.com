import * as adminRepo from '../repositories/admin.repository';
import { AppError } from '../middlewares/errorHandler';
import { AdminUserRecord } from '../types';
import { pool } from '../config/database';

export async function listUsers(page: number, limit: number, search?: string) {
  return adminRepo.listUsers(page, limit, search);
}

export async function getUserById(id: string): Promise<AdminUserRecord> {
  const user = await adminRepo.findUserById(id);
  if (!user) throw new AppError('Usuario no encontrado', 'NOT_FOUND', 404);
  return user;
}

export async function setUserStatus(
  targetId: string,
  requesterId: string,
  isActive: boolean,
): Promise<{ id: string; is_active: boolean }> {
  if (targetId === requesterId) {
    throw new AppError('No puedes desactivar tu propia cuenta', 'SELF_DEACTIVATION_FORBIDDEN', 400);
  }
  const user = await adminRepo.findUserById(targetId);
  if (!user) throw new AppError('Usuario no encontrado', 'NOT_FOUND', 404);
  await adminRepo.setUserStatus(targetId, isActive);
  return { id: targetId, is_active: isActive };
}

export async function getOverviewStats() {
  const { rows } = await pool.query<{
    total_users: string;
    total_plays: string;
    total_dreams: string;
    active_users: string;
  }>(`
    SELECT
      (SELECT COUNT(*) FROM users) AS total_users,
      (SELECT COUNT(*) FROM plays) AS total_plays,
      (SELECT COUNT(*) FROM dream_interpretations) AS total_dreams,
      (SELECT COUNT(*) FROM users WHERE is_active = true) AS active_users
  `);
  const r = rows[0];
  return {
    totalUsers: parseInt(r.total_users, 10),
    totalPlays: parseInt(r.total_plays, 10),
    totalDreams: parseInt(r.total_dreams, 10),
    activeUsers: parseInt(r.active_users, 10),
  };
}

export async function getActivityStats(from: Date, to: Date) {
  if (from >= to) {
    throw new AppError("El parámetro 'from' debe ser anterior a 'to'", 'INVALID_DATE_RANGE', 400);
  }
  const { rows } = await pool.query<{
    registrations: string;
    plays: string;
    dreams: string;
  }>(`
    SELECT
      (SELECT COUNT(*) FROM users WHERE created_at BETWEEN $1 AND $2) AS registrations,
      (SELECT COUNT(*) FROM plays WHERE created_at BETWEEN $1 AND $2) AS plays,
      (SELECT COUNT(*) FROM dream_interpretations WHERE created_at BETWEEN $1 AND $2) AS dreams
  `, [from, to]);
  const r = rows[0];
  return {
    registrations: parseInt(r.registrations, 10),
    plays: parseInt(r.plays, 10),
    dreams: parseInt(r.dreams, 10),
    period: { from: from.toISOString(), to: to.toISOString() },
  };
}
