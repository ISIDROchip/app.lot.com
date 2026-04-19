import { Router, Request, Response, NextFunction } from 'express';
import { validationResult } from 'express-validator';
import { statsUploadValidation } from '../dtos/stats.dto';
import { authMiddleware } from '../middlewares/auth.middleware';
import { superAdminMiddleware } from '../middlewares/superAdmin.middleware';
import * as statsService from '../services/stats.service';
import { getAdvancedStats } from '../repositories/stats.repository';
import { AppError } from '../middlewares/errorHandler';

export const statsRouter = Router();

const auth = authMiddleware;
const superAdmin = superAdminMiddleware;

// POST /stats/upload-results — SuperAdmin only
statsRouter.post('/upload-results', auth, superAdmin, statsUploadValidation,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return next(new AppError(errors.array().map(e => e.msg).join(', '), 'VALIDATION_ERROR', 422));
      }
      const userId = (req.user as { sub: string }).sub;
      const stored = await statsService.uploadResults(req.body.results, userId);
      res.status(201).json({ stored });
    } catch (err) { next(err); }
  },
);

// GET /stats/frequency — SuperAdmin only
statsRouter.get('/frequency', auth, superAdmin,
  async (_req: Request, res: Response, next: NextFunction) => {
    try {
      const frequencies = await statsService.getFrequencies();
      res.json({ frequencies });
    } catch (err) { next(err); }
  },
);

// GET /stats/trends — SuperAdmin only
statsRouter.get('/trends', auth, superAdmin,
  async (_req: Request, res: Response, next: NextFunction) => {
    try {
      res.json(await statsService.getTrends());
    } catch (err) { next(err); }
  },
);

// GET /stats/advanced — SuperAdmin only (LTFree full stats)
statsRouter.get('/advanced', auth, superAdmin,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const lotteryId = req.query.lottery_id as string | undefined;
      res.json(await getAdvancedStats(lotteryId));
    } catch (err) { next(err); }
  },
);
