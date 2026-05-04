-- snapshots/project_snapshot.sql
-- SCD2 snapshot of PROJECT table.
-- check_cols: dbt expires the current row and inserts a new one whenever
-- any of these columns changes between runs.
-- This is the mechanism that captures changes when CONSULTING_UPDATED
-- schema replaces CONSULTING in the source share.

{% snapshot project_snapshot %}

{{
    config(
        target_schema='financial_snapshots',
        unique_key='project_id',
        strategy='check',
        check_cols=[
            'project_status',
            'contract_value',
            'progress_pct',
            'actual_start_date',
            'actual_end_date',
            'planned_end_date',
            'estimated_budget'
        ],
        invalidate_hard_deletes=True
    )
}}

SELECT
    project_id,
    project_name,
    project_type,
    client_id,
    business_unit_id,
    contract_value,
    estimated_budget,
    planned_hours,
    planned_start_date,
    planned_end_date,
    project_status,
    actual_start_date,
    actual_end_date,
    progress_pct
FROM {{ ref('stg_project') }}

{% endsnapshot %}
