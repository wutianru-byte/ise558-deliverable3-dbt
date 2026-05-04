# Financial Reporting DataMart

Owner: Haichuan Zhou (Group 14, ISE 558 Spring 2026 — Deliverable 3)

End-to-end ELT pipeline that loads the consulting-firm operational database into a Financial Reporting DataMart, built with **dbt Core 1.9.4** on **Snowflake**.

## What this folder contains

| File | Purpose |
|------|---------|
| `design_v2.md` | Revised mart design + diff vs D2 |
| `s2t_mapping.xlsx` | Source-to-target mapping (12 sheets, 109 rows) |
| `validation_report.md` | Source DB query vs Mart query — same-result verification |
| `source_db_notes.md` | Notes on the 17 source tables (schema + key value findings) |
| `star_schema_v2.drawio` | Editable star schema (3 pages, one per fact table) |
| `screenshots/` | dbt run results, mart materialization, validation queries |

## Where the dbt code lives

The actual dbt models for this datamart are at the repo root:
- `models/financial/staging/`       12 staging views
- `models/financial/intermediate/`  4 ephemeral CTEs
- `models/financial/conformed/`     5 conformed dims (shared with HR + Project Delivery)
- `models/financial/facts/`         3 financial-specific dims + 3 fact tables
- `snapshots/project_snapshot.sql`  SCD2 of PROJECT

## DataMart at a glance

Three fact tables (galaxy schema):

| Fact | Grain | Rows |
|------|-------|------|
| `fact_project_financial_snapshot` | project × month (Periodic Snapshot) | 99 |
| `fact_labor_cost` | consultant × deliverable × month | 870 |
| `fact_project_expense` | expense line item (1:1 with source) | 72 |

## Validation

Question: *"What is the total billable expense by category in 2024?"*

Source vs Mart: **identical to the cent** — 5 categories, 49 expenses, $23,060.47 total.

| Category | Source / Mart Total |
|----------|---:|
| Subcontractor Fees | $13,617.55 |
| Travel | $4,066.19 |
| Software Licenses | $2,535.22 |
| Training | $1,536.04 |
| Telecommunication | $1,305.47 |

See `validation_report.md` for full details.
