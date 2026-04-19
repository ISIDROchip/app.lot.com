import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { rateLimiter } from './middlewares/rateLimiter';
import { sanitize } from './middlewares/sanitize';
import { errorHandler } from './middlewares/errorHandler';
import { authRouter } from './controllers/auth.controller';
import { dreamRouter } from './controllers/dream.controller';
import { statsRouter } from './controllers/stats.controller';
import { lotteryRouter, historyRouter, contractHistoryRouter } from './controllers/lottery.controller';
import { adminRouter } from './controllers/admin.controller';
import { scraperRouter } from './controllers/scraper.controller';
import { commitmentRouter, pull10Router } from './controllers/commitment.controller';
import { donationRouter } from './controllers/donation.controller';
import { authMiddleware } from './middlewares/auth.middleware';
import * as bankAccountService from './services/bankAccount.service';
import * as lotteryCatalog from './repositories/lottery_catalog.repository';

export function createApp(): express.Application {
  const app = express();

  app.use(helmet({ crossOriginResourcePolicy: false }));
  app.use(cors({ origin: '*', methods: ['GET','POST','PUT','PATCH','DELETE'], allowedHeaders: ['Content-Type','Authorization','X-API-Key'] }));
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));
  app.use(rateLimiter);
  app.use(sanitize);

  app.get('/health', (_req, res) => res.json({ status: 'ok' }));

  app.use('/users', authRouter);
  app.use('/users', historyRouter);
  app.use('/users', contractHistoryRouter);
  app.use('/dreams', dreamRouter);
  app.use('/stats', statsRouter);
  app.use('/lottery', lotteryRouter);
  app.use('/admin', adminRouter);
  app.use('/admin/scraper', scraperRouter);
  app.use('/commitment', commitmentRouter);
  app.use('/lottery', pull10Router);
  app.use('/donations', donationRouter);

  app.get('/bank-accounts', authMiddleware, async (_req, res, next) => {
    try {
      res.json({ data: await bankAccountService.findActive() });
    } catch (err) { next(err); }
  });

  // Public lottery catalog — active lotteries for users
  app.get('/lotteries', authMiddleware, async (_req, res, next) => {
    try {
      res.json({ data: await lotteryCatalog.findActive() });
    } catch (err) { next(err); }
  });

  app.use(errorHandler);

  return app;
}
