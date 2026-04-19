import { Router, Request, Response, NextFunction } from 'express';
import { authMiddleware } from '../middlewares/auth.middleware';
import * as commitmentService from '../services/commitment.service';
import * as pullService from '../services/pull.service';
import * as paymentService from '../services/payment.service';
import { SignContractDto } from '../dtos/commitment.dto';
import { AppError } from '../middlewares/errorHandler';

export const commitmentRouter = Router();
export const pull10Router = Router();

// ── GET /commitment/form ───────────────────────────────────────────────────

commitmentRouter.get(
  '/form',
  authMiddleware,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = (req.user as { sub: string }).sub;
      res.json(await commitmentService.getTemplate(userId));
    } catch (err) {
      next(err);
    }
  },
);

// ── POST /commitment/sign ──────────────────────────────────────────────────

commitmentRouter.post(
  '/sign',
  authMiddleware,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = (req.user as { sub: string }).sub;
      const ip = req.ip ?? null;
      const dto = req.body as SignContractDto;
      const result = await commitmentService.sign(dto, userId, ip);
      res.status(201).json(result);
    } catch (err) {
      // Attach fields to response if present
      if (err instanceof AppError && (err as AppError & { fields?: unknown }).fields) {
        const e = err as AppError & { fields: Array<{ field: string; message: string }> };
        res.status(e.statusCode).json({ error: e.message, fields: e.fields });
        return;
      }
      next(err);
    }
  },
);

// ── GET /commitment/status ─────────────────────────────────────────────────

commitmentRouter.get(
  '/status',
  authMiddleware,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = (req.user as { sub: string }).sub;
      const status = await commitmentService.getStatus(userId);
      res.json(status);
    } catch (err) {
      next(err);
    }
  },
);

// ── GET /commitment/report/:contract_id ───────────────────────────────────

commitmentRouter.get(
  '/report/:contract_id',
  authMiddleware,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = (req.user as { sub: string }).sub;
      const report = await commitmentService.generateReport(req.params.contract_id, userId);
      res.json({ report });
    } catch (err) {
      next(err);
    }
  },
);

// ── POST /lottery/create-payment-intent ────────────────────────────────

pull10Router.post(
  '/create-payment-intent',
  authMiddleware,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = (req.user as { sub: string }).sub;

      // Check if Stripe is configured and we're in production
      const isDev = process.env.NODE_ENV === 'development';
      const stripeConfigured = process.env.STRIPE_SECRET_KEY && !process.env.STRIPE_SECRET_KEY.includes('your_stripe');
      if (isDev || !stripeConfigured) {
        // Development mode: return mock payment intent
        console.log('Development mode: returning mock payment intent');
        res.json({
          clientSecret: 'mock_client_secret_' + Date.now(),
          paymentIntentId: 'mock_pi_' + Date.now(),
        });
        return;
      }

      // Assume fixed price for Pull10, e.g., 1000 cents = $10
      const amount = 1000; // in cents
      const paymentIntent = await paymentService.createPaymentIntent({
        amount,
        currency: 'usd',
        metadata: { userId, type: 'pull10' },
      });
      res.json({
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── POST /lottery/pull-10 ─────────────────────────────────────────────────

pull10Router.post(
  '/pull-10',
  authMiddleware,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = (req.user as { sub: string }).sub;
      const paymentIntentId = req.body.payment_intent_id as string;

      if (!paymentIntentId) {
        throw new AppError('Payment intent ID is required', 'PAYMENT_REQUIRED', 400);
      }

      // Check if Stripe is configured and we're in production
      const isDev = process.env.NODE_ENV === 'development';
      const stripeConfigured = process.env.STRIPE_SECRET_KEY && !process.env.STRIPE_SECRET_KEY.includes('your_stripe');
      if (isDev || !stripeConfigured) {
        // Development mode: skip payment verification
        console.log('Development mode: skipping payment verification');
      } else {
        // Verify payment
        const paymentIntent = await paymentService.retrievePaymentIntent(paymentIntentId);
        if (paymentIntent.status !== 'succeeded') {
          throw new AppError('Payment not completed', 'PAYMENT_NOT_COMPLETED', 400);
        }

        if (paymentIntent.metadata?.userId !== userId) {
          throw new AppError('Invalid payment', 'PAYMENT_INVALID', 400);
        }
      }

      const result = await pullService.pull10(userId, req.body.lottery_id as string | undefined);
      res.status(201).json(result);
    } catch (err) {
      next(err);
    }
  },
);
