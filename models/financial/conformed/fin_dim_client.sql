-- marts/conformed/dim_client.sql
-- 355 clients with state/city joined from LOCATION.

{{ config(materialized='table') }}

SELECT
    MD5(client_id::STRING)                      AS client_key,
    client_id,
    client_name,
    state,
    city,
    phone,
    email
FROM {{ ref('stg_client') }}
