import { body, ValidationChain } from 'express-validator';
import { TipoJugada } from '../types';

export interface LotteryRequestDto {
  tipo: TipoJugada;
}

export const lotteryValidation: ValidationChain[] = [
  body('tipo')
    .isIn(['Loto', 'Pale', 'Tripleta', 'Número'])
    .withMessage('tipo debe ser uno de: Loto, Pale, Tripleta, Número'),
];
