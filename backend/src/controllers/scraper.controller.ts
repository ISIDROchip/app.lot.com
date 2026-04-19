import { Router, Request, Response, NextFunction } from 'express';
import { randomUUID } from 'crypto';
import { authMiddleware } from '../middlewares/auth.middleware';
import { superAdminMiddleware } from '../middlewares/superAdmin.middleware';
import { runScraper, getProgress } from '../services/scraper.service';
import { AppError } from '../middlewares/errorHandler';

export const scraperRouter = Router();

const auth = authMiddleware;
const superAdmin = superAdminMiddleware;

/**
 * POST /admin/scraper/run
 * Inicia el scraper en background y retorna un jobId para seguimiento.
 * Body: { baseUrl, dateFrom, dateTo, weekDays?, delayMs? }
 */
scraperRouter.post('/run', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { baseUrl, dateFrom, dateTo, weekDays, delayMs } = req.body as {
      baseUrl: string;
      dateFrom: string;
      dateTo: string;
      weekDays?: number[];
      delayMs?: number;
    };

    if (!baseUrl || !dateFrom || !dateTo) {
      throw new AppError('baseUrl, dateFrom y dateTo son requeridos', 'VALIDATION_ERROR', 422);
    }

    const from = new Date(dateFrom);
    const to = new Date(dateTo);
    if (isNaN(from.getTime()) || isNaN(to.getTime())) {
      throw new AppError('Formato de fecha inválido. Use YYYY-MM-DD', 'VALIDATION_ERROR', 422);
    }
    if (from > to) {
      throw new AppError('dateFrom debe ser anterior a dateTo', 'VALIDATION_ERROR', 422);
    }

    const userId = (req.user as { sub: string }).sub;
    const jobId = randomUUID();

    // Run in background — don't await
    runScraper(jobId, {
      baseUrl,
      dateFrom,
      dateTo,
      weekDays: weekDays ?? [3, 6],
      delayMs: delayMs ?? 1500,
      uploadedBy: userId,
    }).catch(() => {/* errors are stored in progress */});

    res.status(202).json({
      jobId,
      message: 'Scraper iniciado en background',
      progressUrl: `/admin/scraper/progress/${jobId}`,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /admin/scraper/progress/:jobId
 * Retorna el progreso actual del scraper.
 * Usar con polling cada 2-3 segundos desde el frontend.
 */
scraperRouter.get('/progress/:jobId', auth, superAdmin, (req: Request, res: Response, next: NextFunction) => {
  try {
    const progress = getProgress(req.params.jobId);
    if (!progress) {
      throw new AppError('Job no encontrado o expirado', 'NOT_FOUND', 404);
    }
    res.json(progress);
  } catch (err) {
    next(err);
  }
});
