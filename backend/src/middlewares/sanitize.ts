import { Request, Response, NextFunction } from 'express';

const REPLACEMENTS: [RegExp, string][] = [
  [/</g, '&lt;'],
  [/>/g, '&gt;'],
  [/"/g, '&quot;'],
  [/'/g, '&#x27;'],
  [/;/g, '&#59;'],
  [/--/g, '&#45;&#45;'],
  [/\/\*/g, '&#47;&#42;'],
  [/\*\//g, '&#42;&#47;'],
];

function sanitizeValue(value: unknown): unknown {
  if (typeof value === 'string') {
    return REPLACEMENTS.reduce<string>((str, [pattern, replacement]) => str.replace(pattern, replacement), value);
  }
  if (Array.isArray(value)) return value.map(sanitizeValue);
  if (value !== null && typeof value === 'object') return sanitizeObject(value as Record<string, unknown>);
  return value;
}

function sanitizeObject(obj: Record<string, unknown>): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const key of Object.keys(obj)) result[key] = sanitizeValue(obj[key]);
  return result;
}

export function sanitize(req: Request, _res: Response, next: NextFunction): void {
  if (req.body && typeof req.body === 'object') req.body = sanitizeObject(req.body as Record<string, unknown>);
  if (req.query && typeof req.query === 'object') req.query = sanitizeObject(req.query as Record<string, unknown>) as typeof req.query;
  next();
}
