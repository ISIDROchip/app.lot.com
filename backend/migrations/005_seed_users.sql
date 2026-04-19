-- Migration 005: Seed Users
-- Crea usuarios de prueba automáticamente al iniciar la DB.
-- Contraseña para ambos usuarios: jesus123

-- Usuario normal de prueba
INSERT INTO users (full_name, email, phone, password_hash, birth_date, is_active)
VALUES (
  'Jesus Enmanuel Perez Reynoso',
  'jesusenmanuelperezreynoso@gmail.com',
  '8298625524',
  '$2b$10$1KcFy2Zq54rSP2u6wP5ecO7T/TrCm8kI8H4L2n5dHy7S7WSNfIo.W',
  '2006-07-16',
  true
) ON CONFLICT (email) DO NOTHING;

-- Super Administrador
INSERT INTO users (full_name, email, phone, password_hash, birth_date, is_admin, is_super_admin, is_active)
VALUES (
  'Super Administrador',
  'admin@luxora.com',
  '8090000000',
  '$2b$10$1KcFy2Zq54rSP2u6wP5ecO7T/TrCm8kI8H4L2n5dHy7S7WSNfIo.W',
  '1990-01-01',
  true,
  true,
  true
) ON CONFLICT (email) DO NOTHING;
