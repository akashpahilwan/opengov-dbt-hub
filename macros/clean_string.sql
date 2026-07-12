{#-
  clean_string — trim surrounding whitespace and uppercase a column.
  Reusable normalizer; applied to stage_name in staging so messy source
  casing/whitespace ('  negotiation ') becomes canonical ('NEGOTIATION').
-#}
{% macro clean_string(column_name) %}
    UPPER(TRIM({{ column_name }}))
{% endmacro %}
