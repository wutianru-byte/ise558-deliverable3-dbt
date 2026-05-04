-- marts/financial/fact_project_expense.sql
-- Grain: 1 row per expense line item (~72 rows, source 1:1).

{{ config(materialized='table') }}

WITH e AS (
    SELECT * FROM {{ ref('stg_projectexpense') }}
),
dp AS (
    SELECT project_id, project_key
    FROM {{ ref('fin_dim_project') }}
    WHERE is_current
),
dd AS (
    SELECT deliverable_id, deliverable_key FROM {{ ref('fin_dim_deliverable') }}
),
dc AS (
    SELECT category_name, category_key FROM {{ ref('dim_expense_category') }}
)

SELECT
    MD5(e.expense_id::STRING)                   AS expense_key,
    e.expense_id,
    e.expense_date_key                          AS date_key,
    dp.project_key,
    dd.deliverable_key,                         -- nullable: project-level expenses have no deliverable
    dc.category_key,
    e.expense_amount,
    e.is_billable,
    e.description
FROM e
LEFT JOIN dp ON dp.project_id     = e.project_id
LEFT JOIN dd ON dd.deliverable_id = e.deliverable_id
LEFT JOIN dc ON dc.category_name  = e.category_name
