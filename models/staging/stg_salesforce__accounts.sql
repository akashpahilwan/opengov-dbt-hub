-- Accounts staging: cast, snake_case, normalize. ARR is deliberately NOT
-- selected — it is masked PII (only REVOPS_ADMIN sees it) and dbt runs as
-- REVOPS_DEVELOPER, so pulling it here would persist NULLs. Keep it in RAW.

{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='account_id',
    on_schema_change='append_new_columns'
) }}

-- Incremental MERGE on account_id; CDC on _fivetran_synced.
with source as (
    select * from {{ source('salesforce', 'account') }}
    {% if is_incremental() %}
    where _fivetran_synced > (select coalesce(max(_fivetran_synced), '1900-01-01'::timestamp_ntz) from {{ this }})
    {% endif %}
),
latest as (
    select * from source
    qualify row_number() over (partition by account_id order by _fivetran_synced desc) = 1
)
select
    account_id::varchar                    as account_id,
    account_name::varchar                  as account_name,
    {{ clean_string('industry') }}         as industry,
    billing_state::varchar                 as billing_state,
    {{ clean_string('customer_tier') }}    as customer_tier,
    created_date::timestamp_ntz            as created_date,
    _fivetran_synced::timestamp_ntz        as _fivetran_synced
from latest
