{#-
  The object (table/view) name, by target:
   * dev: the model's own name (schema__object style, e.g.
     stg_salesforce__accounts) — descriptive and collision-proof inside the
     developer's single sandbox schema. Any `alias:` in _models.yml is ignored
     in dev on purpose.
   * preprod / prod: the deployment name from `alias:` in _models.yml if set,
     else the model name — this is the stable public name (e.g. the spoke
     consumes MARTS_REVOPS.<alias>).
-#}
{% macro generate_alias_name(custom_alias_name, node) -%}
    {%- if target.name in ['preprod', 'prod'] and custom_alias_name is not none -%}
        {{ custom_alias_name | trim }}
    {%- else -%}
        {{ node.name }}
    {%- endif -%}
{%- endmacro %}
