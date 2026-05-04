-- staging/stg_projectexpense.sql
-- 72 expense rows. IS_BILLABLE is 0/1 -> cast to boolean.

{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('consulting', 'PROJECTEXPENSE') }}
)

SELECT
    RECORDID                                   AS expense_id,
    PROJECTID                                  AS project_id,
    DELIVERABLEID                              AS deliverable_id,        -- nullable
    TRY_TO_DATE(DATE)                          AS expense_date,
    AMOUNT                                     AS expense_amount,
    DESCRIPTION                                AS description,
    CATEGORY                                   AS category_name,
    CASE WHEN IS_BILLABLE = 1 THEN TRUE ELSE FALSE END
                                               AS is_billable,
    YEAR(TRY_TO_DATE(DATE)) * 100
        + MONTH(TRY_TO_DATE(DATE))             AS year_month_int,
    TO_NUMBER(
        TO_VARCHAR(TRY_TO_DATE(DATE), 'YYYYMMDD')
    )                                          AS expense_date_key
FROM source
WHERE TRY_TO_DATE(DATE) IS NOT NULL
