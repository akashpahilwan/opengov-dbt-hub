-- Accounts staging: cast, snake_case, normalize. ARR is deliberately NOT
-- selected — it is masked PII (only REVOPS_ADMIN sees it) and dbt runs as
-- REVOPS_DEVELOPER, so pulling it here would persist NULLs. Keep it in RAW.

{{ config(unique_key='account_id') }}

-- Incremental MERGE on account_id; CDC on _fivetran_synced.
with source as (
    select * from {{ source('salesforce', 'account') }}
    {% if is_incremental() %}
    where _fivetran_synced > (select coalesce(max(_fivetran_synced), '1900-01-01'::timestamp_ntz) from {{ this }})
    {% endif %}
)

select
    account_id::varchar                    as account_id,
    account_name::varchar                  as account_name,
    {{ clean_string('industry') }}         as industry,
    billing_state::varchar                 as billing_state,
    {{ clean_string('customer_tier') }}    as customer_tier,
    created_date::timestamp_ntz            as created_date,
    _fivetran_synced::timestamp_ntz        as _fivetran_synced
from source
