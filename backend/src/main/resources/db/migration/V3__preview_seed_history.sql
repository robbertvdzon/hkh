CREATE TABLE preview_seed_history (
    seed_key VARCHAR(120) PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL,
    pr_number INTEGER NOT NULL CHECK (pr_number > 0)
);
