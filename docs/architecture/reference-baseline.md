# Architecture reference baseline

## Personal News Feed reference

- Repository: `git@github.com:robbertvdzon/personal-news-feed-by-claude-code.git`
- Software Factory project: `personal-feed`
- Commit: `473ecfac7437130f216dee739f3c0db599fafc8e`
- Reference date: 2026-08-06

The reference is pinned. Later changes in Personal News Feed do not silently change this HKH
baseline.

## Adopted patterns

- one Kotlin/Spring Boot backend using Spring Modulith;
- feature-oriented backend packages with local API, domain and infrastructure layers;
- architecture verification as part of Maven verification;
- separate Flutter applications for distinct audiences;
- independent component verification, images and APK production;
- PostgreSQL/Flyway, OpenShift/Kustomize and GitHub Actions as the intended platform pattern;
- end-to-end tests that start the real application and replace only external dependencies.

## Deliberate differences

- HKH uses clear root component names: `backend`, `frontend` and `frontend-admin`; it does not copy
  historical Personal News Feed directory nesting or product-specific names.
- Local secrets live in root `secrets.env`, not `.env`.
- Env files are parsed as data and are never executed with `source` or `export $(cat ...)`.
- The empty baseline starts with no Modulith violations or compatibility allowlist.
- No Personal News Feed business logic, data or branding is copied.

Every further deviation before tag `comparison-baseline-v1` must be recorded here and applied
equally to `hkh` and `hkh-autopilot`.
