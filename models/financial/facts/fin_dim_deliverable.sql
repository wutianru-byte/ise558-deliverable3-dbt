-- marts/financial/dim_deliverable.sql
-- 113 rows. PRICE + INVOICED_DATE drive FP revenue recognition.

{{ config(materialized='table') }}

WITH d AS (
    SELECT * FROM {{ ref('stg_deliverable') }}
),
p AS (
    SELECT project_id, project_key
    FROM {{ ref('fin_dim_project') }}
    WHERE is_current
)

SELECT
    MD5(d.deliverable_id::STRING)               AS deliverable_key,
    d.deliverable_id,
    p.project_key,                              -- FK to current dim_project version
    d.project_id,
    d.deliverable_name,
    CASE WHEN d.planned_start_date IS NULL THEN NULL
         ELSE TO_NUMBER(TO_VARCHAR(d.planned_start_date, 'YYYYMMDD')) END
                                                AS planned_start_date_key,
    CASE WHEN d.due_date IS NULL THEN NULL
         ELSE TO_NUMBER(TO_VARCHAR(d.due_date, 'YYYYMMDD')) END
                                                AS due_date_key,
    CASE WHEN d.actual_start_date IS NULL THEN NULL
         ELSE TO_NUMBER(TO_VARCHAR(d.actual_start_date, 'YYYYMMDD')) END
                                                AS actual_start_date_key,
    CASE WHEN d.submission_date IS NULL THEN NULL
         ELSE TO_NUMBER(TO_VARCHAR(d.submission_date, 'YYYYMMDD')) END
                                                AS submission_date_key,
    CASE WHEN d.invoiced_date IS NULL THEN NULL
         ELSE TO_NUMBER(TO_VARCHAR(d.invoiced_date, 'YYYYMMDD')) END
                                                AS invoiced_date_key,
    d.planned_hours,
    d.price,                                    -- NULL for T&M deliverables
    d.deliverable_status,
    d.progress_pct
FROM d
LEFT JOIN p ON p.project_id = d.project_id
