/**
 * scraper.service.ts
 *
 * Scraper parametrizado de resultados de lotería.
 * Flujo (igual que LTFree):
 *   1. BORRAR historical_results para la lotería y rango de fechas
 *   2. INSERTAR nuevos resultados scrapeados
 *   3. BORRAR tablas del motor (lot_number_frequency, lot_number_cycles, etc.)
 *   4. RECALCULAR todas las tablas del motor desde historical_results
 */

import axios from 'axios';
import * as cheerio from 'cheerio';
import { pool } from '../config/database';
import { syncEngineTablesFromHistory } from '../repositories/engine.repository';

export interface ScraperParams {
  baseUrl: string;
  dateFrom: string;         // YYYY-MM-DD
  dateTo: string;           // YYYY-MM-DD
  weekDays: number[];       // 0=Dom..6=Sab (default [3,6])
  delayMs: number;
  uploadedBy?: string;
  lotteryId?: string;       // UUID de la lotería — si se provee, filtra por ella
  numberRange?: number;     // rango máximo de números (default 40)
}

export interface ScraperProgress {
  total: number;
  processed: number;
  inserted: number;
  skipped: number;
  errors: number;
  currentDate: string;
  status: 'running' | 'completed' | 'error';
  messages: string[];
}

const progressStore = new Map<string, ScraperProgress>();

export function getProgress(jobId: string): ScraperProgress | null {
  return progressStore.get(jobId) ?? null;
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

function getSorteoDates(from: Date, to: Date, weekDays: number[]): Date[] {
  const dates: Date[] = [];
  const current = new Date(from);
  while (current <= to) {
    if (weekDays.includes(current.getDay())) dates.push(new Date(current));
    current.setDate(current.getDate() + 1);
  }
  return dates;
}

function formatDateParam(d: Date): string {
  const dd = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  return `${dd}-${mm}-${d.getFullYear()}`;
}

function parseNumbers(text: string, targetDate: Date, maxRange: number): number[] | null {
  const ddmm = `${String(targetDate.getDate()).padStart(2, '0')}-${String(targetDate.getMonth() + 1).padStart(2, '0')}`;
  const lines = text.split('\n').map(l => l.trim()).filter(Boolean);
  let foundDate = false;
  const numbers: number[] = [];

  for (const line of lines) {
    if (!foundDate && line.includes(ddmm)) { foundDate = true; continue; }
    if (foundDate) {
      if (/^\d{1,2}$/.test(line)) {
        const n = parseInt(line, 10);
        if (n >= 1 && n <= maxRange) numbers.push(n);
      }
      if (numbers.length >= 6) break;
    }
  }
  return numbers.length >= 6 ? numbers.slice(0, 6) : null;
}

async function fetchPage(url: string): Promise<string> {
  const res = await axios.get(url, {
    timeout: 30000,
    headers: { 'User-Agent': 'Mozilla/5.0 Chrome/120.0.0.0 Safari/537.36' },
  });
  const $ = cheerio.load(res.data as string);
  let text = '';
  $('body').find('*').each((_, el) => {
    const t = $(el).clone().children().remove().end().text().trim();
    if (t) text += t + '\n';
  });
  return text || $('body').text();
}

// ─────────────────────────────────────────────────────────────────────────────
// CLEAR — borra historical_results y tablas del motor para la lotería
// Equivalente a: DELETE FROM gt3; DELETE FROM CumplenConReglas; (LTFree)
// ─────────────────────────────────────────────────────────────────────────────

async function clearLotteryData(lotteryId: string | undefined, progress: ScraperProgress): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    if (lotteryId) {
      // Borrar solo los datos de esta lotería específica
      const { rowCount: hrDeleted } = await client.query(
        `DELETE FROM historical_results WHERE lottery_id = $1`, [lotteryId],
      );
      progress.messages.push(`🗑 Borrados ${hrDeleted ?? 0} registros de historical_results para esta lotería`);

      // Borrar tablas del motor para esta lotería
      await client.query(`DELETE FROM lot_number_frequency   WHERE lottery_id = $1`, [lotteryId]);
      await client.query(`DELETE FROM lot_number_cycles      WHERE lottery_id = $1`, [lotteryId]);
      await client.query(`DELETE FROM lot_pair_frequency     WHERE lottery_id = $1`, [lotteryId]);
      await client.query(`DELETE FROM lot_position_frequency WHERE lottery_id = $1`, [lotteryId]);
      await client.query(`DELETE FROM lot_generated_combinations WHERE lottery_id = $1`, [lotteryId]);
    } else {
      // Sin lottery_id: borrar todos los registros sin lotería asignada
      const { rowCount: hrDeleted } = await client.query(
        `DELETE FROM historical_results WHERE lottery_id IS NULL`,
      );
      progress.messages.push(`🗑 Borrados ${hrDeleted ?? 0} registros de historical_results (sin lotería)`);

      await client.query(`DELETE FROM lot_number_frequency   WHERE lottery_id IS NULL`);
      await client.query(`DELETE FROM lot_number_cycles      WHERE lottery_id IS NULL`);
      await client.query(`DELETE FROM lot_pair_frequency     WHERE lottery_id IS NULL`);
      await client.query(`DELETE FROM lot_position_frequency WHERE lottery_id IS NULL`);
      await client.query(`DELETE FROM lot_generated_combinations WHERE lottery_id IS NULL`);
    }

    await client.query('COMMIT');
    progress.messages.push(`✅ Tablas limpiadas — listo para carga fresca`);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCRAPER
// ─────────────────────────────────────────────────────────────────────────────

export async function runScraper(jobId: string, params: ScraperParams): Promise<void> {
  const from = new Date(params.dateFrom);
  const to = new Date(params.dateTo);
  const weekDays = params.weekDays.length > 0 ? params.weekDays : [3, 6];
  const delay = params.delayMs ?? 1500;
  const maxRange = params.numberRange ?? 40;
  const dates = getSorteoDates(from, to, weekDays);

  const progress: ScraperProgress = {
    total: dates.length,
    processed: 0,
    inserted: 0,
    skipped: 0,
    errors: 0,
    currentDate: '',
    status: 'running',
    messages: [`Iniciando scraper: ${dates.length} fechas (${params.dateFrom} → ${params.dateTo})`],
  };
  progressStore.set(jobId, progress);

  try {
    // PASO 1: Limpiar datos anteriores (como LTFree borraba gt3 y CumplenConReglas)
    progress.messages.push(`Limpiando datos anteriores...`);
    progressStore.set(jobId, { ...progress });
    await clearLotteryData(params.lotteryId, progress);
    progressStore.set(jobId, { ...progress });

    // PASO 2: Scrapear e insertar
    for (const d of dates) {
      const dateParam = formatDateParam(d);
      const isoDate = d.toISOString().split('T')[0];
      const url = `${params.baseUrl.replace(/\/$/, '')}?date=${dateParam}`;

      progress.currentDate = isoDate;
      progress.messages.push(`[${progress.processed + 1}/${progress.total}] ${isoDate}`);

      try {
        const text = await fetchPage(url);
        const numbers = parseNumbers(text, d, maxRange);

        if (numbers) {
          await pool.query(
            `INSERT INTO historical_results (draw_date, numbers, uploaded_by, lottery_id)
             VALUES ($1, $2, $3, $4)`,
            [isoDate, numbers, params.uploadedBy ?? null, params.lotteryId ?? null],
          );
          progress.inserted++;
          progress.messages.push(`  ✓ ${numbers.join('-')}`);
        } else {
          progress.skipped++;
          progress.messages.push(`  ⚠ Sin datos`);
        }
      } catch (err) {
        progress.errors++;
        progress.messages.push(`  ✗ ${err instanceof Error ? err.message : 'error'}`);
      }

      progress.processed++;
      progressStore.set(jobId, { ...progress });

      if (progress.messages.length > 150) {
        progress.messages = progress.messages.slice(-150);
      }

      await new Promise(r => setTimeout(r, delay));
    }

    // PASO 3: Recalcular TODAS las tablas del motor desde cero
    // Equivalente a ejecutar todos los SPs de LTFree en secuencia
    progress.messages.push(`Recalculando motor estadístico desde cero...`);
    progressStore.set(jobId, { ...progress });
    await syncEngineTablesFromHistory(params.lotteryId);
    progress.messages.push(`✅ Motor estadístico recalculado`);
    progress.messages.push(`  → lot_number_frequency actualizada`);
    progress.messages.push(`  → lot_number_cycles actualizada`);
    progress.messages.push(`  → lot_pair_frequency actualizada`);
    progress.messages.push(`  → lot_position_frequency actualizada`);

    progress.status = 'completed';
    progress.messages.push(
      `✅ Completado: ${progress.inserted} insertados, ${progress.skipped} omitidos, ${progress.errors} errores`,
    );
  } catch (err) {
    progress.status = 'error';
    progress.messages.push(`❌ Error fatal: ${err instanceof Error ? err.message : 'desconocido'}`);
  }

  progressStore.set(jobId, { ...progress });
  setTimeout(() => progressStore.delete(jobId), 60 * 60 * 1000);
}
