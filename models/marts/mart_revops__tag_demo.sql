-- Demo mart: proves dbt applies a Snowflake COLUMN TAG during the build.
-- revenue_amount is NUMBER(18,2) (matches the MASK_PII_FINANCIAL_NUMBER policy);
-- it is classified PII_FINANCIAL in _marts.yml, and the apply_column_tags
-- post-hook SET TAGs it right after this table builds. Result: masked (NULL)
-- for non-admins, real value for REVOPS_ADMIN — governance carried onto a mart.
select
    1                         as demo_id,
    123456.78::number(18, 2)  as revenue_amount
