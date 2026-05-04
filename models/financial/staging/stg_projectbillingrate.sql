-- staging/stg_projectbillingrate.sql
-- 42 rows. T&M billing rate by project x title (FP projects not in this table).

{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('consulting', 'PROJECTBILLINGRATE') }}
)

SELECT
    PROJECTID                                  AS project_id,
    TITLEID                                    AS title_id,
    RATE                                       AS billing_rate
FROM source
