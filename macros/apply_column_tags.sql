{#-
  apply_column_tags — carry PII classification onto dbt-built columns.

  Declare the tag on a column in _models.yml under meta.pii_tag, e.g.:

      columns:
        - name: arr_band
          meta:
            pii_tag: { name: PII_FINANCIAL, value: arr }

  Wire as a post-hook (only in deployment targets, where the object is a real
  governed table). Idempotent: re-setting the same tag/value is a no-op.

      # dbt_project.yml
      models:
        og_hub:
          marts:
            +post-hook: "{{ apply_column_tags() }}"

  Requirement: the executing role (REVOPS_DEVELOPER) needs APPLY on the tag
  (one functional_grant), and the GOVERNANCE tag must exist (Terraform). The
  masking policy attached to the tag then protects the column automatically —
  the same tag-based governance as RAW, now travelling to marts. Only runs in
  preprod/prod (dev sandboxes don't carry governed tags).
-#}
{% macro apply_column_tags() %}
    {%- if target.name not in ['preprod', 'prod'] -%}
        {{ return('') }}
    {%- endif -%}
    {#- views need ALTER VIEW, tables ALTER TABLE -#}
    {%- set obj = 'VIEW' if model.config.materialized == 'view' else 'TABLE' -%}
    {%- set stmts = [] -%}
    {%- for col in model.get('columns', {}).values() -%}
        {%- set t = col.get('meta', {}).get('pii_tag') -%}
        {%- if t -%}
            {%- set _ = stmts.append(
                "ALTER " ~ obj ~ " " ~ this ~ " MODIFY COLUMN " ~ col.name ~
                " SET TAG " ~ this.database ~ ".GOVERNANCE." ~ t.name ~ " = '" ~ t.value ~ "'"
            ) -%}
        {%- endif -%}
    {%- endfor -%}
    {{ return(stmts | join(';\n')) }}
{% endmacro %}
