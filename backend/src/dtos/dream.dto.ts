import { body, ValidationChain } from 'express-validator';

export interface DreamDto {
  dreamText: string;
}

export const dreamValidation: ValidationChain[] = [
  body('dreamText')
    .isLength({ min: 10, max: 2000 })
    .withMessage('La descripción del sueño debe tener entre 10 y 2000 caracteres'),
];
