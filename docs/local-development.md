# Local development — set up dbt and run models in your sandbox

Develop models on your machine with **dbt-core**, building into your **own
sandbox schema** (`REVOPS_DEV_<NAME>`). You read every shared layer and write
only your sandbox — nothing shared or in prod is touched.

## Prerequisites

- You're onboarded as a developer (composite role `DEV_<NAME>` + sandbox). See
  the infra repo's [onboard-developer runbook](https://github.com/akashpahilwan/OpenGovPOC/blob/main/infra/docs/runbooks/onboard-developer.md).
- Your Snowflake password is set (or a key pair registered).

## 1. Install dbt (one time)

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1          # macOS/Linux: source .venv/bin/activate
pip install dbt-snowflake
```

## 2. Set your connection

Copy `set-dev-env.ps1` (git-ignored template) per developer and fill in your
values, then dot-source it:

```powershell
$env:SF_ORGANIZATION_NAME = "IVUTLPR"
$env:SF_ACCOUNT_NAME      = "JZ06632"
$env:SF_USERNAME          = "you@opengov.com"     # LOGIN NAME (email), not the object name
$env:SF_PASSWORD          = "<your-password>"      # password auth is the dev default
$env:SF_DEV_ROLE          = "DEV_<YOU>"            # your composite role
$env:DBT_DEV_SCHEMA       = "REVOPS_DEV_<YOU>"     # your sandbox
```

> **Password auth matches `LOGIN_NAME`** — use your email, not the object
> username. Prefer key-pair? set `SF_AUTHENTICATOR=SNOWFLAKE_JWT` +
> `SF_PRIVATE_KEY_PATH` instead of `SF_PASSWORD`. (`externalbrowser`/SSO only
> works on accounts with a SAML IdP — this demo account has none.)

These scripts are git-ignored (`set-dev-env*.ps1`) — never commit a password.

## 3. Build into your sandbox

The repo's `profiles.yml` is used with `--profiles-dir .`:

```powershell
git checkout -b feature/<you>-<thing>
dbt debug --target dev --profiles-dir .        # verify the connection
dbt build --target dev --profiles-dir .        # run + test all models
dbt build --select stg_salesforce__accounts --target dev --profiles-dir .   # one model
```

Models land in `OG_DEV_DB.REVOPS_DEV_<YOU>` named `<schema>__<model>` (e.g.
`STAGING__accounts`, `MARTS_REVOPS__revops_pipeline`) so your sandbox never
collides with the real schemas.

## What you'll see

- You **read** shared `RAW`/`STAGING`/`MARTS` via `REVOPS_READER` (inherited by
  your composite role).
- Financial columns (`amount`, `arr`) come back **`NULL`** in your dev builds —
  a plain reader isn't exemption-listed. You develop the logic; real financials
  appear only in the `preprod`/`prod` builds (which run as `REVOPS_DEVELOPER`).
- Incremental models: your first sandbox build is a full build; re-runs merge.
  After changing incremental logic, add `--full-refresh` to rebuild cleanly.

## Next

Commit, push your branch, open a PR into `dev`. See the
[developer workflow](developer-workflow.md).
