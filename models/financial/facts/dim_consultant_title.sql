-- marts/financial/dim_consultant_title.sql
-- 6 rows. Title hierarchy with hardcoded seniority level 1-6.

{{ config(materialized='table') }}

SELECT
    MD5(title_id::STRING)                       AS title_key,
    title_id,
    title_name,
    title_level
FROM {{ ref('stg_title') }}
