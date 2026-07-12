{#-
  Use the model's +schema verbatim (STAGING, MARTS_REVOPS) instead of dbt's
  default <target_schema>_<custom_schema> concatenation — our schemas are
  fixed, governed names owned by RBAC, not per-developer prefixes.
-#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
