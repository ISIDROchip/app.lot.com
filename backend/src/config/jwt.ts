import jwt from 'jsonwebtoken';
import { config } from './env';

export const JWT_SECRET = config.jwtSecret;

export interface TokenPayload {
  userId: string;
  email: string;
  is_admin: boolean;
  is_super_admin: boolean;
}

export function signToken(payload: TokenPayload): string {
  return jwt.sign(
    { sub: payload.userId, email: payload.email, is_admin: payload.is_admin, is_super_admin: payload.is_super_admin },
    JWT_SECRET,
    { expiresIn: '24h' },
  );
}

export function verifyToken(token: string): jwt.JwtPayload {
  const decoded = jwt.verify(token, JWT_SECRET);
  if (typeof decoded === 'string') {
    throw new Error('Invalid token payload');
  }
  return decoded;
}
