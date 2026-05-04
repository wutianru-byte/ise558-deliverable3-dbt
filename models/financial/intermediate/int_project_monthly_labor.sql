-- intermediate/int_project_monthly_labor.sql
-- Sum labor cost per project per month.
-- = SUM(hours_worked * hourly_cost_rate) by project, year_month_int.

WITH labor AS (
    SELECT * FROM {{ ref('stg_consultantdeliverable') }}
),
deliverable AS (
    SELECT deliverable_id, project_id FROM {{ ref('stg_deliverable') }}
),
cost_rate AS (
    SELECT * FROM {{ ref('int_consultant_cost_rate') }}
)

SELECT
    d.project_id,
    l.year_month_int,
    SUM(l.hours_worked * cr.hourly_cost_rate)   AS labor_cost,
    SUM(l.hours_worked)                         AS total_hours
FROM labor l
INNER JOIN deliverable d
    ON d.deliverable_id = l.deliverable_id
LEFT JOIN cost_rate cr
    ON cr.consultant_id = l.consultant_id
    AND l.work_date >= cr.valid_from
    AND (cr.valid_to IS NULL OR l.work_date <= cr.valid_to)
GROUP BY d.project_id, l.year_month_int
