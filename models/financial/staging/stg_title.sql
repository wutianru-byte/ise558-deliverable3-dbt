-- staging/stg_title.sql
-- 6 rows. Adds title_level (seniority rank 1-6) via CASE.

{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('consulting', 'TITLE') }}
)

SELECT
    TITLEID                                    AS title_id,
    TITLE_NAME                                 AS title_name,
    CASE TITLE_NAME
        WHEN 'Junior Consultant' THEN 1
        WHEN 'Consultant'        THEN 2
        WHEN 'Senior Consultant' THEN 3
        WHEN 'Lead Consultant'   THEN 4
        WHEN 'Project Manager'   THEN 5
        WHEN 'Vice President'    THEN 6
    END                                        AS title_level
FROM source
