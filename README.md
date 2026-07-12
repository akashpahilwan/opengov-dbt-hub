# opengov-dbt-hub

The **HUB** dbt project for the OpenGov data platform (dbt Mesh), run on
**Snowflake's native dbt** feature. Isolated repo so domain **spoke** projects
(separate repos) can consume the hub's public models cross-project.

- **staging/** → `OG_<ENV>_DB.STAGING` (typed, cleaned, deduped views)
  - `stg_salesforce__accounts` — ARR excluded (masked PII, stays in RAW)
  - `stg_salesforce__opportunities` — soft-deletes dropped, `stage_name` normalized via `clean_string`
  - `stg_product_events__page_views` — contract-valid + **event_id dedup** (`QUALIFY ROW_NUMBER`)
- **marts/** → `OG_<ENV>_DB.MARTS_REVOPS`
  - `mart_revops__pipeline` — opportunities × accounts + `days_to_close`,
    `pipeline_stage_bucket`, `weighted_amount`. **PUBLIC mesh model** a spoke consumes.
- **macros/clean_string.sql** — trim + uppercase (applied to `stage_name`)

## Runtime — native dbt on Snowflake

Not run via dbt-core in CI. Snowflake pulls this repo through a Git API
integration and runs it as a `DBT PROJECT` object, executed as
`REVOPS_DEVELOPER` on the `OG_<ENV>_TRANSFORM_*` warehouse:

```sql
EXECUTE DBT PROJECT og_hub ARGS = 'deps';
EXECUTE DBT PROJECT og_hub ARGS = 'build --target dev';   -- run + test
```

Governance carried by RBAC/masking (see the OpenGovPOC infra repo): dbt reads
RAW, writes STAGING + MARTS_REVOPS; ARR is masked so it's kept out of models.

## Mesh: how a spoke consumes this hub

A domain spoke repo lists this project as a dependency and cross-project refs
the public model, writing only its own `MARTS_<domain>`:

```yaml
# spoke: dependencies.yml
projects:
  - name: og_hub
```
```sql
-- spoke model
select * from {{ ref('og_hub', 'mart_revops__pipeline') }}
```
