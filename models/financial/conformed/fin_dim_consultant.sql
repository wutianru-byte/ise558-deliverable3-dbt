-- marts/conformed/dim_consultant.sql
-- SCD2 dim built directly from CONSULTANTTITLEHISTORY (which is already a history table).
-- Each Hire/Promotion/Raise event creates a new dim version.
-- A Layoff event end-dates the latest version (employment_status = 'Terminated').

{{ config(materialized='table') }}

WITH consultant AS (
    SELECT * FROM {{ ref('stg_consultant') }}
),
title_history AS (
    SELECT * FROM {{ ref('stg_consultanttitlehistory') }}
),
title AS (
    SELECT * FROM {{ ref('stg_title') }}
),

-- Title periods = events that change title or salary (Hire, Promotion, Raise).
-- In baseline data only Hire exists (108 rows); Promotion/Raise will appear in
-- CONSULTING_UPDATED schema for incremental load demo.
title_periods AS (
    SELECT
        consultant_id,
        title_id,
        salary,
        start_date AS valid_from,
        end_date   AS valid_to,
        is_current
    FROM title_history
    WHERE event_type IN ('Hire', 'Promotion', 'Raise')
),

-- Layoffs end-date the latest title period for that consultant.
layoffs AS (
    SELECT
        consultant_id,
        MIN(start_date) AS termination_date
    FROM title_history
    WHERE event_type = 'Layoff'
    GROUP BY consultant_id
)

SELECT
    MD5(tp.consultant_id || '|' || tp.valid_from::STRING) AS consultant_key,
    tp.consultant_id,
    c.first_name,
    c.last_name,
    c.email,
    MD5(c.business_unit_id::STRING)             AS business_unit_key,
    c.hire_year,
    -- Current title at this dim version
    MD5(tp.title_id::STRING)                    AS current_title_key,
    tp.title_id,
    t.title_name                                AS current_title_name,
    t.title_level                               AS current_title_level,
    tp.salary                                   AS current_salary,
    -- SCD2 validity
    tp.valid_from                               AS dbt_valid_from,
    -- If laid off and this is the latest period, override valid_to with termination_date
    CASE
        WHEN tp.is_current AND l.termination_date IS NOT NULL
            THEN l.termination_date
        ELSE tp.valid_to
    END                                         AS dbt_valid_to,
    -- Employment status:
    --   'Terminated' if this is the latest period AND there's a layoff event
    --   'Active'     otherwise
    CASE
        WHEN tp.is_current AND l.termination_date IS NOT NULL THEN 'Terminated'
        ELSE 'Active'
    END                                         AS employment_status,
    l.termination_date,
    -- is_current: only the most recent period AND not terminated
    (tp.is_current AND l.termination_date IS NULL) AS is_current
FROM title_periods tp
INNER JOIN consultant c   ON c.consultant_id = tp.consultant_id
INNER JOIN title t        ON t.title_id      = tp.title_id
LEFT  JOIN layoffs l      ON l.consultant_id = tp.consultant_id
