import { Router, Request, Response, NextFunction } from 'express';
import { body, validationResult } from 'express-validator';
import { authMiddleware } from '../middlewares/auth.middleware';
import { generate, getHistoryForUser, getDailyUsage } from '../services/lottery.service';
import { getHistoryGroupedByContract } from '../repositories/lottery.repository';
import { TipoJugada } from '../types';

export const lotteryRouter = Router();

lotteryRouter.post(
  '/request-number',
  authMiddleware,
  body('tipo').isIn(['Loto', 'Pale', 'Tripleta', 'Número']).withMessage('tipo inválido'),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      res.status(400).json({ error: errors.array()[0].msg });
      return;
    }

    try {
      const userId = (req.user as { sub: string }).sub;
      const result = await generate(req.body.tipo as TipoJugada, userId, req.body.lottery_id as string | undefined);
      res.status(201).json(result);
    } catch (err) {
      next(err);
    }
  },
);

export const historyRouter = Router();

historyRouter.get(
  '/history',
  authMiddleware,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = (req.user as { sub: string }).sub;
      const page = Math.max(1, parseInt(String(req.query.page ?? '1'), 10));
      const limit = Math.max(1, Math.min(100, parseInt(String(req.query.limit ?? '20'), 10)));
      const { data, total } = await getHistoryForUser(userId, page, limit);
      res.status(200).json({ data, total, page, limit });
    } catch (err) {
      next(err);
    }
  },
);

// GET /lottery/daily-usage — cuántas jugadas le quedan al usuario hoy
lotteryRouter.get(
  '/daily-usage',
  authMiddleware,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = (req.user as { sub: string }).sub;
      res.json(await getDailyUsage(userId));
    } catch (err) {
      next(err);
    }
  },
);

// GET /users/history/contracts — historial agrupado por contrato con match de números
export const contractHistoryRouter = Router();
contractHistoryRouter.get(
  '/history/contracts',
  authMiddleware,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = (req.user as { sub: string }).sub;
      const groups = await getHistoryGroupedByContract(userId);
      res.json({ data: groups });
    } catch (err) {
      next(err);
    }
  },
);
