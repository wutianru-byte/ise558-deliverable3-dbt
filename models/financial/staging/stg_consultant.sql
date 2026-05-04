-- staging/stg_consultant.sql
-- 108 rows. Note: source col BUSINESSUNITID (vs UNITID in PROJECT).

{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('consulting', 'CONSULTANT') }}
)

SELECT
    CONSULTANTID                               AS consultant_id,
    BUSINESSUNITID                             AS business_unit_id,
    FIRST_NAME                                 AS first_name,
    LAST_NAME                                  AS last_name,
    EMAIL                                      AS email,
    CONTACT                                    AS contact,
    HIRE_YEAR                                  AS hire_year,
    TRY_TO_TIMESTAMP(LAST_UPDATE)              AS last_update_ts
FROM source
