import { pool } from '../config/database';
import { CommitmentContract, CommitmentSignature } from '../types';
import { SignContractDto } from '../dtos/commitment.dto';

export async function createContract(
  dto: SignContractDto,
  userId: string,
  ip: string | null,
  version: string,
): Promise<{ id: string; signed_at: string }> {
  const { rows } = await pool.query<{ id: string; signed_at: string }>(
    `INSERT INTO commitment_contracts
       (user_id, first_name, last_name, address, cedula, phone,
        checkbox_acceptance, contract_version, ip_address, status,
        photo_data, latitude, longitude, location_address)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'signed',$10,$11,$12,$13)
     RETURNING id, signed_at`,
    [
      userId,
      dto.first_name,
      dto.last_name,
      dto.address,
      dto.cedula,
      dto.phone,
      dto.checkbox_acceptance,
      version,
      ip,
      dto.photo_data ?? null,
      dto.latitude ?? null,
      dto.longitude ?? null,
      dto.location_address ?? null,
    ],
  );
  return rows[0];
}

export async function createSignature(
  contractId: string,
  signatureData: string,
  systemSignatureData?: string,
): Promise<void> {
  await pool.query(
    `INSERT INTO commitment_signatures (contract_id, signature_data, system_signature_data)
     VALUES ($1, $2, $3)`,
    [contractId, signatureData, systemSignatureData ?? null],
  );
}

export async function findLatestByUser(userId: string): Promise<CommitmentContract | null> {
  const { rows } = await pool.query<CommitmentContract>(
    `SELECT id, user_id, first_name, last_name, address, cedula, phone,
            checkbox_acceptance, contract_version, ip_address::text AS ip_address,
            status, signed_at, created_at
     FROM commitment_contracts
     WHERE user_id = $1
     ORDER BY signed_at DESC
     LIMIT 1`,
    [userId],
  );
  return rows[0] ?? null;
}

export async function findValidContract(
  userId: string,
  currentVersion: string,
): Promise<CommitmentContract | null> {
  const { rows } = await pool.query<CommitmentContract>(
    `SELECT c.id, c.user_id, c.first_name, c.last_name, c.address, c.cedula, c.phone,
            c.checkbox_acceptance, c.contract_version, c.ip_address::text AS ip_address,
            c.status, c.signed_at, c.created_at
     FROM commitment_contracts c
     INNER JOIN commitment_signatures s ON s.contract_id = c.id
     WHERE c.user_id = $1
       AND c.status = 'signed'
       AND c.contract_version = $2
       AND c.signed_at > NOW() - INTERVAL '30 days'
     ORDER BY c.signed_at DESC
     LIMIT 1`,
    [userId, currentVersion],
  );
  return rows[0] ?? null;
}

export async function findContractByIdAndUser(
  contractId: string,
  userId: string,
  currentVersion: string,
): Promise<CommitmentContract | null> {
  const { rows } = await pool.query<CommitmentContract>(
    `SELECT c.id, c.user_id, c.first_name, c.last_name, c.address, c.cedula, c.phone,
            c.checkbox_acceptance, c.contract_version, c.ip_address::text AS ip_address,
            c.status, c.signed_at, c.created_at
     FROM commitment_contracts c
     INNER JOIN commitment_signatures s ON s.contract_id = c.id
     WHERE c.id = $1
       AND c.user_id = $2
       AND c.status = 'signed'
       AND c.contract_version = $3
       AND c.signed_at > NOW() - INTERVAL '30 days'
     LIMIT 1`,
    [contractId, userId, currentVersion],
  );
  return rows[0] ?? null;
}

export async function findById(
  contractId: string,
): Promise<(CommitmentContract & { signature: CommitmentSignature | null }) | null> {
  const { rows } = await pool.query<CommitmentContract & {
    sig_id: string | null;
    signature_data: string | null;
    sig_created_at: string | null;
  }>(
    `SELECT c.id, c.user_id, c.first_name, c.last_name, c.address, c.cedula, c.phone,
            c.checkbox_acceptance, c.contract_version, c.ip_address::text AS ip_address,
            c.status, c.signed_at, c.created_at,
            s.id AS sig_id, s.signature_data, s.created_at AS sig_created_at
     FROM commitment_contracts c
     LEFT JOIN commitment_signatures s ON s.contract_id = c.id
     WHERE c.id = $1`,
    [contractId],
  );
  if (!rows[0]) return null;
  const row = rows[0];
  const signature: CommitmentSignature | null = row.sig_id
    ? { id: row.sig_id, contract_id: row.id, signature_data: row.signature_data!, created_at: row.sig_created_at! }
    : null;
  return {
    id: row.id,
    user_id: row.user_id,
    first_name: row.first_name,
    last_name: row.last_name,
    address: row.address,
    cedula: row.cedula,
    phone: row.phone,
    checkbox_acceptance: row.checkbox_acceptance,
    contract_version: row.contract_version,
    ip_address: row.ip_address,
    status: row.status,
    signed_at: row.signed_at,
    created_at: row.created_at,
    signature,
  };
}

export interface ContractListItem {
  id: string;
  user_id: string;
  first_name: string;
  last_name: string;
  cedula: string;
  contract_version: string;
  status: string;
  signed_at: string;
  created_at: string;
}

export async function listContracts(
  page: number,
  limit: number,
  search?: string,
): Promise<{ data: ContractListItem[]; total: number }> {
  const offset = (page - 1) * limit;
  const params: unknown[] = [limit, offset];
  let where = '';

  if (search) {
    params.push(`%${search}%`);
    const idx = params.length;
    where = `WHERE cedula ILIKE $${idx} OR first_name ILIKE $${idx} OR last_name ILIKE $${idx}`;
  }

  const { rows } = await pool.query<ContractListItem>(
    `SELECT id, user_id, first_name, last_name, cedula, contract_version, status, signed_at, created_at
     FROM commitment_contracts
     ${where}
     ORDER BY signed_at DESC
     LIMIT $1 OFFSET $2`,
    params,
  );

  const { rows: countRows } = await pool.query<{ total: string }>(
    `SELECT COUNT(*) AS total FROM commitment_contracts ${where}`,
    search ? [params[2]] : [],
  );

  return { data: rows, total: parseInt(countRows[0].total, 10) };
}

// NOTE: listContracts above has a bug in the WHERE clause (missing $ prefix).
// The corrected version is used by the admin controller via a direct query below.
export async function listContractsFixed(
  page: number,
  limit: number,
  search?: string,
): Promise<{ data: ContractListItem[]; total: number }> {
  const offset = (page - 1) * limit;

  if (search) {
    const pattern = `%${search}%`;
    const { rows } = await pool.query<ContractListItem>(
      `SELECT id, user_id, first_name, last_name, cedula, contract_version, status, signed_at, created_at
       FROM commitment_contracts
       WHERE cedula ILIKE $3 OR first_name ILIKE $3 OR last_name ILIKE $3
       ORDER BY signed_at DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset, pattern],
    );
    const { rows: countRows } = await pool.query<{ total: string }>(
      `SELECT COUNT(*) AS total FROM commitment_contracts
       WHERE cedula ILIKE $1 OR first_name ILIKE $1 OR last_name ILIKE $1`,
      [pattern],
    );
    return { data: rows, total: parseInt(countRows[0].total, 10) };
  }

  const { rows } = await pool.query<ContractListItem>(
    `SELECT id, user_id, first_name, last_name, cedula, contract_version, status, signed_at, created_at
     FROM commitment_contracts
     ORDER BY signed_at DESC
     LIMIT $1 OFFSET $2`,
    [limit, offset],
  );
  const { rows: countRows } = await pool.query<{ total: string }>(
    `SELECT COUNT(*) AS total FROM commitment_contracts`,
  );
  return { data: rows, total: parseInt(countRows[0].total, 10) };
}

export interface ContractPullReportItem {
  id: string;
  numbers: number[];
  play_type: string;
  source: string;
  created_at: string;
  matched_numbers: number[];
  matched_count: number;
  is_winner: boolean;
}

export interface ContractDetailedReport {
  contract_id: string;
  user_id: string;
  user_full_name: string;
  user_email: string;
  first_name: string;
  last_name: string;
  address: string;
  cedula: string;
  phone: string;
  checkbox_acceptance: boolean;
  contract_version: string;
  ip_address: string | null;
  status: string;
  signed_at: string;
  created_at: string;
  photo_data: string | null;
  latitude: number | null;
  longitude: number | null;
  location_address: string | null;
  signature_data: string | null;
  pulls: ContractPullReportItem[];
}

export async function getContractsDetailedReport(
  userId: string,
  fromDate: string,
  toDate: string,
): Promise<ContractDetailedReport[]> {
  const { rows: historicalRows } = await pool.query<{ numbers: number[] }>(
    `SELECT numbers FROM historical_results`,
  );
  const allDrawnNumbers = new Set<number>(historicalRows.flatMap(r => r.numbers));

  const { rows } = await pool.query<{
    contract_id: string;
    user_id: string;
    user_full_name: string;
    user_email: string;
    first_name: string;
    last_name: string;
    address: string;
    cedula: string;
    phone: string;
    checkbox_acceptance: boolean;
    contract_version: string;
    ip_address: string | null;
    status: string;
    signed_at: string;
    contract_created_at: string;
    photo_data: string | null;
    latitude: number | null;
    longitude: number | null;
    location_address: string | null;
    signature_data: string | null;
    play_id: string | null;
    play_numbers: number[] | null;
    play_type: string | null;
    play_source: string | null;
    play_created_at: string | null;
  }>(
    `SELECT
       c.id AS contract_id,
       c.user_id,
       u.full_name AS user_full_name,
       u.email AS user_email,
       c.first_name,
       c.last_name,
       c.address,
       c.cedula,
       c.phone,
       c.checkbox_acceptance,
       c.contract_version,
       c.ip_address::text AS ip_address,
       c.status,
       c.signed_at,
       c.created_at AS contract_created_at,
       c.photo_data,
       c.latitude,
       c.longitude,
       c.location_address,
       s.signature_data,
       p.id AS play_id,
       p.numbers AS play_numbers,
       p.play_type,
       p.source AS play_source,
       p.created_at AS play_created_at
     FROM commitment_contracts c
     JOIN users u ON u.id = c.user_id
     LEFT JOIN commitment_signatures s ON s.contract_id = c.id
     LEFT JOIN plays p ON p.user_id = c.user_id
       AND p.source = 'pull_10'
       AND p.created_at >= c.signed_at
       AND p.created_at < c.signed_at + INTERVAL '30 days'
     WHERE c.user_id = $1
       AND c.signed_at >= $2
       AND c.signed_at <= $3
     ORDER BY c.signed_at DESC, p.created_at ASC`,
    [userId, fromDate, toDate],
  );

  const grouped = new Map<string, ContractDetailedReport>();

  for (const row of rows) {
    let contract = grouped.get(row.contract_id);
    if (!contract) {
      contract = {
        contract_id: row.contract_id,
        user_id: row.user_id,
        user_full_name: row.user_full_name,
        user_email: row.user_email,
        first_name: row.first_name,
        last_name: row.last_name,
        address: row.address,
        cedula: row.cedula,
        phone: row.phone,
        checkbox_acceptance: row.checkbox_acceptance,
        contract_version: row.contract_version,
        ip_address: row.ip_address,
        status: row.status,
        signed_at: row.signed_at,
        created_at: row.contract_created_at,
        photo_data: row.photo_data,
        latitude: row.latitude,
        longitude: row.longitude,
        location_address: row.location_address,
        signature_data: row.signature_data,
        pulls: [],
      };
      grouped.set(row.contract_id, contract);
    }

    if (row.play_id && row.play_numbers) {
      const matchedNumbers = row.play_numbers.filter(n => allDrawnNumbers.has(n));
      contract.pulls.push({
        id: row.play_id,
        numbers: row.play_numbers,
        play_type: row.play_type ?? 'pull_10',
        source: row.play_source ?? 'pull_10',
        created_at: row.play_created_at ?? '',
        matched_numbers: matchedNumbers,
        matched_count: matchedNumbers.length,
        is_winner: matchedNumbers.length === row.play_numbers.length && row.play_numbers.length > 0,
      });
    }
  }

  return Array.from(grouped.values());
}
