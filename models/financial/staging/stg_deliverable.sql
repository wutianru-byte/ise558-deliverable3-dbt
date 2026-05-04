-- staging/stg_deliverable.sql
-- 113 rows. PRICE + INVOICED_DATE drive FP revenue recognition.
-- 86 of 113 have PRICE; only 17 have INVOICED_DATE in baseline.

{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('consulting', 'DELIVERABLE') }}
)

SELECT
    DELIVERABLEID                              AS deliverable_id,
    PROJECTID                                  AS project_id,
    NAME                                       AS deliverable_name,
    TRY_TO_TIMESTAMP(CREATED_AT)               AS created_at_ts,
    PRICE                                      AS price,                    -- NULL for T&M deliverables
    TRY_TO_DATE(PLANNED_START_DATE)            AS planned_start_date,
    TRY_TO_DATE(ACTUAL_START_DATE)             AS actual_start_date,
    PLANNED_HOURS                              AS planned_hours,
    TRY_TO_DATE(DUE_DATE)                      AS due_date,
    STATUS                                     AS deliverable_status,
    PROGRESS                                   AS progress_pct,             -- 0-100
    TRY_TO_DATE(SUBMISSION_DATE)               AS submission_date,
    TRY_TO_DATE(INVOICED_DATE)                 AS invoiced_date,             -- triggers FP revenue
    TRY_TO_TIMESTAMP(LAST_UPDATE)              AS last_update_ts
FROM source
