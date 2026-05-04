-- intermediate/int_project_monthly_revenue.sql
-- Per project x month, recognize revenue per business rules:
--   * FP: SUM(DELIVERABLE.PRICE) where INVOICED_DATE in this month
--   * T&M: SUM(HOURS * billing_rate) + SUM(billable expense_amount)

WITH project AS (
    SELECT project_id, project_type FROM {{ ref('stg_project') }}
),

-- ====== Fixed-Price revenue: triggered by INVOICED_DATE ======
fp_rev AS (
    SELECT
        d.project_id,
        YEAR(d.invoiced_date) * 100 + MONTH(d.invoiced_date) AS year_month_int,
        SUM(d.price)                            AS revenue_recognized
    FROM {{ ref('stg_deliverable') }} d
    INNER JOIN project p ON p.project_id = d.project_id
    WHERE p.project_type = 'Fixed'
      AND d.invoiced_date IS NOT NULL
      AND d.price IS NOT NULL
    GROUP BY d.project_id, year_month_int
),

-- ====== T&M revenue: hours x billing_rate ======
tm_labor_rev AS (
    SELECT
        d.project_id,
        cd.year_month_int,
        SUM(cd.hours_worked * br.billing_rate)  AS revenue_recognized
    FROM {{ ref('stg_consultantdeliverable') }} cd
    INNER JOIN {{ ref('stg_deliverable') }} d
        ON d.deliverable_id = cd.deliverable_id
    INNER JOIN project p
        ON p.project_id = d.project_id
        AND p.project_type = 'Time and Material'
    -- Find consultant title at work date for billing rate lookup
    INNER JOIN {{ ref('stg_consultanttitlehistory') }} th
        ON th.consultant_id = cd.consultant_id
        AND cd.work_date >= th.start_date
        AND (th.end_date IS NULL OR cd.work_date <= th.end_date)
        AND th.event_type IN ('Hire', 'Promotion', 'Raise')
    INNER JOIN {{ ref('stg_projectbillingrate') }} br
        ON br.project_id = d.project_id
        AND br.title_id = th.title_id
    GROUP BY d.project_id, cd.year_month_int
),

-- ====== T&M billable expense passthrough revenue ======
tm_exp_rev AS (
    SELECT
        e.project_id,
        e.year_month_int,
        SUM(e.expense_amount)                   AS revenue_recognized
    FROM {{ ref('stg_projectexpense') }} e
    INNER JOIN project p
        ON p.project_id = e.project_id
        AND p.project_type = 'Time and Material'
    WHERE e.is_billable = TRUE
    GROUP BY e.project_id, e.year_month_int
),

-- Union all 3 sources
all_rev AS (
    SELECT * FROM fp_rev
    UNION ALL
    SELECT * FROM tm_labor_rev
    UNION ALL
    SELECT * FROM tm_exp_rev
)

SELECT
    project_id,
    year_month_int,
    SUM(revenue_recognized)                     AS revenue_recognized
FROM all_rev
GROUP BY project_id, year_month_int
