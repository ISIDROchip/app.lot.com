import { Router, Request, Response, NextFunction } from 'express';
import { validationResult } from 'express-validator';
import { registerValidation } from '../dtos/register.dto';
import { loginValidation } from '../dtos/login.dto';
import * as authService from '../services/auth.service';
import { AppError } from '../middlewares/errorHandler';

export const authRouter = Router();

authRouter.post('/register', registerValidation, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return next(new AppError(
        errors.array().map(e => e.msg).join(', '),
        'VALIDATION_ERROR',
        422,
      ));
    }

    const result = await authService.register(req.body);
    res.status(201).json(result);
  } catch (err) {
    next(err);
  }
});

authRouter.post('/login', loginValidation, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return next(new AppError(
        errors.array().map(e => e.msg).join(', '),
        'VALIDATION_ERROR',
        422,
      ));
    }

    const result = await authService.login(req.body);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
});
