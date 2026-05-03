{{ config(materialized='table') }}

WITH

base AS (
    SELECT
        CONSULTANTID,
        BUSINESSUNITID,
        FIRST_NAME,
        LAST_NAME,
        EMAIL,
        HIRE_YEAR
    FROM {{ source('consulting', 'CONSULTANT') }}
),

-- Derive hire and termination dates from the title-history event log
hire_termination AS (
    SELECT
        CONSULTANTID,
        MIN(CASE WHEN EVENT_TYPE = 'Hire'   THEN TRY_TO_DATE(START_DATE) END) AS hire_date,
        MAX(CASE WHEN EVENT_TYPE = 'Layoff' THEN TRY_TO_DATE(START_DATE) END) AS termination_date
    FROM {{ source('consulting', 'CONSULTANTTITLEHISTORY') }}
    GROUP BY CONSULTANTID
),

-- Latest title and annual salary per consultant (Type 1 snapshot)
current_title_salary AS (
    SELECT
        CONSULTANTID,
        TITLEID AS current_title_id,
        SALARY  AS current_annual_salary
    FROM {{ source('consulting', 'CONSULTANTTITLEHISTORY') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY CONSULTANTID
        ORDER BY TRY_TO_DATE(START_DATE) DESC
    ) = 1
)

SELECT
    ROW_NUMBER() OVER (ORDER BY b.CONSULTANTID)              AS CONSULTANT_KEY,
    b.CONSULTANTID                                           AS CONSULTANT_ID,
    b.FIRST_NAME,
    b.LAST_NAME,
    CONCAT(b.FIRST_NAME, ' ', b.LAST_NAME)                   AS FULL_NAME,
    b.EMAIL,
    b.BUSINESSUNITID                                         AS BUSINESS_UNIT_ID,
    b.HIRE_YEAR,
    h.hire_date                                              AS HIRE_DATE,
    h.termination_date                                       AS TERMINATION_DATE,
    CASE
        WHEN h.termination_date IS NULL THEN 'Active'
        ELSE 'Terminated'
    END                                                      AS EMPLOYMENT_STATUS,
    c.current_title_id                                       AS CURRENT_TITLE_ID,
    c.current_annual_salary                                  AS CURRENT_ANNUAL_SALARY
FROM base b
LEFT JOIN hire_termination     h USING (CONSULTANTID)
LEFT JOIN current_title_salary c USING (CONSULTANTID)
