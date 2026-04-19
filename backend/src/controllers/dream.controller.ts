import { Router, Request, Response, NextFunction } from 'express';
import { body, validationResult } from 'express-validator';
import { authMiddleware } from '../middlewares/auth.middleware';
import { interpret } from '../services/dream.service';

export const dreamRouter = Router();

dreamRouter.post(
  '/interpret',
  authMiddleware,
  body('dreamText')
    .isString()
    .isLength({ min: 10, max: 2000 })
    .withMessage('La descripción del sueño es demasiado corta'),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      res.status(400).json({ error: errors.array()[0].msg });
      return;
    }
    try {
      const userId = (req.user as { sub: string }).sub;
      const result = await interpret(req.body.dreamText as string, userId);
      res.status(200).json(result);
    } catch (err) {
      next(err);
    }
  },
);
