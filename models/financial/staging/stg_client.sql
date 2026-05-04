-- staging/stg_client.sql
-- 355 rows. JOINs LOCATION to denormalize state/city.

{{ config(materialized='view') }}

WITH client AS (
    SELECT * FROM {{ source('consulting', 'CLIENT') }}
),
location AS (
    SELECT * FROM {{ ref('stg_location') }}
)

SELECT
    c.CLIENTID                                AS client_id,
    c.CLIENT_NAME                             AS client_name,
    c.LOCATIONID                              AS location_id,
    l.state                                   AS state,
    l.city                                    AS city,
    c.PHONE_NUMBER                            AS phone,
    c.EMAIL                                   AS email,
    TRY_TO_TIMESTAMP(c.LAST_UPDATE)           AS last_update_ts
FROM client c
LEFT JOIN location l
    ON c.LOCATIONID = l.location_id
