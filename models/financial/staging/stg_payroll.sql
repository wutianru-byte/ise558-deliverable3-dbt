-- staging/stg_payroll.sql
-- 638 payroll payments. AMOUNT is monthly salary payment.
-- (Optional reconciliation source; primary cost rate uses CONSULTANTTITLEHISTORY.SALARY / 2080.)

{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('consulting', 'PAYROLL') }}
)

SELECT
    RECORDID                                   AS record_id,
    CONSULTANTID                               AS consultant_id,
    AMOUNT                                     AS amount,
    TRY_TO_DATE(PAYMENT_DATE)                  AS payment_date,
    YEAR(TRY_TO_DATE(PAYMENT_DATE)) * 100
        + MONTH(TRY_TO_DATE(PAYMENT_DATE))     AS year_month_int
FROM source
WHERE TRY_TO_DATE(PAYMENT_DATE) IS NOT NULL
