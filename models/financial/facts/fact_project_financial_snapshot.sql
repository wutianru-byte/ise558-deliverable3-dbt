-- marts/financial/fact_project_financial_snapshot.sql
-- Grain: 1 row per project per month-end (Periodic Snapshot).
-- Generates a row for each month between project effective_start and
-- min(effective_end, current month).

{{ config(materialized='table') }}

WITH proj_stg AS (
    SELECT * FROM {{ ref('stg_project') }}
),
dim_proj AS (
    SELECT * FROM {{ ref('fin_dim_project') }} WHERE is_current
),

-- Combine stg dates with dim surrogate keys
project AS (
    SELECT
        s.project_id,
        s.project_type,
        d.project_key,
        d.client_key,
        d.business_unit_key,
        s.contract_value,
        s.estimated_budget,
        s.planned_hours,
        s.progress_pct,
        COALESCE(s.actual_start_date, s.planned_start_date) AS effective_start,
        COALESCE(s.actual_end_date,   s.planned_end_date)   AS effective_end
    FROM proj_stg s
    INNER JOIN dim_proj d ON d.project_id = s.project_id
),

-- All month-ends in calendar (filtered to past + current)
month_ends AS (
    SELECT date_key AS month_key, full_date AS month_end, year_month_int
    FROM {{ ref('fin_dim_date') }}
    WHERE is_month_end
      AND full_date <= LAST_DAY(CURRENT_DATE())
),

-- Cross product: each project x each month between start and end
project_months AS (
    SELECT
        p.*,
        m.month_key,
        m.month_end,
        m.year_month_int
    FROM project p
    INNER JOIN month_ends m
        ON m.month_end >= DATE_TRUNC('month', p.effective_start)
        AND m.month_end <= LEAST(
                COALESCE(p.effective_end, CURRENT_DATE()),
                CURRENT_DATE()
            )
),

-- Pull pre-aggregated revenue / labor / expense
rev AS (
    SELECT * FROM {{ ref('int_project_monthly_revenue') }}
),
labor AS (
    SELECT * FROM {{ ref('int_project_monthly_labor') }}
),
expense AS (
    SELECT * FROM {{ ref('int_project_monthly_expense') }}
),

-- Combine
combined AS (
    SELECT
        pm.month_key,
        pm.project_key,
        pm.client_key,
        pm.business_unit_key,
        pm.project_id,
        pm.project_type,
        pm.contract_value,
        pm.estimated_budget,
        pm.planned_hours,
        pm.progress_pct,
        pm.year_month_int,
        COALESCE(r.revenue_recognized, 0)       AS revenue_recognized,
        COALESCE(l.labor_cost, 0)               AS labor_cost,
        COALESCE(e.expense_cost, 0)             AS expense_cost
    FROM project_months pm
    LEFT JOIN rev     r ON r.project_id = pm.project_id AND r.year_month_int = pm.year_month_int
    LEFT JOIN labor   l ON l.project_id = pm.project_id AND l.year_month_int = pm.year_month_int
    LEFT JOIN expense e ON e.project_id = pm.project_id AND e.year_month_int = pm.year_month_int
),

-- Add cumulative measures
with_cum AS (
    SELECT
        c.*,
        c.labor_cost + c.expense_cost                                              AS total_cost,
        SUM(c.revenue_recognized)
            OVER (PARTITION BY c.project_id ORDER BY c.month_key)                  AS cumulative_revenue,
        SUM(c.labor_cost + c.expense_cost)
            OVER (PARTITION BY c.project_id ORDER BY c.month_key)                  AS cumulative_cost
    FROM combined c
),

-- Add forecast and profit calculations
with_forecast AS (
    SELECT
        wc.*,
        -- forecast_remaining_cost: simple linear estimate
        --   = MAX(0, estimated_budget - cumulative_cost)
        GREATEST(0, COALESCE(wc.estimated_budget, 0) - wc.cumulative_cost)
                                                AS forecast_remaining_cost
    FROM with_cum wc
)

SELECT
    month_key,
    project_key,
    client_key,
    business_unit_key,
    -- Measures
    contract_value,
    revenue_recognized,
    cumulative_revenue,
    labor_cost,
    expense_cost,
    total_cost,
    cumulative_cost,
    forecast_remaining_cost,
    cumulative_cost + forecast_remaining_cost   AS expected_total_cost,
    -- expected_profit: FP uses contract_value, T&M uses cumulative_revenue
    CASE
        WHEN project_type = 'Fixed' AND contract_value IS NOT NULL
            THEN contract_value - (cumulative_cost + forecast_remaining_cost)
        ELSE cumulative_revenue - (cumulative_cost + forecast_remaining_cost)
    END                                         AS expected_profit,
    -- profit_margin_pct: percentage of revenue/contract value
    CASE
        WHEN project_type = 'Fixed' AND contract_value IS NOT NULL AND contract_value <> 0
            THEN (contract_value - (cumulative_cost + forecast_remaining_cost))
                 / contract_value * 100
        WHEN cumulative_revenue <> 0
            THEN (cumulative_revenue - (cumulative_cost + forecast_remaining_cost))
                 / cumulative_revenue * 100
        ELSE NULL
    END                                         AS profit_margin_pct,
    progress_pct
FROM with_forecast
