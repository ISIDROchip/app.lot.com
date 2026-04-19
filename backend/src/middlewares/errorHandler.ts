import { Request, Response, NextFunction } from 'express';
import { insertError } from '../repositories/errorLog.repository';

export class AppError extends Error {
  constructor(
    public message: string,
    public code: string,
    public statusCode: number,
  ) {
    super(message);
    this.name = 'AppError';
  }
}

const ERROR_CODE_MAP: Record<string, number> = {
  UNDERAGE: 403,
  EMAIL_CONFLICT: 409,
  INVALID_CREDENTIALS: 401,
  TOKEN_MISSING: 401,
  TOKEN_INVALID: 401,
  DREAM_TOO_SHORT: 400,
  DREAM_SERVICE_DOWN: 503,
  INVALID_NUMBER_RANGE: 400,
  GENERATION_FAILED: 500,
  RATE_LIMIT_EXCEEDED: 429,
};

export function errorHandler(
  err: unknown,
  req: Request,
  res: Response,
  _next: NextFunction,
): void {
  const timestamp = new Date().toISOString();

  if (err instanceof AppError) {
    res.status(err.statusCode).json({ error: err.message, code: err.code, timestamp });
    return;
  }

  if (err instanceof Error) {
    const code = (err as AppError).code ?? 'INTERNAL_ERROR';
    const statusCode = ERROR_CODE_MAP[code] ?? 500;

    // Persist unhandled 500 errors with a reference_id
    if (statusCode === 500) {
      insertError({
        errorCode: code,
        message: err.message,
        stackTrace: err.stack,
        context: { method: req.method, path: req.path },
      })
        .then((referenceId) => {
          res.status(statusCode).json({ error: err.message, code, timestamp, reference_id: referenceId });
        })
        .catch(() => {
          res.status(statusCode).json({ error: err.message, code, timestamp });
        });
      return;
    }

    res.status(statusCode).json({ error: err.message, code, timestamp });
    return;
  }

  // Unknown error — persist and return reference_id
  insertError({
    errorCode: 'INTERNAL_ERROR',
    message: 'An unexpected error occurred',
    context: { method: req.method, path: req.path },
  })
    .then((referenceId) => {
      res.status(500).json({ error: 'An unexpected error occurred', code: 'INTERNAL_ERROR', timestamp, reference_id: referenceId });
    })
    .catch(() => {
      res.status(500).json({ error: 'An unexpected error occurred', code: 'INTERNAL_ERROR', timestamp });
    });
}
