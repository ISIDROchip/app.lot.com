export interface SignContractDto {
  first_name: string;
  last_name: string;
  address: string;
  cedula: string;
  phone: string;
  digital_signature: string;
  checkbox_acceptance: boolean;
  photo_data?: string;          // foto del firmante en Base64
  latitude?: number;            // coordenadas GPS
  longitude?: number;
  location_address?: string;    // dirección legible del GPS
}

export interface ContractFieldDef {
  name: string;
  label: string;
  type: 'text' | 'phone';
  required: boolean;
}

export interface ContractTemplateResponse {
  contract_version: string;
  fields: ContractFieldDef[];
  clauses: Array<{ id: string; version: string; text: string }>;
  initial_values?: {
    first_name?: string;
    last_name?: string;
    address?: string;
    cedula?: string;
    phone?: string;
  };
}

export interface ContractReportPayload {
  report_type: 'commitment_contract';
  generated_at: string;
  contract: {
    id: string;
    contract_version: string;
    status: string;
    signed_at: string;
    ip_address: string | null;
    latitude?: number | null;
    longitude?: number | null;
    location_address?: string | null;
  };
  user_data: {
    first_name: string;
    last_name: string;
    address: string;
    cedula: string;
    phone: string;
  };
  clauses: Array<{ id: string; version: string; text: string }>;
  checkbox_acceptance: boolean;
  digital_signature: string;       // firma manual del usuario
  system_signature: string;        // firma generada por el sistema
  photo_data?: string | null;      // foto del firmante
}

export interface ContractPullItem {
  id: string;
  numbers: number[];
  play_type: string;
  source: string;
  created_at: string;
  matched_numbers: number[];
  matched_count: number;
  is_winner: boolean;
}

export interface ContractDetailedReportPayload {
  report_type: 'commitment_contract_detailed';
  generated_at: string;
  user_id: string;
  user_full_name: string;
  user_email: string;
  filters: {
    from: string;
    to: string;
  };
  contracts: Array<{
    contract_id: string;
    contract_version: string;
    status: string;
    signed_at: string;
    created_at: string;
    ip_address: string | null;
    latitude?: number | null;
    longitude?: number | null;
    location_address?: string | null;
    first_name: string;
    last_name: string;
    address: string;
    cedula: string;
    phone: string;
    checkbox_acceptance: boolean;
    signature_data: string | null;
    photo_data: string | null;
    pulls: ContractPullItem[];
  }>;
}
