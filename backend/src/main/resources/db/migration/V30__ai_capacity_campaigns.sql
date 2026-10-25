CREATE TABLE ai_capacity_dataset (
    id uuid PRIMARY KEY,
    name varchar(160) NOT NULL,
    checksum varchar(64) NOT NULL,
    questions jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by varchar(320) NOT NULL
);
CREATE TABLE ai_capacity_campaign (
    id uuid PRIMARY KEY,
    name varchar(160) NOT NULL,
    dataset_id uuid NOT NULL REFERENCES ai_capacity_dataset(id),
    provider varchar(100) NOT NULL,
    config jsonb NOT NULL,
    status varchar(32) NOT NULL DEFAULT 'RUNNING',
    holds_provider boolean NOT NULL DEFAULT true,
    reason text,
    next_dispatch_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz,
    created_by varchar(320) NOT NULL,
    lease_owner varchar(100),
    lease_until timestamptz
);
CREATE UNIQUE INDEX ai_capacity_one_campaign_per_provider ON ai_capacity_campaign(provider) WHERE holds_provider;
CREATE TABLE ai_capacity_run (
    id uuid PRIMARY KEY,
    campaign_id uuid NOT NULL REFERENCES ai_capacity_campaign(id),
    ordinal integer NOT NULL,
    question jsonb NOT NULL,
    turn_id uuid UNIQUE REFERENCES ai_search_turn(id),
    current_turn_id uuid REFERENCES ai_search_turn(id),
    scenario_step integer NOT NULL DEFAULT 0,
    status varchar(32) NOT NULL DEFAULT 'PENDING',
    error_message text,
    created_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz,
    UNIQUE(campaign_id, ordinal)
);
CREATE INDEX ai_capacity_run_campaign ON ai_capacity_run(campaign_id, status);
CREATE TABLE ai_capacity_checkpoint (
    turn_id uuid NOT NULL REFERENCES ai_search_turn(id),
    name varchar(100) NOT NULL,
    value jsonb NOT NULL,
    PRIMARY KEY(turn_id, name)
);
CREATE TABLE ai_capacity_phase (
    turn_id uuid NOT NULL REFERENCES ai_search_turn(id),
    phase_key varchar(200) NOT NULL,
    generation integer NOT NULL DEFAULT 0,
    request jsonb NOT NULL,
    dispatch_body jsonb,
    job_id varchar(100),
    status varchar(40) NOT NULL DEFAULT 'SUBMITTING',
    result jsonb,
    collected boolean NOT NULL DEFAULT false,
    error_code varchar(100),
    error_message text,
    usage jsonb,
    attempts jsonb,
    event_cursor bigint NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY(turn_id, phase_key, generation)
);
CREATE UNIQUE INDEX ai_capacity_phase_job ON ai_capacity_phase(job_id) WHERE job_id IS NOT NULL;
CREATE TABLE ai_capacity_limit (
    campaign_id uuid NOT NULL REFERENCES ai_capacity_campaign(id),
    job_id varchar(100) NOT NULL,
    event_id varchar(160) NOT NULL,
    attempt_id varchar(100),
    observation jsonb NOT NULL,
    counts jsonb NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY(job_id, event_id)
);
CREATE TABLE ai_capacity_event (
    id bigserial PRIMARY KEY,
    campaign_id uuid NOT NULL REFERENCES ai_capacity_campaign(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    message text NOT NULL
);

-- Every turn in a scenario retains the same immutable campaign execution settings.
CREATE VIEW ai_capacity_turn AS
SELECT r.id,r.campaign_id,r.ordinal,r.status,t.id AS turn_id
FROM ai_capacity_run r JOIN ai_search_turn first_turn ON first_turn.id=r.turn_id
JOIN ai_search_turn t ON t.session_id=first_turn.session_id;
