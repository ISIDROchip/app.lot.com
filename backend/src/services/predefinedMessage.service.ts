import * as repo from '../repositories/predefinedMessage.repository';
import { AppError } from '../middlewares/errorHandler';
import { CreateMessageDto, UpdateMessageDto } from '../dtos/admin.dto';
import { PredefinedMessageRecord } from '../repositories/predefinedMessage.repository';

export async function findAll() {
  return repo.findAll();
}

export async function findById(id: string): Promise<PredefinedMessageRecord> {
  const msg = await repo.findById(id);
  if (!msg) throw new AppError('Mensaje no encontrado', 'NOT_FOUND', 404);
  return msg;
}

export async function create(data: CreateMessageDto) {
  return repo.create(data);
}

export async function update(id: string, data: UpdateMessageDto) {
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
