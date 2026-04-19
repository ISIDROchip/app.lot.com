import { body, ValidationChain } from 'express-validator';

export interface HistoricalResultDto {
  drawDate: string; // ISO 8601
  numbers: number[];
}

export interface UploadResultsDto {
  results: HistoricalResultDto[];
}

export const statsUploadValidation: ValidationChain[] = [
  body('results').isArray().withMessage('results debe ser un array'),
  body('results.*.drawDate').isISO8601().withMessage('drawDate debe estar en formato ISO 8601'),
  body('results.*.numbers').isArray().withMessage('numbers debe ser un array'),
];
