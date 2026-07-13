# opengov-dbt-hub

The **HUB** dbt project for the OpenGov data platform (dbt Mesh), run on
**Snowflake's native dbt** feature. Isolated repo so domain **spoke** projects
(separate repos) can consume the hub's public models cross-project.

## Project

- **`models/staging/`** → `OG_<ENV>_DB.STAGING` — typed, cleaned, **incremental**
  (merge) models with in-batch **dedup** (`QUALIFY ROW_NUMBER`):
  - `stg_salesforce__accounts` — CDC on `_fivetran_synced`, latest per `account_id`.
  - `stg_salesforce__opportunities` — soft-deletes dropped, `stage_name`
    normalized via `clean_string`, latest per `opportunity_id`. `amount` carried
    (masked upstream by the `PII_FINANCIAL` tag).
  - `stg_product_events__page_views` — contract-valid rows only (`user_id` cast
    so a JSON-null is excluded), latest per `event_id` (CDC on `_loaded_at`).
- **`models/marts/`** → `OG_<ENV>_DB.MARTS_REVOPS`:
  - `mart_revops__pipeline` — opportunities × accounts + `days_to_close`,
    `pipeline_stage_bucket`, `weighted_amount`. **Public mesh model.** `amount`
    is visible to `REVOPS_ANALYST` here (analysts are exempt from the financial
    mask); a plain reader still sees `NULL`.
- **`macros/`** — `clean_string` (trim+upper), `apply_column_tags` (post-hook that
  carries the `PII_FINANCIAL` tag onto built columns in preprod/prod),
  `generate_schema_name` / `generate_alias_name` (the naming strategy below).

## Targets (`profiles.yml`)

| Target | Role | Database | Model naming |
|--------|------|----------|--------------|
| `dev` | `DEV_<NAME>` (developer's composite) | `OG_DEV_DB` | in **your sandbox** `REVOPS_DEV_<NAME>` as `<schema>__<model>` |
| `preprod` | `REVOPS_DEVELOPER` | `OG_DEV_DB` | real schemas (`STAGING`/`MARTS_REVOPS`), model `alias` |
| `prod` | `REVOPS_DEVELOPER` | `OG_PROD_DB` | real schemas, model `alias` |

The `dev` target authenticates with **username + password** by default
(`SF_USERNAME` = login-name/email + `SF_PASSWORD`); key-pair and SSO are
available via `SF_AUTHENTICATOR`. Native dbt-on-Snowflake ignores these fields
and uses the session identity.

## Runtime — native dbt on Snowflake

Not run via a dbt-core runner in CI. Snowflake pulls this repo through a Git API
integration and runs it as a `DBT PROJECT` object, executed as `REVOPS_DEVELOPER`
on `OG_<ENV>_DEVELOPER_WH`:

```sql
EXECUTE DBT PROJECT OG_PROD_DB.DBT.OG_HUB ARGS='build --target prod';
```

## Guides

- **[Local development](docs/local-development.md)** — set up dbt-core locally and
  run models in your own sandbox.
- **[Developer workflow](docs/developer-workflow.md)** — branch → sandbox → PR →
  preprod → prod; how isolation works.
- **[CI/CD](docs/ci-cd.md)** — auto-deploy on push + the manual full-refresh workflow.

## Governance

Enforced by RBAC + tag-based masking in the
[OpenGovPOC infra repo](https://github.com/akashpahilwan/OpenGovPOC): dbt reads
RAW, writes STAGING + MARTS. `ACCOUNT.ARR` / `OPPORTUNITY.AMOUNT` are masked by
the `PII_FINANCIAL` tag for non-exempt roles.

## Mesh: how a spoke consumes this hub

A domain spoke repo lists this project as a dependency and cross-project `ref`s
the public model, writing only its own `MARTS_<domain>`:

```yaml
# spoke: dependencies.yml
projects:
  - name: og_hub
```
```sql
select * from {{ ref('og_hub', 'mart_revops__pipeline') }}
```
