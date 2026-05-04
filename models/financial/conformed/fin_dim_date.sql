-- marts/conformed/dim_date.sql
-- Generated calendar from 2020-01-01 to 2030-12-31 (4018 rows).
-- No source dependency; used by every fact table for time-based analysis.

{{ config(materialized='table') }}

WITH date_spine AS (
    SELECT
        DATEADD(day, SEQ4(), '2020-01-01'::DATE) AS full_date
    FROM TABLE(GENERATOR(ROWCOUNT => 4018))
)

SELECT
    TO_NUMBER(TO_VARCHAR(full_date, 'YYYYMMDD'))      AS date_key,
    full_date,
    YEAR(full_date)                                    AS calendar_year,
    QUARTER(full_date)                                 AS calendar_quarter,
    MONTH(full_date)                                   AS calendar_month,
    TRIM(TO_CHAR(full_date, 'MMMM'))                   AS month_name,
    DAY(full_date)                                     AS day_of_month,
    TRIM(TO_CHAR(full_date, 'DAY'))                    AS day_of_week,
    full_date = LAST_DAY(full_date)                    AS is_month_end,
    full_date = LAST_DAY(full_date, 'QUARTER')         AS is_quarter_end,
    (MONTH(full_date) = 12 AND DAY(full_date) = 31)    AS is_year_end,
    DAYOFWEEK(full_date) IN (0, 6)                     AS is_weekend,
    YEAR(full_date) * 100 + MONTH(full_date)           AS year_month_int
FROM date_spine
