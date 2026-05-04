-- staging/stg_consultanttitlehistory.sql
-- 112 rows = 108 Hire + 4 Layoff (no Promotion in baseline).
-- Derive end_date via LEAD(start_date) per consultant for SCD2 lookups.

{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('consulting', 'CONSULTANTTITLEHISTORY') }}
),

with_dates AS (
    SELECT
        RECORDID                                AS record_id,
        CONSULTANTID                            AS consultant_id,
        TITLEID                                 AS title_id,
        TRY_TO_DATE(START_DATE)                 AS start_date,
        EVENT_TYPE                              AS event_type,
        SALARY                                  AS salary,
        TRY_TO_TIMESTAMP(LAST_UPDATE)           AS last_update_ts
    FROM source
)

SELECT
    record_id,
    consultant_id,
    title_id,
    start_date,
    -- Effective end is the day BEFORE the next event for the same consultant
    DATEADD(
        day,
        -1,
        LEAD(start_date) OVER (PARTITION BY consultant_id ORDER BY start_date)
    )                                          AS end_date,
    event_type,
    salary,
    last_update_ts,
    -- Mark the latest row per consultant as current (NULL end_date)
    CASE
        WHEN LEAD(start_date) OVER (PARTITION BY consultant_id ORDER BY start_date) IS NULL
        THEN TRUE ELSE FALSE
    END                                        AS is_current
FROM with_dates
