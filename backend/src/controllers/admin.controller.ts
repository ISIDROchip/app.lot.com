import { Router, Request, Response, NextFunction } from 'express';
import { authMiddleware } from '../middlewares/auth.middleware';
import { adminMiddleware } from '../middlewares/admin.middleware';
import { superAdminMiddleware } from '../middlewares/superAdmin.middleware';
import * as adminService from '../services/admin.service';
import * as tariffService from '../services/tariff.service';
import * as bankAccountService from '../services/bankAccount.service';
import * as messageService from '../services/predefinedMessage.service';
import * as oauthService from '../services/oauth.service';
import * as errorLogRepo from '../repositories/errorLog.repository';
import * as commitmentRepo from '../repositories/commitment.repository';
import * as commitmentService from '../services/commitment.service';
import * as lotteryCatalog from '../repositories/lottery_catalog.repository';
import { pool } from '../config/database';

export const adminRouter = Router();

const auth = authMiddleware;
const admin = adminMiddleware;
const superAdmin = superAdminMiddleware;

// ── Users ──────────────────────────────────────────────────────────────────

adminRouter.get('/users', auth, admin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.max(1, parseInt(req.query.limit as string) || 20);
    const search = req.query.search as string | undefined;
    const result = await adminService.listUsers(page, limit, search);
    res.json({ ...result, page, limit });
  } catch (err) { next(err); }
});

adminRouter.get('/users/:id', auth, admin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = await adminService.getUserById(req.params.id);
    res.json(user);
  } catch (err) { next(err); }
});

adminRouter.patch('/users/:id/status', auth, admin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const requesterId = (req.user as { sub: string }).sub;
    const result = await adminService.setUserStatus(req.params.id, requesterId, req.body.is_active);
    res.json(result);
  } catch (err) { next(err); }
});

// ── System Stats ───────────────────────────────────────────────────────────

adminRouter.get('/stats/overview', auth, superAdmin, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    res.json(await adminService.getOverviewStats());
  } catch (err) { next(err); }
});

adminRouter.get('/stats/activity', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const from = new Date(req.query.from as string);
    const to = new Date(req.query.to as string);
    res.json(await adminService.getActivityStats(from, to));
  } catch (err) { next(err); }
});

// ── Error Logs ─────────────────────────────────────────────────────────────

adminRouter.get('/logs/errors', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const referenceId = req.query.reference_id as string | undefined;
    if (referenceId) {
      const record = await errorLogRepo.findByReferenceId(referenceId);
      if (!record) {
        res.status(404).json({ error: 'Error no encontrado' });
        return;
      }
      res.json({ data: [record] });
      return;
    }
    const data = await errorLogRepo.findRecent(100);
    res.json({ data });
  } catch (err) { next(err); }
});

// ── Audit Logs ─────────────────────────────────────────────────────────────

adminRouter.get('/logs/audit', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.query.user_id as string | undefined;
    const action = req.query.action as string | undefined;

    const conditions: string[] = [];
    const params: unknown[] = [];

    if (userId) { params.push(userId); conditions.push(`user_id = $${params.length}`); }
    if (action) { params.push(action); conditions.push(`action = $${params.length}`); }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
    const { rows } = await pool.query(
      `SELECT * FROM audit_logs ${where} ORDER BY created_at DESC LIMIT 200`,
      params,
    );
    res.json({ data: rows });
  } catch (err) { next(err); }
});

// ── Tariffs ────────────────────────────────────────────────────────────────

adminRouter.get('/tariffs', auth, superAdmin, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    res.json(await tariffService.getTariff());
  } catch (err) { next(err); }
});

adminRouter.put('/tariffs', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = (req.user as { sub: string }).sub;
    res.json(await tariffService.updateTariff(req.body, adminId));
  } catch (err) { next(err); }
});

// ── Bank Accounts ──────────────────────────────────────────────────────────

adminRouter.get('/bank-accounts', auth, superAdmin, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    res.json({ data: await bankAccountService.findAll() });
  } catch (err) { next(err); }
});

adminRouter.post('/bank-accounts', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    res.status(201).json(await bankAccountService.create(req.body));
  } catch (err) { next(err); }
});

adminRouter.put('/bank-accounts/:id', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    res.json(await bankAccountService.update(req.params.id, req.body));
  } catch (err) { next(err); }
});

adminRouter.patch('/bank-accounts/:id/status', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    res.json(await bankAccountService.setStatus(req.params.id, req.body.is_active));
  } catch (err) { next(err); }
});

adminRouter.delete('/bank-accounts/:id', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    await bankAccountService.deleteById(req.params.id);
    res.status(204).send();
  } catch (err) { next(err); }
});

// ── Predefined Messages ────────────────────────────────────────────────────

adminRouter.get('/messages', auth, admin, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    res.json({ data: await messageService.findAll() });
  } catch (err) { next(err); }
});

adminRouter.get('/messages/:id', auth, admin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    res.json(await messageService.findById(req.params.id));
  } catch (err) { next(err); }
});

adminRouter.post('/messages', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    res.status(201).json(await messageService.create(req.body));
  } catch (err) { next(err); }
});

adminRouter.put('/messages/:id', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    res.json(await messageService.update(req.params.id, req.body));
  } catch (err) { next(err); }
});

adminRouter.delete('/messages/:id', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    await messageService.deleteById(req.params.id);
    res.status(204).send();
  } catch (err) { next(err); }
});

adminRouter.patch('/messages/:id/status', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    res.json(await messageService.setStatus(req.params.id, req.body.is_active));
  } catch (err) { next(err); }
});

// ── OAuth Providers ────────────────────────────────────────────────────────

adminRouter.get('/oauth', auth, superAdmin, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    res.json({ data: await oauthService.getProviders() });
  } catch (err) { next(err); }
});

adminRouter.put('/oauth/:provider', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = (req.user as { sub: string }).sub;
    res.json(await oauthService.updateProvider(req.params.provider, req.body, adminId));
  } catch (err) { next(err); }
});

adminRouter.patch('/oauth/:provider/status', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    res.json(await oauthService.setProviderStatus(req.params.provider, req.body.is_active));
  } catch (err) { next(err); }
});

// ── Commitment Contracts (Admin) ───────────────────────────────────────────

adminRouter.get('/commitment/contracts', auth, admin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.max(1, parseInt(req.query.limit as string) || 20);
    const search = req.query.search as string | undefined;
    const result = await commitmentRepo.listContractsFixed(page, limit, search);
    res.json({ ...result, page, limit });
  } catch (err) { next(err); }
});

adminRouter.get('/commitment/contracts/:id', auth, admin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const contract = await commitmentRepo.findById(req.params.id);
    if (!contract) {
      res.status(404).json({ error: 'Contrato no encontrado' });
      return;
    }
    res.json(contract);
  } catch (err) { next(err); }
});

adminRouter.get('/commitment/contracts/:id/report', auth, admin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminUserId = (req.user as { sub: string }).sub;
    const report = await commitmentService.generateReport(req.params.id, adminUserId, true);
    res.json({ report });
  } catch (err) { next(err); }
});

// ── Reporting ──────────────────────────────────────────────────────────────

adminRouter.get('/reports/contracts-by-user-date', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const from = req.query.from ? new Date(req.query.from as string) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const to = req.query.to ? new Date(req.query.to as string) : new Date();

    const { rows } = await pool.query(
      `SELECT u.full_name, u.email, DATE(c.signed_at) as date, COUNT(*) as contracts
       FROM commitment_contracts c
       JOIN users u ON c.user_id = u.id
       WHERE c.signed_at >= $1 AND c.signed_at < $2
       GROUP BY u.id, u.full_name, u.email, DATE(c.signed_at)
       ORDER BY date DESC, u.full_name`,
      [from, to],
    );
    res.json({ data: rows, from, to });
  } catch (err) { next(err); }
});

adminRouter.get('/reports/hits-by-contract', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const from = req.query.from ? new Date(req.query.from as string) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const to = req.query.to ? new Date(req.query.to as string) : new Date();

    // Assuming hits are plays with source 'pull_10' that match historical results
    // This is a simplified version; in reality, you'd need to check if numbers match lottery results
    const { rows } = await pool.query(
      `SELECT c.id as contract_id, u.full_name, u.email, DATE(c.signed_at) as contract_date, COUNT(p.id) as hits
       FROM commitment_contracts c
       JOIN users u ON c.user_id = u.id
       LEFT JOIN plays p ON p.user_id = c.user_id AND p.source = 'pull_10' AND p.created_at >= c.signed_at
       WHERE c.signed_at >= $1 AND c.signed_at < $2
       GROUP BY c.id, u.full_name, u.email, DATE(c.signed_at)
       ORDER BY contract_date DESC, u.full_name`,
      [from, to],
    );
    res.json({ data: rows, from, to });
  } catch (err) { next(err); }
});

adminRouter.get('/reports/contracts-detailed', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.query.user_id as string | undefined;
    if (!userId) {
      res.status(400).json({ error: 'El parámetro user_id es requerido' });
      return;
    }

    const from = req.query.from ? new Date(req.query.from as string) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const to = req.query.to ? new Date(req.query.to as string) : new Date();
    const toInclusive = new Date(to);
    toInclusive.setHours(23, 59, 59, 999);

    const report = await commitmentRepo.getContractsDetailedReport(
      userId,
      from.toISOString(),
      toInclusive.toISOString(),
    );

    res.json({
      report_type: 'commitment_contract_detailed',
      generated_at: new Date().toISOString(),
      user_id: userId,
      user_email: report.length ? report[0].user_email : null,
      from: from.toISOString(),
      to: toInclusive.toISOString(),
      contracts: report,
    });
  } catch (err) { next(err); }
});

// ── Lotteries Catalog ──────────────────────────────────────────────────────

// GET /admin/lotteries — list all (superAdmin)
adminRouter.get('/lotteries', auth, superAdmin, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    res.json({ data: await lotteryCatalog.findAll() });
  } catch (err) { next(err); }
});

// GET /lotteries — list active (any authenticated user)
// Mounted separately in app.ts

// POST /admin/lotteries — create (superAdmin)
adminRouter.post('/lotteries', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    res.status(201).json(await lotteryCatalog.create(req.body));
  } catch (err) { next(err); }
});

// PUT /admin/lotteries/:id — update (superAdmin)
adminRouter.put('/lotteries/:id', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const updated = await lotteryCatalog.update(req.params.id, req.body);
    if (!updated) { res.status(404).json({ error: 'Lotería no encontrada' }); return; }
    res.json(updated);
  } catch (err) { next(err); }
});

// PATCH /admin/lotteries/:id/status — activate/deactivate (superAdmin)
adminRouter.patch('/lotteries/:id/status', auth, superAdmin, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const updated = await lotteryCatalog.setStatus(req.params.id, req.body.is_active);
    if (!updated) { res.status(404).json({ error: 'Lotería no encontrada' }); return; }
    res.json(updated);
  } catch (err) { next(err); }
});
