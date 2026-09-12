CREATE TABLE app_user (
    id            UUID PRIMARY KEY,
    email         VARCHAR(320) NOT NULL UNIQUE,
    display_name  VARCHAR(200),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMPTZ
);

-- Sessietokens staan uitsluitend gehasht in de database. Een sessie is een jaar geldig en
-- schuift bij gebruik op; alleen uitloggen (revoked_at) beëindigt hem eerder.
CREATE TABLE user_session (
    id           UUID PRIMARY KEY,
    user_id      UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    token_hash   CHAR(64) NOT NULL UNIQUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at   TIMESTAMPTZ NOT NULL,
    revoked_at   TIMESTAMPTZ
);

CREATE INDEX user_session_user_idx ON user_session (user_id);
