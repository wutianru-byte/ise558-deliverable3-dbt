-- staging/stg_location.sql
-- 40 rows. Used by stg_client to enrich with state/city.

{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('consulting', 'LOCATION') }}
)

SELECT
    LOCATIONID  AS location_id,
    STATE       AS state,
    CITY        AS city
FROM source
