-- Page-views staging: this is where the append-only RAW log becomes a clean,
-- deduplicated current view.
--   * enforce the contract (drop malformed rows the full-set landing kept)
--   * ROW-LEVEL event_id dedup (the dedup we deliberately keep OUT of ingestion)
-- Latest row per event_id wins (by _loaded_at), so re-landed/backfilled events
-- and in-file duplicates collapse to one.

{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='event_id',
    on_schema_change='append_new_columns'
) }}

-- Incremental MERGE on event_id; high-watermark on _loaded_at. RAW._loaded_at
-- defaults to CURRENT_TIMESTAMP() on every insert, so any newly-loaded row --
-- including a --force-insert re-append of an existing event -- gets a _loaded_at
-- greater than what's already in the model and is picked up automatically; no
-- lookback needed. The NOT EXISTS at the end then drops rows whose non-metadata
-- fields are unchanged, so the MERGE only touches genuinely new or changed events.
with source as (
    select * from {{ source('product_events', 'page_views') }}
    {% if is_incremental() %}
    where _loaded_at > (select coalesce(max(_loaded_at), '1900-01-01'::timestamp_ntz) from {{ this }})
    {% endif %}
),

-- typed + contract-filtered + one row per event_id
deduped as (
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
      -- user_id lives in the VARIANT payload: a JSON null ("user_id": null) is NOT
      -- SQL NULL, so `payload:user_id IS NOT NULL` is TRUE for it and the row leaks
      -- through (then ::varchar makes it NULL again). Filter on the CAST value so
      -- both a missing key and an explicit JSON null are excluded.
      and payload:user_id::varchar is not null
    qualify row_number() over (partition by event_id order by event_timestamp desc, _loaded_at desc) = 1
)

select * from deduped s
{% if is_incremental() %}
-- CHANGE DETECTION: only merge NEW or genuinely CHANGED events. Drop a record
-- when an identical row (same event_id, every non-metadata field equal) already
-- exists in the model, so the MERGE never does a no-op update. NOT EXISTS with
-- equality (deliberately, not EXISTS with <>) keeps brand-new event_ids -- which
-- have no match in {{ this }} -- as well as changed ones. coalesce guards nulls:
-- text -> 'NA', timestamp -> '1900-01-01', number -> 0 (boolean -> false,
-- float/decimal -> 0.00 for those types). _source_file / _loaded_at are metadata
-- and are intentionally excluded from the comparison.
where not exists (
    select 1
    from {{ this }} t
    where t.event_id = s.event_id
      and coalesce(t.account_id, 'NA')  = coalesce(s.account_id, 'NA')
      and coalesce(t.user_id, 'NA')     = coalesce(s.user_id, 'NA')
      and coalesce(t.event_timestamp, '1900-01-01'::timestamp_ntz)
        = coalesce(s.event_timestamp, '1900-01-01'::timestamp_ntz)
      and coalesce(t.page_name, 'NA')   = coalesce(s.page_name, 'NA')
      and coalesce(t.session_id, 'NA')  = coalesce(s.session_id, 'NA')
      and coalesce(t.module, 'NA')      = coalesce(s.module, 'NA')
      and coalesce(t.browser, 'NA')     = coalesce(s.browser, 'NA')
      and coalesce(t.duration_ms, 0)    = coalesce(s.duration_ms, 0)
)
{% endif %}
