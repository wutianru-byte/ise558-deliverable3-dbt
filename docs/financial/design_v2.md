# Financial Reporting DataMart — Design v2 (D3 Revised)

> **作者**: Haichuan (Group 14)
> **来源**: D2 设计 + Phase 1 source DB 探索（2026-05-03）
> **目的**: 把 D2 凭空写的字段对照真实 source 修订一遍，作为 Phase 3 (S2T Mapping) 和 Phase 5 (dbt 实现) 的设计真相之源。

---

## 修订总览（D2 → v2 的差异）

| 类别 | D2 原设计 | v2 修订 | 原因 |
|------|----------|---------|------|
| `DimBusinessUnit.geographic_region` | 独立字段 | **删除** | BU name 本身就是 region（North America / EMEA / Asia Pacific / Central and South America） |
| `DimClient.industry` | 独立字段 | **删除** | source `CLIENT` 表没有此字段 |
| `DimClient.client_region` | 独立字段 | 改为 `state` + `city` | source 通过 `LOCATION` 表给出 STATE + CITY，不是抽象的 region |
| `DimProject.project_type` 取值 | "Fixed-Price" / "Time and Materials" | "Fixed" / "Time and Material" | source `PROJECT.TYPE` 实际值 |
| `DimProject.contract_value` | 独立字段 | OK，但要 NULL on T&M | source `PROJECT.PRICE`，T&M 行确实 NULL |
| `DimProject` 新增 | — | `estimated_budget`, `progress`, `actual_start_date`, `actual_end_date` | source 有这些字段，对 forecast 计算有用 |
| `DimDeliverable` 新增 | — | `price`, `submission_date`, `invoiced_date`, `planned_hours` | source 有；`PRICE`+`INVOICED_DATE` 是 FP 收入触发器 |
| `PROGRESS` 单位 | 未定 | 0-100 百分比 | source 实际范围 |
| `CONSULTANTTITLEHISTORY` | 假设有 Promotion / Raise | baseline 只有 Hire / Layoff | SCD2 设计保留，但 dbt snapshot 在 UPDATE schema 才能捕获到变化 |

---

## 最终维度表清单

### 1. DimDate（Conformed · 生成式）

**Grain**: 一行一天
**SCD**: 不适用（一次生成）
**Source**: 用 `dbt_utils.date_spine` 生成 2020-01-01 到 2030-12-31（11 年 ≈ 4018 行）

| Column | Type | Notes |
|--------|------|-------|
| `date_key` | INTEGER PK | YYYYMMDD 格式 |
| `full_date` | DATE | |
| `calendar_year` | INTEGER | |
| `calendar_quarter` | INTEGER | 1-4 |
| `calendar_month` | INTEGER | 1-12 |
| `month_name` | VARCHAR | "January" |
| `day_of_month` | INTEGER | 1-31 |
| `day_of_week` | VARCHAR | "Monday" |
| `is_month_end` | BOOLEAN | |
| `is_quarter_end` | BOOLEAN | |
| `is_year_end` | BOOLEAN | |
| `is_weekend` | BOOLEAN | |
| `year_month_int` | INTEGER | YYYYMM 格式（用于和 source NON_BILLABLE_HOURS.YEARMONTH 对接） |

---

### 2. DimProject（Conformed · SCD2）

**Grain**: 一行一个 project version
**SCD**: Type 2（status 和 progress 会变；用 dbt snapshot）
**Source**: `PROJECT` 表

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `project_key` | INTEGER PK (surrogate) | `dbt_utils.generate_surrogate_key([projectid, dbt_valid_from])` | |
| `project_id` | VARCHAR Natural Key | `PROJECT.PROJECTID` | |
| `project_name` | VARCHAR | `PROJECT.NAME` | |
| `project_type` | VARCHAR | `PROJECT.TYPE` | "Fixed" / "Time and Material" |
| `project_status` | VARCHAR | `PROJECT.STATUS` | "Not Started" / "In Progress" / "Completed" |
| `client_key` | INTEGER FK | derived from `PROJECT.CLIENTID` | |
| `business_unit_key` | INTEGER FK | derived from `PROJECT.UNITID` | source 字段名是 UNITID（不是 BUSINESSUNITID） |
| `planned_start_date_key` | INTEGER FK | `PROJECT.PLANNED_START_DATE` → date_key | |
| `planned_end_date_key` | INTEGER FK | `PROJECT.PLANNED_END_DATE` → date_key | |
| `actual_start_date_key` | INTEGER FK | `PROJECT.ACTUAL_START_DATE` | nullable |
| `actual_end_date_key` | INTEGER FK | `PROJECT.ACTUAL_END_DATE` | nullable |
| `contract_value` | DECIMAL(15,2) | `PROJECT.PRICE` | NULL for T&M |
| `estimated_budget` | DECIMAL(15,2) | `PROJECT.ESTIMATED_BUDGET` | 计划成本 |
| `planned_hours` | INTEGER | `PROJECT.PLANNED_HOURS` | |
| `progress_pct` | DECIMAL(5,2) | `PROJECT.PROGRESS` | 0-100 |
| `dbt_valid_from` | TIMESTAMP | dbt snapshot 自动 | |
| `dbt_valid_to` | TIMESTAMP | dbt snapshot 自动 | NULL = 当前 |

---

### 3. DimClient（Conformed · Type 1）

**Source**: `CLIENT` 表 + `LOCATION` 表

| Column | Type | Source |
|--------|------|--------|
| `client_key` | INTEGER PK | surrogate |
| `client_id` | INTEGER NK | `CLIENT.CLIENTID` |
| `client_name` | VARCHAR | `CLIENT.CLIENT_NAME` |
| `state` | VARCHAR | `LOCATION.STATE` (join via CLIENT.LOCATIONID) |
| `city` | VARCHAR | `LOCATION.CITY` |
| `phone` | VARCHAR | `CLIENT.PHONE_NUMBER` |
| `email` | VARCHAR | `CLIENT.EMAIL` |

---

### 4. DimBusinessUnit（Conformed · Type 1）

**Source**: `BUSINESSUNIT` 表（4 行）

| Column | Type | Source |
|--------|------|--------|
| `business_unit_key` | INTEGER PK | surrogate |
| `business_unit_id` | INTEGER NK | `BUSINESSUNIT.BUSINESSUNITID` |
| `bu_name` | VARCHAR | `BUSINESSUNIT.BUSINESS_UNIT_NAME` (是 region 名) |

> 取值固定 4 个：`North America`, `Central and South America`, `EMEA`, `Asia Pacific`

---

### 5. DimConsultant（Conformed · SCD2）

**Source**: `CONSULTANT` + `CONSULTANTTITLEHISTORY`（用 dbt snapshot 维护）

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `consultant_key` | INTEGER PK | surrogate（含 valid_from） | |
| `consultant_id` | VARCHAR NK | `CONSULTANT.CONSULTANTID` | |
| `first_name` | VARCHAR | `CONSULTANT.FIRST_NAME` | Type 1 |
| `last_name` | VARCHAR | `CONSULTANT.LAST_NAME` | Type 1 |
| `email` | VARCHAR | `CONSULTANT.EMAIL` | Type 1 |
| `business_unit_key` | INTEGER FK | derived from `CONSULTANT.BUSINESSUNITID` | Type 1 |
| `hire_year` | INTEGER | `CONSULTANT.HIRE_YEAR` | |
| `current_title_key` | INTEGER FK | latest `CONSULTANTTITLEHISTORY.TITLEID` (effective on snapshot date) | Type 2 |
| `current_salary` | DECIMAL(12,2) | latest `CONSULTANTTITLEHISTORY.SALARY` | Type 2 |
| `employment_status` | VARCHAR | derived: 如果有 Layoff 事件 → "Terminated"; 否则 "Active" | Type 2 |
| `dbt_valid_from` / `dbt_valid_to` | TIMESTAMP | dbt snapshot | |

> **SCD2 设计 vs 实际数据**：baseline `CONSULTING` schema 里 `EVENT_TYPE` 只有 `Hire`/`Layoff`，没有 promotion；DimConsultant 在 baseline 上其实只有当前一行/人。**SCD2 设计保留**，等切到 `CONSULTING_UPDATED` schema 跑 incremental 再验证 promotion 事件能否被 snapshot 捕获——这是 D3 的核心演示点。

---

### 6. DimConsultantTitle（Financial 私有 · Type 1）

**Source**: `TITLE` 表（6 行 + dbt 里 hardcode level）

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `title_key` | INTEGER PK | surrogate |
| `title_id` | VARCHAR NK | `TITLE.TITLEID` |
| `title_name` | VARCHAR | `TITLE.TITLE_NAME` |
| `title_level` | INTEGER | dbt CASE WHEN | 1=Junior Consultant, 2=Consultant, 3=Senior Consultant, 4=Lead Consultant, 5=Project Manager, 6=Vice President |

---

### 7. DimDeliverable（Financial 私有 · Type 1）

**Source**: `DELIVERABLE` 表

| Column | Type | Source |
|--------|------|--------|
| `deliverable_key` | INTEGER PK | surrogate |
| `deliverable_id` | VARCHAR NK | `DELIVERABLE.DELIVERABLEID` |
| `project_key` | INTEGER FK | derived from `DELIVERABLE.PROJECTID` |
| `deliverable_name` | VARCHAR | `DELIVERABLE.NAME` |
| `planned_start_date_key` | INTEGER FK | `DELIVERABLE.PLANNED_START_DATE` |
| `due_date_key` | INTEGER FK | `DELIVERABLE.DUE_DATE` |
| `actual_start_date_key` | INTEGER FK | `DELIVERABLE.ACTUAL_START_DATE` |
| `submission_date_key` | INTEGER FK | `DELIVERABLE.SUBMISSION_DATE` (nullable) |
| `invoiced_date_key` | INTEGER FK | `DELIVERABLE.INVOICED_DATE` (nullable) |
| `planned_hours` | DECIMAL | `DELIVERABLE.PLANNED_HOURS` |
| `price` | DECIMAL(15,2) | `DELIVERABLE.PRICE` (nullable, 仅 FP) |
| `status` | VARCHAR | `DELIVERABLE.STATUS` |
| `progress_pct` | DECIMAL(5,2) | `DELIVERABLE.PROGRESS` |

---

### 8. DimExpenseCategory（Financial 私有 · Type 1）

**Source**: `SELECT DISTINCT CATEGORY FROM PROJECTEXPENSE`

| Column | Type | Source |
|--------|------|--------|
| `category_key` | INTEGER PK | surrogate |
| `category_name` | VARCHAR | distinct of `PROJECTEXPENSE.CATEGORY` |

> 实际取值 10 个（按行数排序）：Travel(13), Subcontractor Fees(12), Training(11), Software Licenses(7), Telecommunication(6), Client Entertainment(5), Legal and Professional Fees(5), Office Supplies(5), Equipment(4), Miscellaneous(4)

---

## 最终事实表清单

### Fact 1: FactProjectFinancialSnapshot（Periodic Snapshot）

**Grain**: 一行一个 project × month
**Type**: Periodic Snapshot
**Estimated rows**: 24 projects × 12-24 months ≈ 300-600 行

| Column | Type | Notes |
|--------|------|-------|
| `month_key` | INTEGER FK → DimDate | 当月最后一天的 date_key |
| `project_key` | INTEGER FK → DimProject | |
| `client_key` | INTEGER FK → DimClient | denormalized for query convenience |
| `business_unit_key` | INTEGER FK → DimBusinessUnit | denormalized |
| **Measures** | | |
| `contract_value` | DECIMAL(15,2) | semi-additive (do not sum across time) |
| `revenue_recognized` | DECIMAL(15,2) | 当月新增收入 — additive |
| `cumulative_revenue` | DECIMAL(15,2) | semi-additive |
| `labor_cost` | DECIMAL(15,2) | 当月人工成本 — additive |
| `expense_cost` | DECIMAL(15,2) | 当月非人工费用 — additive |
| `total_cost` | DECIMAL(15,2) | labor + expense — additive |
| `cumulative_cost` | DECIMAL(15,2) | semi-additive |
| `forecast_remaining_cost` | DECIMAL(15,2) | non-additive |
| `expected_total_cost` | DECIMAL(15,2) | non-additive |
| `expected_profit` | DECIMAL(15,2) | non-additive |
| `profit_margin_pct` | DECIMAL(7,4) | non-additive |
| `progress_pct` | DECIMAL(5,2) | snapshot of project progress |

**Revenue 计算逻辑（关键 transformation）**:
- **FP**: 月内 `DELIVERABLE.INVOICED_DATE` 落在该月的 deliverable 的 `PRICE` 之和
  - 简化处理：发票日期 = 收入确认日期
  - 备选方案：按 `PROGRESS` 月度变化 × `DELIVERABLE.PRICE` 分摊（更精细但复杂）
- **T&M**: 月内 `CONSULTANTDELIVERABLE.HOURS × PROJECTBILLINGRATE.RATE` 求和 + 月内 `is_billable=1` 的 `PROJECTEXPENSE.AMOUNT`

**Cost 计算逻辑**:
- `labor_cost` = SUM(`CONSULTANTDELIVERABLE.HOURS` × `consultant_cost_rate`) where `MONTH(DATE) = m`
  - `consultant_cost_rate` = effective `CONSULTANTTITLEHISTORY.SALARY` / 2080（年标工时）
- `expense_cost` = SUM(`PROJECTEXPENSE.AMOUNT`) where `MONTH(DATE) = m`
- `forecast_remaining_cost` = (`PROJECT.PLANNED_HOURS` − `cumulative_hours_to_date`) × `current_avg_cost_rate`

---

### Fact 2: FactLaborCost（Transaction）

**Grain**: 一行一个 consultant × deliverable × month
**Type**: Transaction (聚合后)
**Estimated rows**: source `CONSULTANTDELIVERABLE` 6507 行 → group by month 后 ≈ 3000 行

| Column | Type | Notes |
|--------|------|-------|
| `month_key` | INTEGER FK → DimDate | |
| `consultant_key` | INTEGER FK → DimConsultant (SCD2 effective version) | |
| `deliverable_key` | INTEGER FK → DimDeliverable | |
| `project_key` | INTEGER FK → DimProject (denormalized via deliverable) | |
| `title_key` | INTEGER FK → DimConsultantTitle (SCD2 当时的 title) | |
| **Measures** | | |
| `hours_worked` | DECIMAL(8,2) | additive |
| `internal_cost_rate` | DECIMAL(8,2) | non-additive (rate at time) |
| `labor_cost_amount` | DECIMAL(12,2) | hours × cost_rate — additive |
| `billing_rate` | DECIMAL(8,2) | non-additive (T&M only) |
| `billing_amount` | DECIMAL(12,2) | hours × billing_rate — additive (T&M only, NULL for FP) |

**Source aggregation**:
```sql
SELECT 
  CONSULTANTID, DELIVERABLEID,
  EOMONTH(TRY_TO_DATE(DATE)) AS month_end,
  SUM(HOURS) AS hours_worked
FROM CONSULTANTDELIVERABLE
GROUP BY 1, 2, 3
```

---

### Fact 3: FactProjectExpense（Transaction）

**Grain**: 一行一笔 expense
**Type**: Transaction (基本 1:1 with source)
**Estimated rows**: 72（同 PROJECTEXPENSE 行数）

| Column | Type | Source |
|--------|------|--------|
| `expense_key` | INTEGER PK (surrogate) | `dbt_utils.generate_surrogate_key([RECORDID])` |
| `expense_id` | VARCHAR NK | `PROJECTEXPENSE.RECORDID` |
| `date_key` | INTEGER FK → DimDate | `PROJECTEXPENSE.DATE` |
| `project_key` | INTEGER FK → DimProject | derived from `PROJECTID` |
| `deliverable_key` | INTEGER FK → DimDeliverable | derived from `DELIVERABLEID` |
| `category_key` | INTEGER FK → DimExpenseCategory | derived from `CATEGORY` |
| **Measures** | | |
| `expense_amount` | DECIMAL(12,2) | `PROJECTEXPENSE.AMOUNT` |
| `is_billable` | BOOLEAN | `PROJECTEXPENSE.IS_BILLABLE = 1` |
| **Degenerate** | | |
| `description` | TEXT | `PROJECTEXPENSE.DESCRIPTION` |

---

## Star Schema 关系图（cardinality 设计依据）

每条 dim → fact 边都是 IE crow's foot 风格，按 CLAUDE.md 的 4 种 cardinality 单独判断：

### FactProjectFinancialSnapshot

| Dim → Fact | Dim 端 | Fact 端 | 理由 |
|-----------|--------|---------|------|
| DimDate (month_key) | `||` mandatory exactly one | `○<` zero or many | 每行 snapshot 必有月份；DimDate 预填 11 年很多月份没数据 |
| DimProject | `||` | `|<` one or many | 每个 project 必有；project 一旦启动至少有 1 个月 snapshot |
| DimClient | `||` | `|<` | 每 project 必有 client；client 多 project |
| DimBusinessUnit | `||` | `|<` | 每 project 必属一 BU |

### FactLaborCost

| Dim → Fact | Dim 端 | Fact 端 | 理由 |
|-----------|--------|---------|------|
| DimDate | `||` | `○<` | 同上 |
| DimConsultant | `||` | `○<` | 部分 consultant 可能尚未参与 deliverable |
| DimDeliverable | `||` | `○<` | 113 deliverable 中部分尚未启动 (Not Started 60 个) |
| DimProject | `||` | `|<` | 每 deliverable 必属 project |
| DimConsultantTitle | `||` | `|<` | 每条 labor 行必有 title |

### FactProjectExpense

| Dim → Fact | Dim 端 | Fact 端 | 理由 |
|-----------|--------|---------|------|
| DimDate | `||` | `○<` | 同上 |
| DimProject | `||` | `|<` | 每 expense 必属 project |
| DimDeliverable | `○|` zero or one | `○<` | source `DELIVERABLEID` is_nullable=YES，可能存在项目级 expense（实际数据待 dbt 时验证） |
| DimExpenseCategory | `||` | `|<` | 每 expense 必有 category |

---

## 与 D2 设计的对齐说明（PPT 用）

> 用于 D3 PPT 的 design v2 介绍页

1. **保留**：D2 的 fact constellation 设计（3 张 fact 共享 conformed dim）
2. **保留**：核心 measure 列表和业务问题（10 个 question 不变）
3. **修订字段**：3 处删除 + 4 处新增 + 取值标准化（详见上面的"修订总览"表）
4. **新增**：每条边的 cardinality 单独判断（IE crow's foot 4 种），不再"全 mandatory one + many"

---

## 下一步

- Phase 2 第二个交付物：用 draw.io 画 v2 star schema（`Financial_DataMart_v2.drawio`）
- Phase 3：基于本文档生成 `Financial_S2T_Mapping.xlsx`
- Phase 5：dbt 实现按本文档字段为最终目标
