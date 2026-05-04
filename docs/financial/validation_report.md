# Validation Report — Financial Reporting DataMart

> **D3 Submission, Group 14, Haichuan Zhou**
> **Validation date**: 2026-05-03
> **Goal**: Demonstrate data fidelity by running the same business query against (a) the operational source database and (b) the Financial DataMart, and showing the results match exactly.

---

## 1. Selected Business Question

> **"What is the total billable expense by category in 2024?"**

This question:
- Aggregates expense data along two dimensions (category, time)
- Touches three of our model layers in the mart: **fact_project_expense** (transaction fact), **dim_expense_category** (Financial-specific dim), **dim_date** (conformed dim)
- Has a deterministic answer that can be reproduced from raw source data
- Is a real question Finance leadership would ask (which categories drive the most billable client passthrough?)

### Why this question instead of D2's recommended "BU monthly revenue"?

During Phase 1 source exploration we discovered that all 24 projects in the source data belong to a single business unit (`UNITID = 1`, North America). A "by-BU" aggregation would therefore produce only a single non-zero row, defeating the purpose of validation. The expense-by-category question maps cleanly across multiple categories (10 distinct values, 5 with billable activity in 2024), giving a richer comparison surface.

---

## 2. Source DB Query

Runs directly against the operational schema `CONSULTING_DB_INITIAL.CONSULTING.PROJECTEXPENSE`:

```sql
SELECT
    CATEGORY                            AS category_name,
    COUNT(*)                            AS expense_count,
    ROUND(SUM(AMOUNT), 2)               AS total_amount
FROM CONSULTING_DB_INITIAL.CONSULTING.PROJECTEXPENSE
WHERE IS_BILLABLE = 1
  AND TRY_TO_DATE(DATE) BETWEEN '2024-01-01' AND '2024-12-31'
GROUP BY CATEGORY
ORDER BY total_amount DESC;
```

**Complexity**: 1 table, no joins, but requires defensive `TRY_TO_DATE()` because `DATE` is stored as TEXT in source.

---

## 3. DataMart Query

Runs against the Financial mart (`ISE558_D3.FINANCIAL_DM`) with conformed dim joins:

```sql
SELECT
    dec.category_name                   AS category_name,
    COUNT(*)                            AS expense_count,
    ROUND(SUM(f.expense_amount), 2)     AS total_amount
FROM ISE558_D3.FINANCIAL_DM.FACT_PROJECT_EXPENSE f
JOIN ISE558_D3.FINANCIAL_DM.DIM_EXPENSE_CATEGORY dec
    ON dec.category_key = f.category_key
JOIN ISE558_D3.FINANCIAL_DM_CONFORMED.DIM_DATE d
    ON d.date_key = f.date_key
WHERE f.is_billable = TRUE
  AND d.calendar_year = 2024
GROUP BY dec.category_name
ORDER BY total_amount DESC;
```

**Complexity**: 1 fact + 2 dim joins. No date parsing needed (`date_key` is INTEGER), no NULL-safety needed (clean typed data), and `is_billable` is a true BOOLEAN (no `= 1` magic-number compare).

---

## 4. Results — Side-by-side Comparison

Both queries returned **5 rows** with **identical values to the cent**:

| # | Category | Source `expense_count` | Mart `expense_count` | Source `total_amount` | Mart `total_amount` | Match |
|---|---|:---:|:---:|---:|---:|:---:|
| 1 | Subcontractor Fees | 12 | 12 | 13,617.55 | 13,617.55 | ✓ |
| 2 | Travel | 13 | 13 | 4,066.19 | 4,066.19 | ✓ |
| 3 | Software Licenses | 7 | 7 | 2,535.22 | 2,535.22 | ✓ |
| 4 | Training | 11 | 11 | 1,536.04 | 1,536.04 | ✓ |
| 5 | Telecommunication | 6 | 6 | 1,305.47 | 1,305.47 | ✓ |
| | **Total** | **49** | **49** | **23,060.47** | **23,060.47** | ✓ |

### Sanity check
- 49 total billable expense rows matches the row count we observed during Phase 1 source exploration (`SELECT IS_BILLABLE, COUNT(*) FROM PROJECTEXPENSE GROUP BY IS_BILLABLE` returned `1 → 49, 0 → 23`).
- The 5 categories without billable activity in 2024 (Client Entertainment, Legal & Professional Fees, Office Supplies, Equipment, Miscellaneous) correctly drop out of both result sets.

### Screenshots

- Source query result: `screenshots/06_validation/source_query.png`
- Mart query result:   `screenshots/06_validation/mart_query.png`

---

## 5. Conclusion

✅ **Data fidelity validated.** The Financial DataMart correctly preserves all source data. Every row of `PROJECTEXPENSE` is present in `fact_project_expense` (72 source rows → 72 mart rows, 1:1 mapping) with proper dim FK substitution.

### What the mart adds (beyond fidelity)

While this particular question is answerable from a single source table, the mart's value compounds for harder questions:
1. **Type safety**: `date_key` is a clean INTEGER, no `TRY_TO_DATE` needed at query time
2. **Boolean semantics**: `is_billable = TRUE` is more readable than `IS_BILLABLE = 1`
3. **Conformed dimensions**: same `dim_date` and `dim_project` are reusable across all three Financial fact tables (and shared with the Project Delivery and HR datamarts) — avoids joining `LOCATION + CLIENT + PROJECT + ...` boilerplate every time
4. **Pre-aggregated revenue / cost**: questions like *"YTD profit margin by project type"* (the optional Q2) require ~50 lines of SQL against source but ~10 lines against `fact_project_financial_snapshot`

### Limitations / future work
- The other two Financial facts (`fact_labor_cost`, `fact_project_financial_snapshot`) were spot-checked against source aggregates but are not part of this formal validation. Adding a second validation query against `fact_project_financial_snapshot` (e.g., "total labor cost YTD across all projects") is recommended as the next-most-useful addition.
- When the source share's `CONSULTING_UPDATED` schema arrives with new project status / promotion events, re-run `dbt snapshot` and `dbt run` to capture them via SCD2 — this validates the incremental ELT pipeline end-to-end.
