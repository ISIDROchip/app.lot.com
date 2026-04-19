const Stripe = require('stripe');
import type { Stripe as StripeType } from 'stripe';
import { AppError } from '../middlewares/errorHandler';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

export interface PaymentIntentData {
  amount: number; // in cents
  currency: string;
  metadata?: Record<string, string>;
}

export async function createPaymentIntent(data: PaymentIntentData): Promise<any> {
  try {
    return await stripe.paymentIntents.create({
      amount: data.amount,
      currency: data.currency,
      metadata: data.metadata,
    });
  } catch (error) {
    throw new AppError('Error creating payment intent', 'PAYMENT_ERROR', 500);
  }
}

export async function confirmPaymentIntent(paymentIntentId: string): Promise<any> {
  try {
    return await stripe.paymentIntents.confirm(paymentIntentId);
  } catch (error) {
    throw new AppError('Error confirming payment', 'PAYMENT_ERROR', 500);
  }
}

export async function retrievePaymentIntent(paymentIntentId: string): Promise<any> {
  try {
    return await stripe.paymentIntents.retrieve(paymentIntentId);
  } catch (error) {
    throw new AppError('Payment intent not found', 'PAYMENT_NOT_FOUND', 404);
  }
}