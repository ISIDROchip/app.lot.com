import { Router, Request, Response, NextFunction } from 'express';
import { body, validationResult } from 'express-validator';
import { authMiddleware } from '../middlewares/auth.middleware';
import { config } from '../config/env';
import Stripe from 'stripe';

const stripe = new Stripe(config.stripeSecretKey || '', {
  apiVersion: '2023-10-16' as any,
});

export const donationRouter = Router();

donationRouter.post(
  '/intent',
  authMiddleware,
  body('amount').isNumeric().withMessage('Monto inválido'),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      res.status(400).json({ error: errors.array()[0].msg });
      return;
    }

    try {
      const { amount } = req.body;
      const userId = (req.user as { sub: string }).sub;

      // En modo desarrollo, saltamos Stripe real si se solicita o si no hay key
      if (process.env.NODE_ENV === 'development' || !config.stripeSecretKey) {
        res.status(201).json({
          clientSecret: 'mock_secret_donation_' + Date.now(),
          publishableKey: 'pk_test_mock',
          isMock: true
        });
        return;
      }

      const paymentIntent = await stripe.paymentIntents.create({
        amount: Math.round(amount * 100), // Stripe usa centavos
        currency: 'usd',
        metadata: { userId, type: 'donation' },
        automatic_payment_methods: { enabled: true },
      });

      res.status(201).json({
        clientSecret: paymentIntent.client_secret,
        publishableKey: process.env.STRIPE_PUBLISHABLE_KEY || '', // Normalmente se envía desde el env
      });
    } catch (err) {
      next(err);
    }
  }
);
