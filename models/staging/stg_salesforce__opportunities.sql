-- Opportunities staging: cast, snake_case, normalize stage_name via the
-- clean_string macro, and EXCLUDE soft-deleted rows (Fivetran is_deleted).
-- (The brief's "filter is_deleted" = drop deleted records from the clean layer.)

with source as (
    select * from {{ source('salesforce', 'opportunity') }}
)

select
    opportunity_id::varchar               as opportunity_id,
    account_id::varchar                   as account_id,
    owner_id::varchar                     as owner_id,
    {{ clean_string('stage_name') }}      as stage_name,
    amount::number(18, 2)                 as amount,
    close_date::date                      as close_date,
    created_date::timestamp_ntz           as created_date,
    last_modified_date::timestamp_ntz     as last_modified_date,
    _fivetran_synced::timestamp_ntz       as _fivetran_synced
from source
where not is_deleted   -- drop soft-deleted opportunities
