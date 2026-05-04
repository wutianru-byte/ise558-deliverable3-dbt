-- marts/conformed/dim_project.sql
-- SCD2 dim from project_snapshot. Captures changes when source updates.
-- Reads dbt_valid_from / dbt_valid_to / dbt_scd_id added by snapshot mechanism.

{{ config(materialized='table') }}

WITH snap AS (
    SELECT * FROM {{ ref('project_snapshot') }}
)

SELECT
    -- Use dbt's built-in scd_id as the surrogate key (already MD5 of NK + valid_from)
    snap.dbt_scd_id                             AS project_key,
    snap.project_id,
    snap.project_name,
    snap.project_type,                          -- 'Fixed' or 'Time and Material'
    snap.project_status,                        -- 'Not Started' / 'In Progress' / 'Completed'
    -- FK lookups (denormalized for query convenience)
    MD5(snap.client_id::STRING)                 AS client_key,
    MD5(snap.business_unit_id::STRING)          AS business_unit_key,
    snap.client_id,
    snap.business_unit_id,
    -- Date keys (NULL-safe)
    CASE WHEN snap.planned_start_date IS NULL THEN NULL
         ELSE TO_NUMBER(TO_VARCHAR(snap.planned_start_date, 'YYYYMMDD')) END
                                                AS planned_start_date_key,
    CASE WHEN snap.planned_end_date IS NULL THEN NULL
         ELSE TO_NUMBER(TO_VARCHAR(snap.planned_end_date, 'YYYYMMDD')) END
                                                AS planned_end_date_key,
    CASE WHEN snap.actual_start_date IS NULL THEN NULL
         ELSE TO_NUMBER(TO_VARCHAR(snap.actual_start_date, 'YYYYMMDD')) END
                                                AS actual_start_date_key,
    CASE WHEN snap.actual_end_date IS NULL THEN NULL
         ELSE TO_NUMBER(TO_VARCHAR(snap.actual_end_date, 'YYYYMMDD')) END
                                                AS actual_end_date_key,
    -- Money / hours
    snap.contract_value,                        -- NULL on T&M
    snap.estimated_budget,
    snap.planned_hours,
    snap.progress_pct,                          -- 0-100
    -- SCD2 metadata (from snapshot)
    snap.dbt_valid_from,
    snap.dbt_valid_to,
    (snap.dbt_valid_to IS NULL)                 AS is_current
FROM snap
