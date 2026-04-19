import { Request, Response, NextFunction } from 'express';
import { AppError } from './errorHandler';

export function adminMiddleware(req: Request, _res: Response, next: NextFunction): void {
  const user = req.user as { is_admin?: boolean; is_super_admin?: boolean } | undefined;
  if (!user?.is_admin && !user?.is_super_admin) {
    return next(new AppError('Acceso denegado. Se requiere rol de administrador', 'FORBIDDEN', 403));
  }
  next();
}
