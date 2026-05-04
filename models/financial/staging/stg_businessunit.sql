-- staging/stg_businessunit.sql
-- 4 rows; BU name is implicitly the geographic region.

{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('consulting', 'BUSINESSUNIT') }}
)

SELECT
    BUSINESSUNITID                  AS business_unit_id,
    BUSINESS_UNIT_NAME              AS bu_name
FROM source
