import { pool } from '../config/database';
import { createHash } from 'crypto';
import sharp from 'sharp';
import { ContractStatusResponse } from '../types';
import { SignContractDto, ContractTemplateResponse, ContractReportPayload } from '../dtos/commitment.dto';
import * as commitmentRepo from '../repositories/commitment.repository';
import { AppError } from '../middlewares/errorHandler';

// ── Contract version & clauses ─────────────────────────────────────────────

export const CURRENT_CONTRACT_VERSION = 'v1.1';

export const CLAUSES_V1 = [
  {
    id: 'c1',
    version: 'v1.0',
    text: `El usuario se compromete irrevocablemente a pagar el treinta por ciento (30 %) del monto neto de cualquier premio obtenido mediante las combinaciones generadas en el Pull de 10 de Luxora Smart Lottery. Este compromiso aplica a cada combinación individualmente y al conjunto de combinaciones del Pull. El pago deberá realizarse dentro de los cinco (5) días hábiles siguientes a la fecha de cobro del premio, mediante transferencia a las cuentas bancarias oficiales de Luxora indicadas en la aplicación. El incumplimiento de este compromiso podrá resultar en la suspensión del acceso al servicio Pull de 10.`,
  },
];

export const CLAUSES_V11 = [
  {
    id: 'c1',
    version: 'v1.1',
    text: `El usuario acepta los términos de uso del servicio Pull de 10 de Luxora Smart Lottery. El servicio se proporciona con un límite de 20 pulls por usuario en un período de 30 días. Cada pull solicitado requiere verificación de identidad mediante cédula y pago correspondiente.`,
  },
];

// ── Template ───────────────────────────────────────────────────────────────

export async function getTemplate(userId?: string): Promise<ContractTemplateResponse> {
  const template: ContractTemplateResponse = {
    contract_version: CURRENT_CONTRACT_VERSION,
    fields: [
      { name: 'first_name', label: 'Nombre',    type: 'text',  required: true },
      { name: 'last_name',  label: 'Apellido',  type: 'text',  required: true },
      { name: 'address',    label: 'Dirección', type: 'text',  required: true },
      { name: 'cedula',     label: 'Cédula',    type: 'text',  required: true },
      { name: 'phone',      label: 'Teléfono',  type: 'phone', required: true },
    ],
    clauses: CLAUSES_V11,
  };

  if (!userId) {
    return template;
  }

  const latestContract = await commitmentRepo.findLatestByUser(userId);
  if (!latestContract) {
    return template;
  }

  template.initial_values = {
    first_name: latestContract.first_name,
    last_name: latestContract.last_name,
    address: latestContract.address,
    cedula: latestContract.cedula,
    phone: latestContract.phone,
  };

  return template;
}

// ── Status ─────────────────────────────────────────────────────────────────

export async function getStatus(userId: string): Promise<ContractStatusResponse> {
  const validContract = await commitmentRepo.findValidContract(userId, CURRENT_CONTRACT_VERSION);

  if (validContract) {
    return {
      status: 'signed',
      can_pull: true,
      contract_id: validContract.id,
      signed_at: validContract.signed_at,
      contract_version: validContract.contract_version,
    };
  }

  const latestContract = await commitmentRepo.findLatestByUser(userId);
  if (!latestContract) {
    return { status: 'none', can_pull: false };
  }

  if (latestContract.contract_version !== CURRENT_CONTRACT_VERSION) {
    return { status: 'outdated', can_pull: false, contract_version: latestContract.contract_version };
  }

  const signedAt = new Date(latestContract.signed_at);
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

  if (signedAt < thirtyDaysAgo) {
    return { status: 'expired', can_pull: false, contract_version: latestContract.contract_version };
  }

  return { status: 'none', can_pull: false };
}

// ── Validation helpers ─────────────────────────────────────────────────────

const ALPHA_ACCENTS = /^[A-Za-zÀ-ÖØ-öø-ÿ\s]+$/;

function validateFields(dto: SignContractDto): Array<{ field: string; message: string }> {
  const errors: Array<{ field: string; message: string }> = [];

  if (!dto.first_name || dto.first_name.length < 2 || dto.first_name.length > 60 || !ALPHA_ACCENTS.test(dto.first_name)) {
    errors.push({ field: 'first_name', message: 'Debe tener entre 2 y 60 caracteres alfabéticos (acentos y espacios permitidos)' });
  }
  if (!dto.last_name || dto.last_name.length < 2 || dto.last_name.length > 60 || !ALPHA_ACCENTS.test(dto.last_name)) {
    errors.push({ field: 'last_name', message: 'Debe tener entre 2 y 60 caracteres alfabéticos (acentos y espacios permitidos)' });
  }
  if (!dto.address || dto.address.length < 10 || dto.address.length > 255) {
    errors.push({ field: 'address', message: 'Debe tener entre 10 y 255 caracteres' });
  }
  if (!dto.cedula || !/^[A-Za-z0-9]{6,20}$/.test(dto.cedula)) {
    errors.push({ field: 'cedula', message: 'Debe tener entre 6 y 20 caracteres alfanuméricos' });
  }
  if (!dto.phone || !/^\d{8,15}$/.test(dto.phone)) {
    errors.push({ field: 'phone', message: 'Debe tener entre 8 y 15 dígitos numéricos' });
  }

  // Validate digital_signature: non-empty Base64, decoded size >= 1 KB
  if (!dto.digital_signature) {
    errors.push({ field: 'digital_signature', message: 'La firma digital es requerida' });
  } else {
    try {
      const decoded = Buffer.from(dto.digital_signature, 'base64');
      if (decoded.length < 1024) {
        errors.push({ field: 'digital_signature', message: 'La firma digital debe tener un tamaño mínimo de 1 KB' });
      }
    } catch {
      errors.push({ field: 'digital_signature', message: 'La firma digital debe ser una cadena Base64 válida' });
    }
  }

  return errors;
}

async function validatePhoto(photoData: string): Promise<void> {
  if (!photoData) {
    throw new AppError('La foto del firmante es requerida', 'VALIDATION_ERROR', 422);
  }

  try {
    // Decode Base64 to buffer
    const imageBuffer = Buffer.from(photoData, 'base64');

    // Check minimum size (at least 20KB for a decent photo)
    if (imageBuffer.length < 20000) {
      throw new AppError('La foto debe tener un tamaño mínimo de 20 KB', 'VALIDATION_ERROR', 422);
    }

    // Use sharp to read EXIF metadata
    const metadata = await sharp(imageBuffer).metadata();

    // If no EXIF data, assume it's from camera (some devices don't include it)
    if (!metadata.exif) {
      // Still check if it's a reasonable image format
      if (!['jpeg', 'jpg', 'png'].includes(metadata.format?.toLowerCase() || '')) {
        throw new AppError('La foto debe ser una imagen válida (JPEG o PNG)', 'VALIDATION_ERROR', 422);
      }
      return; // Accept without EXIF validation
    }

    // Parse EXIF data
    const exifData = metadata.exif as any;

    // Check DateTimeOriginal or DateTime (when photo was taken)
    const dateTimeOriginal = exifData.exif?.DateTimeOriginal || exifData.image?.DateTime;
    if (dateTimeOriginal) {
      try {
        // Parse the date - handle different formats
        let photoDate: Date;
        if (dateTimeOriginal.includes(' ')) {
          // Format: "2024:01:15 14:30:25"
          photoDate = new Date(dateTimeOriginal.replace(/:/g, '-').replace(' ', 'T'));
        } else {
          // Try as timestamp
          photoDate = new Date(parseInt(dateTimeOriginal) * 1000);
        }

        const now = new Date();
        const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000); // 1 hour ago
        const oneHourFromNow = new Date(now.getTime() + 60 * 60 * 1000); // 1 hour from now

        if (photoDate < oneHourAgo || photoDate > oneHourFromNow) {
          throw new AppError('La foto debe haber sido tomada recientemente (máximo 1 hora)', 'VALIDATION_ERROR', 422);
        }
      } catch (dateError) {
        // If date parsing fails, continue (don't reject)
        console.warn('Could not parse photo date:', dateTimeOriginal);
      }
    }

    // Check for obvious editing software (but be less strict)
    const software = exifData.image?.Software;
    if (software && (
      software.toLowerCase().includes('photoshop') ||
      software.toLowerCase().includes('gimp') ||
      software.toLowerCase().includes('adobe') ||
      software.toLowerCase().includes('lightroom')
    )) {
      throw new AppError('La foto parece haber sido editada con software profesional. Use una foto tomada directamente con la cámara', 'VALIDATION_ERROR', 422);
    }

  } catch (error) {
    if (error instanceof AppError) {
      throw error;
    }
    throw new AppError('La foto proporcionada no es válida o está corrupta', 'VALIDATION_ERROR', 422);
  }
}

// ── Sign ───────────────────────────────────────────────────────────────────

export async function sign(
  dto: SignContractDto,
  userId: string,
  ip: string | null,
): Promise<{ contract_id: string; signed_at: string }> {
  // Validate checkbox first
  if (!dto.checkbox_acceptance) {
    throw new AppError('Debes aceptar las cláusulas del contrato para continuar', 'VALIDATION_ERROR', 422);
  }

  const fieldErrors = validateFields(dto);
  if (fieldErrors.length > 0) {
    const err = new AppError('Validación fallida', 'VALIDATION_ERROR', 422) as AppError & { fields: typeof fieldErrors };
    err.fields = fieldErrors;
    throw err;
  }

  // Validate photo authenticity
  await validatePhoto(dto.photo_data!);

  // Check daily contract limit (25 per user per day)
  const { rows: countRows } = await pool.query<{ count: string }>(
    `SELECT COUNT(*) AS count
     FROM commitment_contracts
     WHERE user_id = $1
       AND signed_at >= CURRENT_DATE
       AND signed_at < CURRENT_DATE + INTERVAL '1 day'`,
    [userId],
  );
  const todayContracts = parseInt(countRows[0].count, 10);
  if (todayContracts >= 25) {
    throw new AppError(
      'Has alcanzado el límite de 25 contratos por día. Vuelve mañana.',
      'CONTRACT_DAILY_LIMIT',
      429,
    );
  }

  const { id: contractId, signed_at } = await commitmentRepo.createContract(dto, userId, ip, CURRENT_CONTRACT_VERSION);

  // Generate system signature: SHA-256 hash of (contractId + userId + signedAt + version)
  const systemSignatureData = createHash('sha256')
    .update(`${contractId}:${userId}:${signed_at}:${CURRENT_CONTRACT_VERSION}`)
    .digest('hex');

  await commitmentRepo.createSignature(contractId, dto.digital_signature, systemSignatureData);

  // Audit log
  await pool.query(
    `INSERT INTO audit_logs (user_id, action, ip_address, metadata)
     VALUES ($1, 'CONTRACT_SIGNED', $2, $3)`,
    [userId, ip, JSON.stringify({ contract_id: contractId })],
  );

  return { contract_id: contractId, signed_at };
}

// ── Generate Report ────────────────────────────────────────────────────────

export async function generateReport(
  contractId: string,
  requestingUserId: string,
  isAdmin = false,
): Promise<string> {
  const contract = await commitmentRepo.findById(contractId);

  if (!contract) {
    throw new AppError('Contrato no encontrado', 'NOT_FOUND', 404);
  }

  if (!isAdmin && contract.user_id !== requestingUserId) {
    throw new AppError('No tienes permiso para acceder a este contrato', 'FORBIDDEN', 403);
  }

  const payload: ContractReportPayload = {
    report_type: 'commitment_contract',
    generated_at: new Date().toISOString(),
    contract: {
      id: contract.id,
      contract_version: contract.contract_version,
      status: contract.status,
      signed_at: contract.signed_at,
      ip_address: contract.ip_address,
      latitude: (contract as any).latitude ?? null,
      longitude: (contract as any).longitude ?? null,
      location_address: (contract as any).location_address ?? null,
    },
    user_data: {
      first_name: contract.first_name,
      last_name: contract.last_name,
      address: contract.address,
      cedula: contract.cedula,
      phone: contract.phone,
    },
    clauses: CLAUSES_V1,
    checkbox_acceptance: contract.checkbox_acceptance,
    digital_signature: contract.signature?.signature_data ?? '',
    system_signature: (contract.signature as any)?.system_signature_data ?? '',
    photo_data: (contract as any).photo_data ?? null,
  };

  const report = Buffer.from(JSON.stringify(payload)).toString('base64');

  // Audit log
  await pool.query(
    `INSERT INTO audit_logs (user_id, action, metadata)
     VALUES ($1, 'CONTRACT_REPORT_ACCESSED', $2)`,
    [requestingUserId, JSON.stringify({ contract_id: contractId, user_id: requestingUserId })],
  );

  return report;
}
