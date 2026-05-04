-- staging/stg_consultantdeliverable.sql
-- 6507 daily labor logs. Aggregate to month later in intermediate layer.
-- DATE field is TEXT -> TRY_TO_DATE; derive year_month_int for joining.

{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('consulting', 'CONSULTANTDELIVERABLE') }}
)

SELECT
    RECORDID                                   AS record_id,
    CONSULTANTID                               AS consultant_id,
    DELIVERABLEID                              AS deliverable_id,
    TRY_TO_DATE(DATE)                          AS work_date,
    HOURS                                      AS hours_worked,
    TRY_TO_TIMESTAMP(LAST_UPDATE)              AS last_update_ts,
    -- Pre-compute YYYYMM for monthly aggregation joins
    YEAR(TRY_TO_DATE(DATE)) * 100
        + MONTH(TRY_TO_DATE(DATE))             AS year_month_int,
    -- Pre-compute month-end date_key for FK to DimDate
    TO_NUMBER(
        TO_VARCHAR(LAST_DAY(TRY_TO_DATE(DATE)), 'YYYYMMDD')
    )                                          AS month_end_date_key
FROM source
WHERE TRY_TO_DATE(DATE) IS NOT NULL
