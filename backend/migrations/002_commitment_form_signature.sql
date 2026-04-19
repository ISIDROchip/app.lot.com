-- Migration 002: Commitment Form Signature
-- Creates commitment_contracts and commitment_signatures tables

-- Tabla: commitment_contracts
CREATE TABLE commitment_contracts (
    id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    first_name          VARCHAR(60)  NOT NULL,
    last_name           VARCHAR(60)  NOT NULL,
    address             VARCHAR(255) NOT NULL,
    cedula              VARCHAR(20)  NOT NULL,
    phone               VARCHAR(15)  NOT NULL,
    checkbox_acceptance BOOLEAN      NOT NULL,
    contract_version    VARCHAR(20)  NOT NULL,
    ip_address          INET,
    status              VARCHAR(20)  NOT NULL DEFAULT 'signed'
                            CHECK (status IN ('pending','signed','expired')),
    signed_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Tabla: commitment_signatures
CREATE TABLE commitment_signatures (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id     UUID        NOT NULL REFERENCES commitment_contracts(id) ON DELETE CASCADE,
    signature_data  TEXT        NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_commitment_contracts_user_id
    ON commitment_contracts(user_id, signed_at DESC);
CREATE INDEX idx_commitment_contracts_cedula
    ON commitment_contracts(cedula);
CREATE INDEX idx_commitment_contracts_status
    ON commitment_contracts(status);
CREATE INDEX idx_commitment_signatures_contract_id
    ON commitment_signatures(contract_id);

-- Actualizar CHECK de source en plays para incluir 'pull_10'
ALTER TABLE plays
    DROP CONSTRAINT plays_source_check,
    ADD CONSTRAINT plays_source_check
        CHECK (source IN ('generated','dream','pull_10'));
