{{ config(materialized='table') }}

SELECT
    ROW_NUMBER() OVER (ORDER BY TITLEID) AS TITLE_KEY,
    TITLEID                              AS TITLE_ID,
    TITLE_NAME,
    CAST(SUBSTR(TITLEID, 2) AS INTEGER)  AS LEVEL_RANK
FROM {{ source('consulting', 'TITLE') }}
