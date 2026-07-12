-- Page-views staging: this is where the append-only RAW log becomes a clean,
-- deduplicated current view.
--   * enforce the contract (drop malformed rows the full-set landing kept)
--   * ROW-LEVEL event_id dedup (the dedup we deliberately keep OUT of ingestion)
-- Latest row per event_id wins (by _loaded_at), so re-landed/backfilled events
-- and in-file duplicates collapse to one.

with source as (
    select * from {{ source('product_events', 'page_views') }}
)

select
    event_id::varchar                                  as event_id,
    account_id::varchar                                as account_id,
    payload:user_id::varchar                           as user_id,
    event_timestamp::timestamp_ntz                     as event_timestamp,
    payload:page_name::varchar                         as page_name,
    payload:session_id::varchar                        as session_id,
    payload:properties.module::varchar                 as module,
    payload:properties.browser::varchar                as browser,
    payload:properties.duration_ms::int                as duration_ms,
    _filename                                          as _source_file,
    _loaded_at                                         as _loaded_at
from source
-- contract: keep only valid events (malformed full-set rows stay in RAW only)
where event_id is not null
  and account_id is not null
  and event_timestamp is not null
  and payload:user_id is not null
qualify row_number() over (partition by event_id order by _loaded_at desc) = 1
