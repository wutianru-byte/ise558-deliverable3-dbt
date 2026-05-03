{{ config(materialized='table') }}

WITH all_dates AS (
    SELECT TRY_TO_DATE(DATE) AS activity_date
    FROM CONSULTING_DB_INITIAL.CONSULTING.CONSULTANTDELIVERABLE

    UNION

    SELECT TRY_TO_DATE(DATE) AS activity_date
    FROM CONSULTING_DB_INITIAL.CONSULTING.PROJECTEXPENSE
),
month_dates AS (
    SELECT DISTINCT
        DATE_TRUNC('MONTH', activity_date) AS month_start_date
    FROM all_dates
    WHERE activity_date IS NOT NULL
)

SELECT
    TO_NUMBER(TO_CHAR(month_start_date, 'YYYYMMDD')) AS DATE_KEY,
    month_start_date AS MONTH_START_DATE,
    EXTRACT(MONTH FROM month_start_date) AS MONTH,
    EXTRACT(QUARTER FROM month_start_date) AS QUARTER,
    EXTRACT(YEAR FROM month_start_date) AS YEAR
FROM month_dates
