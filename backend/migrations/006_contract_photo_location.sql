-- Migration 006: Contract Photo and Location
-- Agrega foto del firmante y geolocalización al contrato de compromiso.

ALTER TABLE commitment_contracts
    ADD COLUMN IF NOT EXISTS photo_data        TEXT,           -- foto del firmante en Base64
    ADD COLUMN IF NOT EXISTS latitude          NUMERIC(10,7),  -- coordenada GPS
    ADD COLUMN IF NOT EXISTS longitude         NUMERIC(10,7),
    ADD COLUMN IF NOT EXISTS location_address  VARCHAR(500);   -- dirección legible del GPS

-- También agregar firma del sistema (hash criptográfico generado automáticamente)
ALTER TABLE commitment_signatures
    ADD COLUMN IF NOT EXISTS system_signature_data TEXT;       -- firma generada por el sistema
