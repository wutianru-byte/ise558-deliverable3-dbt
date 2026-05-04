-- marts/financial/dim_expense_category.sql
-- 10 distinct categories from PROJECTEXPENSE.CATEGORY.

{{ config(materialized='table') }}

SELECT
    MD5(category_name)                          AS category_key,
    category_name
FROM (
    SELECT DISTINCT category_name
    FROM {{ ref('stg_projectexpense') }}
    WHERE category_name IS NOT NULL
)
