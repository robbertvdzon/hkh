CREATE TABLE latest_news (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title VARCHAR(160) NOT NULL,
    message TEXT NOT NULL,
    published_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(320) NOT NULL,
    CONSTRAINT latest_news_title_not_blank CHECK (LENGTH(TRIM(title)) > 0),
    CONSTRAINT latest_news_message_not_blank CHECK (LENGTH(TRIM(message)) > 0),
    CONSTRAINT latest_news_message_max_length CHECK (LENGTH(message) <= 10000)
);

CREATE INDEX latest_news_published_at_idx ON latest_news (published_at DESC, id DESC);
