-- intermediate/int_consultant_cost_rate.sql
-- For each consultant title period, compute hourly internal cost rate.
-- hourly_cost_rate = SALARY / 2080 (standard annual hours).
-- Downstream queries JOIN on work_date BETWEEN valid_from AND valid_to.

SELECT
    consultant_id,
    title_id,
    salary,
    start_date                                  AS valid_from,
    end_date                                    AS valid_to,
    salary / 2080.0                             AS hourly_cost_rate
FROM {{ ref('stg_consultanttitlehistory') }}
WHERE event_type IN ('Hire', 'Promotion', 'Raise')
