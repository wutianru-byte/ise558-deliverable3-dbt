-- intermediate/int_project_monthly_expense.sql
-- Sum expense cost per project per month.

SELECT
    project_id,
    year_month_int,
    SUM(expense_amount)                         AS expense_cost,
    SUM(CASE WHEN is_billable THEN expense_amount ELSE 0 END)
                                                AS billable_expense_amount
FROM {{ ref('stg_projectexpense') }}
GROUP BY project_id, year_month_int
