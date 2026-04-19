import { body, ValidationChain } from 'express-validator';

export interface RegisterDto {
  fullName: string;
  birthDate: string; // ISO 8601
  email: string;
  phone: string;
  password: string;
}

export const registerValidation: ValidationChain[] = [
  body('email').isEmail().withMessage('Email inválido'),
  body('phone')
    .isLength({ min: 8, max: 15 }).withMessage('El teléfono debe tener entre 8 y 15 dígitos')
    .isNumeric().withMessage('El teléfono solo debe contener dígitos'),
  body('password').notEmpty().withMessage('La contraseña es requerida'),
  body('fullName').notEmpty().withMessage('El nombre completo es requerido'),
  body('birthDate').isISO8601().withMessage('La fecha de nacimiento debe estar en formato ISO 8601'),
];
