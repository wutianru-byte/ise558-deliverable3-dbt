{{ config(materialized='table') }}

WITH

-- Monthly billable + non-billable hours per consultant
monthly_hours AS (
    SELECT
        CONSULTANTID,
        DATE_TRUNC('MONTH', TRY_TO_DATE(DATE)) AS month_start_date,
        SUM(BILLABLE_HOURS)                    AS billable_hours,
        SUM(TABLE_NONBILLABLEHOURS)            AS non_billable_hours
    FROM {{ source('consulting', 'NON_BILLABLE_HOURS') }}
    GROUP BY CONSULTANTID, DATE_TRUNC('MONTH', TRY_TO_DATE(DATE))
),

-- Monthly payroll amount per consultant
monthly_payroll AS (
    SELECT
        CONSULTANTID,
        DATE_TRUNC('MONTH', TRY_TO_DATE(PAYMENT_DATE)) AS month_start_date,
        SUM(AMOUNT)                                    AS payroll_amount
    FROM {{ source('consulting', 'PAYROLL') }}
    GROUP BY CONSULTANTID, DATE_TRUNC('MONTH', TRY_TO_DATE(PAYMENT_DATE))
),

-- Universe of (consultant, month) we must produce a row for
consultant_months AS (
    SELECT CONSULTANTID, month_start_date FROM monthly_hours
    UNION
    SELECT CONSULTANTID, month_start_date FROM monthly_payroll
),

-- Effective title and annual salary per (consultant, month):
-- pick the latest CONSULTANTTITLEHISTORY row whose START_DATE <= month_start_date
effective_title_salary AS (
    SELECT
        cm.CONSULTANTID,
        cm.month_start_date,
        th.TITLEID AS effective_title_id,
        th.SALARY  AS effective_annual_salary
    FROM consultant_months cm
    JOIN {{ source('consulting', 'CONSULTANTTITLEHISTORY') }} th
        ON cm.CONSULTANTID = th.CONSULTANTID
        AND TRY_TO_DATE(th.START_DATE) <= cm.month_start_date
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY cm.CONSULTANTID, cm.month_start_date
        ORDER BY TRY_TO_DATE(th.START_DATE) DESC
    ) = 1
),

-- Promotion month flag (will be empty in current data — only Hire/Layoff events exist)
promotion_events AS (
    SELECT
        CONSULTANTID,
        DATE_TRUNC('MONTH', TRY_TO_DATE(START_DATE)) AS month_start_date,
        1 AS is_promoted
    FROM {{ source('consulting', 'CONSULTANTTITLEHISTORY') }}
    WHERE EVENT_TYPE = 'Promotion'
)

SELECT
    ROW_NUMBER() OVER (
        ORDER BY cm.CONSULTANTID, cm.month_start_date
    )                                                  AS HR_MONTHLY_KEY,

    -- Surrogate keys (from dimensions)
    dc.CONSULTANT_KEY,
    dt.TITLE_KEY,
    dbu.BUSINESS_UNIT_KEY,
    dd.DATE_KEY,

    -- Natural keys retained for traceability
    cm.CONSULTANTID                                    AS CONSULTANT_ID,
    cm.month_start_date                                AS MONTH_START_DATE,

    -- Hours measures
    COALESCE(mh.billable_hours, 0)                     AS BILLABLE_HOURS,
    COALESCE(mh.non_billable_hours, 0)                 AS NON_BILLABLE_HOURS,
    COALESCE(mh.billable_hours, 0)
        + COALESCE(mh.non_billable_hours, 0)           AS TOTAL_HOURS_WORKED,
    160                                                AS AVAILABLE_HOURS,
    DIV0(COALESCE(mh.billable_hours, 0), 160)          AS UTILIZATION_RATE,

    -- Salary measures
    ets.effective_annual_salary                        AS ANNUAL_SALARY,
    COALESCE(mp.payroll_amount, 0)                     AS PAYROLL_AMOUNT,

    -- Event flags
    COALESCE(pe.is_promoted, 0)                        AS IS_PROMOTED,
    CASE
        WHEN dc.HIRE_DATE <= LAST_DAY(cm.month_start_date)
         AND (dc.TERMINATION_DATE IS NULL
              OR dc.TERMINATION_DATE > LAST_DAY(cm.month_start_date))
        THEN 1 ELSE 0
    END                                                AS HEADCOUNT_FLAG

FROM consultant_months cm
LEFT JOIN {{ ref('dim_consultant') }}     dc  ON cm.CONSULTANTID      = dc.CONSULTANT_ID
LEFT JOIN effective_title_salary          ets ON cm.CONSULTANTID      = ets.CONSULTANTID
                                            AND cm.month_start_date = ets.month_start_date
LEFT JOIN {{ ref('dim_title') }}          dt  ON ets.effective_title_id = dt.TITLE_ID
LEFT JOIN {{ ref('dim_business_unit') }}  dbu ON dc.BUSINESS_UNIT_ID  = dbu.BUSINESS_UNIT_ID
LEFT JOIN {{ ref('dim_date') }}           dd  ON cm.month_start_date  = dd.MONTH_START_DATE
LEFT JOIN monthly_hours                   mh  ON cm.CONSULTANTID      = mh.CONSULTANTID
                                            AND cm.month_start_date = mh.month_start_date
LEFT JOIN monthly_payroll                 mp  ON cm.CONSULTANTID      = mp.CONSULTANTID
                                            AND cm.month_start_date = mp.month_start_date
LEFT JOIN promotion_events                pe  ON cm.CONSULTANTID      = pe.CONSULTANTID
                                            AND cm.month_start_date = pe.month_start_date
