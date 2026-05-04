-- marts/conformed/dim_businessunit.sql
-- 4 rows. BU name is implicitly the geographic region.

{{ config(materialized='table') }}

SELECT
    MD5(business_unit_id::STRING)               AS business_unit_key,
    business_unit_id,
    bu_name
FROM {{ ref('stg_businessunit') }}
