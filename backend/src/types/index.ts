export type TipoJugada = 'Loto' | 'Pale' | 'Tripleta' | 'Número';

export interface JwtPayload {
  sub: string;
  email: string;
  is_admin: boolean;
  is_super_admin: boolean;
  iat?: number;
  exp?: number;
}

export interface JugadaResult {
  id: string;
  tipo: TipoJugada;
  numbers: number[];
  timestamp: string;
  remaining?: number;  // jugadas restantes del día para este tipo
}

export interface FrequencyRecord {
  number: number;
  count: number;
}

export interface HistoryRecord {
  id: string;
  type: 'play' | 'dream';
  numbers: number[];
  createdAt: string;
  meta?: Record<string, unknown>;
}

export interface AdminUserRecord {
  id: string;
  full_name: string;
  email: string;
  phone: string;
  is_active: boolean;
  is_admin: boolean;
  is_super_admin: boolean;
  created_at: string;
}

export interface AppError extends Error {
  statusCode?: number;
  code?: string;
}

// ── Commitment Form Signature ──────────────────────────────────────────────

export type ContractStatus = 'none' | 'signed' | 'expired' | 'outdated';

export interface CommitmentContract {
  id: string;
  user_id: string;
  first_name: string;
  last_name: string;
  address: string;
  cedula: string;
  phone: string;
  checkbox_acceptance: boolean;
  contract_version: string;
  ip_address: string | null;
  status: 'pending' | 'signed' | 'expired';
  signed_at: string;
  created_at: string;
}

export interface CommitmentSignature {
  id: string;
  contract_id: string;
  signature_data: string;
  created_at: string;
}

export interface ContractStatusResponse {
  status: ContractStatus;
  can_pull: boolean;
  contract_id?: string;
  signed_at?: string;
  contract_version?: string;
}

export interface Pull10Result {
  combinations: number[][];
  lottery_id: string | null;
  timestamp: string;
  contract_id?: string | null;
}

// ── Multi-Lottery Support ──────────────────────────────────────────────────

export interface Lottery {
  id: string;
  name: string;
  short_name: string;
  country: string;
  numbers_count: number;
  number_range: number;
  draw_days: number[];
  scraper_url: string | null;
  is_active: boolean;
  created_at: string;
}
