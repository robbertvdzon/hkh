---
default_base_branch: main
branch_prefix: ai/
preview_url_template: "https://hkh-pr-{pr_num}.vdzonsoftware.nl"
preview_namespace_template: "hkh-pr-{pr_num}"
preview_db_secret_recipe: ""
---

# Deployment

Pull requests worden als geïsoleerde preview in OpenShift gedeployd. De publieke app is bereikbaar
op `https://hkh-pr-<nummer>.vdzonsoftware.nl`; de admin-app op
`https://hkh-admin-pr-<nummer>.vdzonsoftware.nl`. De bijbehorende namespace heet
`hkh-pr-<nummer>` en wordt na het sluiten van de pull request automatisch opgeruimd.
