CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name       VARCHAR(120)  NOT NULL,
    email           VARCHAR(255)  NOT NULL UNIQUE,
    phone           VARCHAR(20)   NOT NULL,
    password_hash   VARCHAR(72)   NOT NULL,
    birth_date      DATE          NOT NULL,
    is_admin        BOOLEAN       NOT NULL DEFAULT false,
    is_super_admin  BOOLEAN       NOT NULL DEFAULT false,
    is_active       BOOLEAN       NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE historical_results (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    draw_date   DATE        NOT NULL,
    numbers     SMALLINT[]  NOT NULL,
    uploaded_by UUID        REFERENCES users(id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE plays (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    play_type   VARCHAR(20) NOT NULL CHECK (play_type IN ('Loto','Pale','Tripleta','Número')),
    numbers     SMALLINT[]  NOT NULL,
    source      VARCHAR(20) NOT NULL DEFAULT 'generated' CHECK (source IN ('generated','dream')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE dream_interpretations (
    id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    dream_text        TEXT        NOT NULL,
    suggested_numbers SMALLINT[]  NOT NULL,
    keywords          TEXT[]      NOT NULL DEFAULT '{}',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE audit_logs (
    id          BIGSERIAL   PRIMARY KEY,
    user_id     UUID        REFERENCES users(id) ON DELETE SET NULL,
    action      VARCHAR(80) NOT NULL,
    ip_address  INET,
    metadata    JSONB       NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE application_errors (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_id    UUID NOT NULL UNIQUE,
    error_code      VARCHAR(80),
    message         TEXT NOT NULL,
    stack_trace     TEXT,
    context         JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE application_errors_archive (
    id              UUID PRIMARY KEY,
    reference_id    UUID NOT NULL UNIQUE,
    error_code      VARCHAR(80),
    message         TEXT NOT NULL,
    stack_trace     TEXT,
    context         JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tariff_config (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    base_cost_per_play      NUMERIC(10,2) NOT NULL,
    subscription_cost       NUMERIC(10,2) NOT NULL,
    discount_percentage     NUMERIC(5,2)  NOT NULL DEFAULT 0,
    min_plays_for_discount  INTEGER       NOT NULL DEFAULT 1,
    updated_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at              TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE company_bank_accounts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_name       VARCHAR(120)  NOT NULL,
    account_number  VARCHAR(50)   NOT NULL,
    account_type    VARCHAR(50)   NOT NULL,
    account_holder  VARCHAR(120)  NOT NULL,
    description     TEXT,
    is_active       BOOLEAN       NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE predefined_messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           VARCHAR(255)  NOT NULL,
    body            TEXT          NOT NULL,
    message_type    VARCHAR(80)   NOT NULL,
    role            VARCHAR(20)   NOT NULL CHECK (role IN ('sender','receiver','general')),
    is_active       BOOLEAN       NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE oauth_providers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_name   VARCHAR(20)   NOT NULL CHECK (provider_name IN ('google','facebook')),
    client_id       VARCHAR(255)  NOT NULL DEFAULT '',
    client_secret   VARCHAR(255)  NOT NULL DEFAULT '',
    redirect_uri    VARCHAR(500)  NOT NULL DEFAULT '',
    is_active       BOOLEAN       NOT NULL DEFAULT false,
    updated_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_plays_user_id_created      ON plays(user_id, created_at DESC);
CREATE INDEX idx_dream_interp_user_id       ON dream_interpretations(user_id, created_at DESC);
CREATE INDEX idx_historical_draw_date       ON historical_results(draw_date DESC);
CREATE INDEX idx_audit_logs_user_id         ON audit_logs(user_id, created_at DESC);
CREATE INDEX idx_audit_logs_action          ON audit_logs(action, created_at DESC);
CREATE INDEX idx_app_errors_reference_id    ON application_errors(reference_id);
CREATE INDEX idx_app_errors_created_at      ON application_errors(created_at DESC);
CREATE INDEX idx_bank_accounts_is_active    ON company_bank_accounts(is_active);
CREATE INDEX idx_predefined_messages_active ON predefined_messages(is_active);

INSERT INTO oauth_providers (provider_name) VALUES ('google'), ('facebook');
