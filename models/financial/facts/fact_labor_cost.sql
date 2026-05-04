-- marts/financial/fact_labor_cost.sql
-- Grain: 1 row per consultant x deliverable x month.
-- Source CONSULTANTDELIVERABLE (6507 daily) -> aggregated to month.
-- billing_rate is NULL for FP projects (only T&M has billing rates).

{{ config(materialized='table') }}

WITH labor AS (
    SELECT * FROM {{ ref('stg_consultantdeliverable') }}
),
deliv AS (
    SELECT deliverable_id, project_id FROM {{ ref('stg_deliverable') }}
),
proj AS (
    SELECT project_id, project_type FROM {{ ref('stg_project') }}
),
cost_rate AS (
    SELECT * FROM {{ ref('int_consultant_cost_rate') }}
),
billing AS (
    SELECT * FROM {{ ref('stg_projectbillingrate') }}
),
dim_consultant AS (
    SELECT consultant_key, consultant_id, dbt_valid_from, dbt_valid_to
    FROM {{ ref('fin_dim_consultant') }}
),
dim_deliv AS (
    SELECT deliverable_key, deliverable_id FROM {{ ref('fin_dim_deliverable') }}
),
dim_proj AS (
    SELECT project_key, project_id FROM {{ ref('fin_dim_project') }} WHERE is_current
),
dim_title AS (
    SELECT title_key, title_id FROM {{ ref('dim_consultant_title') }}
),

-- Aggregate labor to consultant x deliverable x month
labor_monthly AS (
    SELECT
        consultant_id,
        deliverable_id,
        year_month_int,
        month_end_date_key,
        SUM(hours_worked)                       AS hours_worked,
        MIN(work_date)                          AS first_work_date_in_month
    FROM labor
    GROUP BY consultant_id, deliverable_id, year_month_int, month_end_date_key
),

-- Attach title and cost rate effective at first work date of the month
enriched AS (
    SELECT
        lm.*,
        cr.title_id,
        cr.hourly_cost_rate
    FROM labor_monthly lm
    LEFT JOIN cost_rate cr
        ON cr.consultant_id = lm.consultant_id
        AND lm.first_work_date_in_month >= cr.valid_from
        AND (cr.valid_to IS NULL OR lm.first_work_date_in_month <= cr.valid_to)
)

SELECT
    e.month_end_date_key                        AS month_key,
    dc.consultant_key,
    dd.deliverable_key,
    dp.project_key,
    dt.title_key,
    e.hours_worked,
    e.hourly_cost_rate                          AS internal_cost_rate,
    e.hours_worked * e.hourly_cost_rate         AS labor_cost_amount,
    -- billing_rate only applies to T&M
    CASE WHEN p.project_type = 'Time and Material' THEN br.billing_rate END
                                                AS billing_rate,
    CASE WHEN p.project_type = 'Time and Material' AND br.billing_rate IS NOT NULL
         THEN e.hours_worked * br.billing_rate END
                                                AS billing_amount
FROM enriched e
INNER JOIN deliv d ON d.deliverable_id = e.deliverable_id
INNER JOIN proj p  ON p.project_id     = d.project_id
LEFT  JOIN dim_consultant dc
    ON dc.consultant_id = e.consultant_id
    AND e.first_work_date_in_month >= dc.dbt_valid_from
    AND (dc.dbt_valid_to IS NULL OR e.first_work_date_in_month <= dc.dbt_valid_to)
LEFT  JOIN dim_deliv  dd ON dd.deliverable_id = e.deliverable_id
LEFT  JOIN dim_proj   dp ON dp.project_id     = d.project_id
LEFT  JOIN dim_title  dt ON dt.title_id       = e.title_id
LEFT  JOIN billing    br
    ON br.project_id = d.project_id
    AND br.title_id  = e.title_id
