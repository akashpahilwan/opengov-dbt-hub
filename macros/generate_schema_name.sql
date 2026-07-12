{#-
  Where a model lands, by target:
   * dev (an individual developer): ALWAYS the developer's own sandbox schema
     (target.schema = REVOPS_DEV_<NAME>). Every model materializes there, so
     developers never collide and never touch shared/PROD schemas.
   * preprod / prod (the scheduled dbt job as REVOPS_DEVELOPER): the model's
     real governed +schema (STAGING, MARTS_REVOPS) — verbatim, not prefixed.
-#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if target.name in ['preprod', 'prod'] -%}
        {{ (custom_schema_name | trim) if custom_schema_name is not none else target.schema }}
    {%- else -%}
        {{ target.schema }}
    {%- endif -%}
{%- endmacro %}
