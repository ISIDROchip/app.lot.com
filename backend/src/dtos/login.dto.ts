import { body, ValidationChain } from 'express-validator';

export interface LoginDto {
  email: string;
  password: string;
}

export const loginValidation: ValidationChain[] = [
  body('email').isEmail().withMessage('Email inválido'),
  body('password').notEmpty().withMessage('La contraseña es requerida'),
];
