import axios from 'axios';
import { config } from '../config/env';
import { AppError } from '../middlewares/errorHandler';
import { saveDreamInterpretation, getLastDreamInterpretation } from '../repositories/lottery.repository';

export interface DreamResult {
  numbers: number[];
  keywords: string[];
}

export async function interpret(dreamText: string, userId: string): Promise<DreamResult> {
  // Check daily limit
  const lastDateStr = await getLastDreamInterpretation(userId);
  if (lastDateStr) {
    const lastDate = new Date(lastDateStr);
    const today = new Date();
    if (
      lastDate.getDate() === today.getDate() &&
      lastDate.getMonth() === today.getMonth() &&
      lastDate.getFullYear() === today.getFullYear()
    ) {
      throw new AppError('Solo puedes realizar una interpretación de sueño por día.', 'DREAM_LIMIT_REACHED', 429);
    }
  }

  try {
    const { data } = await axios.post<DreamResult>(
      `${config.aiServiceUrl}/interpret`,
      { text: dreamText },
      {
        headers: { 'X-API-Key': config.aiServiceApiKey },
        timeout: 5000,
      },
    );
    await saveDreamInterpretation(userId, dreamText, data.numbers, data.keywords);
    return data;
  } catch (err: unknown) {
    if (axios.isAxiosError(err) && err.response) {
      throw new AppError(
        (err.response.data as { detail?: string })?.detail ?? 'Error en servicio de sueños',
        'DREAM_SERVICE_ERROR',
        err.response.status,
      );
    }
    throw new AppError('El servicio de interpretación no está disponible', 'DREAM_SERVICE_DOWN', 503);
  }
}
