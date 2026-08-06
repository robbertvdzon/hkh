# Development

## Configuration precedence

The backend resolves local configuration in this order:

1. values from root `secrets.env`;
2. real process environment variables, which override file values.

Set `HKH_SECRETS_FILE` to use another file. The parser accepts `KEY=value`, blank lines, comments
and optional surrounding single or double quotes. Invalid lines and missing required keys fail
without logging secret values.

## Backend commands

```bash
mvn -f backend/pom.xml spring-boot:run
mvn -B --no-transfer-progress -f backend/pom.xml clean verify
```

Always run from the repository root, or from `backend`; the loader checks both locations for the
root `secrets.env`.

## Local PostgreSQL

Start the isolated PostgreSQL 16 development database on host port 5434:

```bash
docker compose -f docker-compose.dev.yml up -d
```

Flyway applies migrations automatically when the backend starts. Stop the database without losing
data with `docker compose -f docker-compose.dev.yml down`. Removing the named volume is an explicit
destructive development reset and is therefore not part of the normal stop command.
