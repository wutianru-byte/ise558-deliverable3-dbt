-- staging/stg_project.sql
-- 24 rows (17 Fixed + 7 Time and Material).
-- All date cols are TEXT in source -> TRY_TO_DATE.

{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('consulting', 'PROJECT') }}
)

SELECT
    PROJECTID                                  AS project_id,
    TRY_TO_TIMESTAMP(CREATED_AT)               AS created_at_ts,
    CLIENTID                                   AS client_id,
    UNITID                                     AS business_unit_id,    -- source col is UNITID, not BUSINESSUNITID
    NAME                                       AS project_name,
    TYPE                                       AS project_type,         -- 'Fixed' or 'Time and Material'
    PRICE                                      AS contract_value,       -- NULL for T&M
    ESTIMATED_BUDGET                           AS estimated_budget,
    PLANNED_HOURS                              AS planned_hours,
    TRY_TO_DATE(PLANNED_START_DATE)            AS planned_start_date,
    TRY_TO_DATE(PLANNED_END_DATE)              AS planned_end_date,
    STATUS                                     AS project_status,
    TRY_TO_DATE(ACTUAL_START_DATE)             AS actual_start_date,
    TRY_TO_DATE(ACTUAL_END_DATE)               AS actual_end_date,
    PROGRESS                                   AS progress_pct,         -- 0-100
    TRY_TO_TIMESTAMP(LAST_UPDATE)              AS last_update_ts
FROM source
