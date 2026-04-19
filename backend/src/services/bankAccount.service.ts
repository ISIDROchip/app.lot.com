import * as repo from '../repositories/bankAccount.repository';
import { AppError } from '../middlewares/errorHandler';
import { CreateBankAccountDto, UpdateBankAccountDto } from '../dtos/admin.dto';
import { BankAccountRecord } from '../repositories/bankAccount.repository';

export async function findAll() {
  return repo.findAll();
}

export async function findActive() {
  return repo.findActive();
}

export async function findById(id: string): Promise<BankAccountRecord> {
  const account = await repo.findById(id);
  if (!account) throw new AppError('Cuenta bancaria no encontrada', 'NOT_FOUND', 404);
  return account;
}

export async function create(data: CreateBankAccountDto) {
  return repo.create(data);
}

export async function update(id: string, data: UpdateBankAccountDto) {
  await findById(id);
  return repo.update(id, data);
}

export async function setStatus(id: string, is_active: boolean) {
  await findById(id);
  return repo.setStatus(id, is_active);
}

export async function deleteById(id: string) {
  await findById(id);
  return repo.deleteById(id);
}
