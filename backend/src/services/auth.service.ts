import bcrypt from 'bcrypt';
import { signToken } from '../config/jwt';
import * as userRepo from '../repositories/user.repository';
import { isAdult } from '../utils/ageValidator';
import { AppError } from '../middlewares/errorHandler';

const BCRYPT_COST = 10;

export interface RegisterInput {
  fullName: string;
  birthDate: string; // ISO 8601
  email: string;
  phone: string;
  password: string;
}

export interface RegisterResult {
  id: string;
  email: string;
}

export interface LoginInput {
  email: string;
  password: string;
}

export interface LoginResult {
  token: string;
  expiresIn: number;
}

export async function register(input: RegisterInput): Promise<RegisterResult> {
  const birthDate = new Date(input.birthDate);

  if (!isAdult(birthDate)) {
    throw new AppError('Debes ser mayor de 18 años para registrarte', 'UNDERAGE', 403);
  }

  const existing = await userRepo.findByEmail(input.email);
  if (existing) {
    throw new AppError('El correo ya está registrado', 'EMAIL_CONFLICT', 409);
  }

  const passwordHash = await bcrypt.hash(input.password, BCRYPT_COST);

  const user = await userRepo.create({
    fullName: input.fullName,
    email: input.email,
    phone: input.phone,
    passwordHash,
    birthDate,
  });

  return { id: user.id, email: user.email };
}

export async function login(input: LoginInput): Promise<LoginResult> {
  const user = await userRepo.findByEmail(input.email);

  if (!user) {
    throw new AppError('Credenciales inválidas', 'INVALID_CREDENTIALS', 401);
  }

  const passwordMatch = await bcrypt.compare(input.password, user.password_hash);
  if (!passwordMatch) {
    throw new AppError('Credenciales inválidas', 'INVALID_CREDENTIALS', 401);
  }

  if (!user.is_active) {
    throw new AppError('Tu cuenta está desactivada. Contacta al administrador', 'ACCOUNT_DISABLED', 403);
  }

  const token = signToken({
    userId: user.id,
    email: user.email,
    is_admin: user.is_admin,
    is_super_admin: user.is_super_admin,
  });

  return { token, expiresIn: 86400 };
}
