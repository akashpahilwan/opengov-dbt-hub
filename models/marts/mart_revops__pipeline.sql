-- RevOps pipeline mart: one row per opportunity, enriched with account context
-- and RevOps measures. PUBLIC dbt Mesh model — domain SPOKE projects consume
-- this cross-project (read-only) and build their own MARTS_<domain>.
--
-- Measures:
--   days_to_close        created -> close (negative = closed in the past)
--   pipeline_stage_bucket Early / Late / Closed  (from normalized stage_name)
--   weighted_amount      amount * stage win-probability (forecast value)

with opportunities as (
    select * from {{ ref('stg_salesforce__opportunities') }}
),

accounts as (
    select * from {{ ref('stg_salesforce__accounts') }}
),

final as (
    select
        o.opportunity_id,
        o.account_id,
        a.account_name,
        a.industry,
        a.customer_tier,
        a.billing_state,
        o.owner_id,
        o.stage_name,
        o.amount,
        o.close_date,
        o.created_date,

        datediff('day', o.created_date::date, o.close_date) as days_to_close,

        case
            when o.stage_name in ('CLOSED WON', 'CLOSED LOST') then 'Closed'
            when o.stage_name in ('PROSPECTING', 'QUALIFICATION') then 'Early Stage'
            else 'Late Stage'
        end as pipeline_stage_bucket,

        -- stage win-probability (simple, explainable forecast weighting)
        o.amount * case o.stage_name
            when 'PROSPECTING'   then 0.10
            when 'QUALIFICATION' then 0.25
            when 'NEGOTIATION'   then 0.60
            when 'CLOSED WON'    then 1.00
            when 'CLOSED LOST'   then 0.00
            else 0.50
        end as weighted_amount

    from opportunities o
    left join accounts a on o.account_id = a.account_id
)

select * from final
