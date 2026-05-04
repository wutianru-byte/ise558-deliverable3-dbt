# Source DB Notes — `CONSULTING_DB_INITIAL.CONSULTING`

> **生成时间**: 2026-05-03
> **来源查询**: INFORMATION_SCHEMA.COLUMNS + TABLES
> **表数**: 17（全部小写 schema 名 = `CONSULTING`）
> **目的**: 对照 D2 Financial 设计，把每个字段的实际名字 / 类型 / 数据量记下来，作为 Phase 2（设计修订）和 Phase 3（S2T mapping）的真相之源。

---

## 全表清单（按 D3 相关性分类）

### 高相关 — Financial 三个 fact 直接消费

| Table | Rows | 在 Financial 用作 |
|-------|------|-------------------|
| `PROJECT` | 24 | DimProject + FactProjectFinancialSnapshot 主键源 |
| `DELIVERABLE` | 113 | DimDeliverable + FP revenue recognition trigger |
| `CONSULTANT` | 108 | DimConsultant 基础信息 |
| `CONSULTANTTITLEHISTORY` | 112 | DimConsultant SCD2 + 推算 internal cost rate |
| `CONSULTANTDELIVERABLE` | **6507** | FactLaborCost 主源；FactProjectFinancialSnapshot.labor_cost |
| `PAYROLL` | 638 | 验证 cost rate（PAYROLL.AMOUNT vs salary 推算） |
| `PROJECTEXPENSE` | 72 | FactProjectExpense（几乎 1:1） + DimExpenseCategory |
| `PROJECTBILLINGRATE` | 42 | T&M 项目的 billing_rate（按 project × title） |

### 中相关 — Conformed dim / 辅助

| Table | Rows | 用途 |
|-------|------|------|
| `BUSINESSUNIT` | 4 | DimBusinessUnit（极薄，只有 id + name） |
| `CLIENT` | 355 | DimClient（join LOCATION 拿地理） |
| `LOCATION` | 40 | DimClient 的地理来源 |
| `TITLE` | 6 | DimConsultantTitle |
| `INDIRECT_COSTS` | 11 | BU 级别的 overhead，可选放进 Financial（深化 BU 利润分析） |

### 低相关 — 主要给 HR / Project Delivery 用

| Table | Rows | 备注 |
|-------|------|------|
| `NON_BILLABLE_HOURS` | 658 | HR 关心，Financial 可用于 cost rate 分母 |
| `PROJECTTEAM` | 173 | 项目团队成员，Project Delivery 用 |
| `CLIENT_FEEDBACK` | 18 | 客户满意度，与 Financial 无关 |
| `FEEDBACK_RESPONSES` | 72 | 满意度问卷，与 Financial 无关 |

---

## D2 设计 vs Source — 字段差异表

### DimBusinessUnit ⚠️ 大改

| D2 字段 | Source 字段 | Action |
|---------|-------------|--------|
| `bu_name` | `BUSINESS_UNIT_NAME` | 直接 rename |
| `geographic_region` | **不存在** | **删掉**，或注释为"由 BU 名字推断（North America / EMEA 等）"——但 source 里看不到名字内容，要 sample 才知道 |
| - | `BUSINESSUNITID` | 加 natural key + surrogate key |

**结论**：DimBusinessUnit 极简，只有 id + name 两列。`geographic_region` 不能保留。

### DimClient ⚠️ 中改

| D2 字段 | Source 字段 | Action |
|---------|-------------|--------|
| `client_name` | `CLIENT.CLIENT_NAME` | OK |
| `industry` | **不存在** | **删掉** |
| `client_region` | `LOCATION.STATE` (via CLIENT.LOCATIONID) | 改名 `state`；可加 `city` |
| - | `CLIENT.PHONE_NUMBER`, `CLIENT.EMAIL` | 可选增加 |

### DimProject ✅ 小改

| D2 字段 | Source 字段 | Action |
|---------|-------------|--------|
| `project_name` | `PROJECT.NAME` | OK |
| `project_type` | `PROJECT.TYPE` | 取值待 Phase 1.2 sample 确认 |
| `project_status` | `PROJECT.STATUS` | 取值待 sample 确认 |
| `client_key` | derived from `PROJECT.CLIENTID` | OK |
| `business_unit_key` | derived from `PROJECT.UNITID` | 注意 source 是 `UNITID` 不是 `BUSINESSUNITID` |
| `planned_start_date_key` | `PROJECT.PLANNED_START_DATE` | OK |
| `planned_end_date_key` | `PROJECT.PLANNED_END_DATE` | OK |
| `contract_value` | `PROJECT.PRICE` | 改名；T&M 是否 NULL 待 sample 确认 |
| - | `PROJECT.ESTIMATED_BUDGET` | **新增**：planned cost，用于 forecast 计算 |
| - | `PROJECT.PROGRESS` | **新增**：% complete |
| - | `PROJECT.ACTUAL_START_DATE`, `ACTUAL_END_DATE` | **新增** |

**关键发现**：PROJECT 有两个金额字段——`PRICE`（contract value, 收入侧）和 `ESTIMATED_BUDGET`（计划成本侧），分得很清楚。

### DimConsultant ✅ 字段对得上，但 SCD2 来源是另一张表

- `CONSULTANT` 表只有 basic info（name, email, hire_year, BU）— **没有 title / salary**
- `CONSULTANTTITLEHISTORY` 是 SCD2 来源（每次升职/加薪一行）
  - 字段：CONSULTANTID, TITLEID, START_DATE, EVENT_TYPE, SALARY
  - **没有 END_DATE 列** → 必须用 `LEAD(START_DATE) OVER (PARTITION BY consultantid ORDER BY start_date)` 推导
  - **没有 is_current 列** → 用 `MAX(START_DATE) PER CONSULTANT` 推导

### DimConsultantTitle ✅ 直接 1:1

- `TITLE` 表：TITLEID + TITLE_NAME，6 行
- D2 写了 `title_level (seniority rank)` — source 没有，可在 dbt 里 hardcode 一个 mapping（Consultant=1, Senior=2, Manager=3, ...）

### DimDeliverable ✅ 字段更丰富

| D2 字段 | Source 字段 | Action |
|---------|-------------|--------|
| `deliverable_name` | `DELIVERABLE.NAME` | OK |
| `planned_start` | `DELIVERABLE.PLANNED_START_DATE` | OK |
| `planned_end` | `DELIVERABLE.DUE_DATE` | 注意 source 字段名不是 PLANNED_END_DATE |
| `status` | `DELIVERABLE.STATUS` | OK |
| `pct_complete` | `DELIVERABLE.PROGRESS` | OK |
| - | `DELIVERABLE.PRICE` | **新增**：FP 项目按 deliverable 定价 |
| - | `DELIVERABLE.SUBMISSION_DATE`, `INVOICED_DATE` | **新增**：FP 收入确认时点 |
| - | `DELIVERABLE.PLANNED_HOURS` | **新增** |

**关键发现**：DELIVERABLE.PRICE 存在 → FP 项目按 deliverable 单独计价 → revenue 分摊到 deliverable 级别（不是项目级别），更精细。

### DimExpenseCategory ✅ 不变

- 来源：`SELECT DISTINCT CATEGORY FROM PROJECTEXPENSE`
- 待 sample 看实际取值（Travel / Software / Subcontractor / ...）

### DimDate ⚠️ 不在 source

- Source 里**没有 date 表**
- dbt 里用 `dbt_utils.date_spine` 生成（如 2020-01-01 到 2030-12-31）

---

## Fact 实现关键点

### FactProjectFinancialSnapshot

- **Grain**: project × month
- **Revenue 计算**:
  - FP: 当 `DELIVERABLE.INVOICED_DATE` 落在该月 → revenue += DELIVERABLE.PRICE
    - 或更细：按 PROGRESS 增量 × DELIVERABLE.PRICE 分摊（待评审业务规则）
  - T&M: 当月 `CONSULTANTDELIVERABLE.HOURS × PROJECTBILLINGRATE.RATE` 求和 + 当月 billable PROJECTEXPENSE
- **labor_cost**:
  - 月度：SUM(CONSULTANTDELIVERABLE.HOURS × cost_rate) where MONTH(DATE) = m
  - cost_rate 推导：当时 effective 的 SALARY / 2080（年标工时）
  - 或：当月 PAYROLL.AMOUNT / 当月该 consultant 总工时
- **expense_cost**: SUM(PROJECTEXPENSE.AMOUNT) where MONTH(DATE) = m
- **forecast_remaining_cost**: (PROJECT.PLANNED_HOURS − cumulative_hours) × current_cost_rate
- **expected_total_cost**: cumulative_cost + forecast_remaining_cost
- **expected_profit**:
  - FP: PROJECT.PRICE − expected_total_cost
  - T&M: cumulative_revenue − expected_total_cost（等于实时 margin）

### FactLaborCost

- **Grain**: consultant × deliverable × month
- **Source**: CONSULTANTDELIVERABLE（6507 行 → group by month 后估计 ~3000 行）
- **Aggregation**: GROUP BY consultantid, deliverableid, year_month(date)
- **Measures**:
  - hours_worked: SUM(HOURS)
  - internal_cost_rate: 接 CONSULTANTTITLEHISTORY 当时 effective 的 SALARY / 2080
  - labor_cost_amount: hours × rate
  - billing_rate: 接 PROJECTBILLINGRATE.RATE（项目 + 当时 title）；只 T&M 项目有
  - billing_amount: hours × billing_rate

### FactProjectExpense

- **Grain**: 一行 = 一笔 expense 记录
- **Source**: PROJECTEXPENSE 几乎 1:1（72 行）
- 只需替换 FK 为 surrogate key

---

## 数据质量要点（Phase 1.2 sample 时验证）

1. **所有日期都是 TEXT 类型** → dbt staging 层全部用 `TRY_TO_DATE()` 转换
2. **YEARMONTH 类型不一致**：INDIRECT_COSTS 是 TEXT，NON_BILLABLE_HOURS 是 NUMBER → 统一转 INTEGER YYYYMM
3. **CONSULTANTID 是 TEXT**（不是 NUMBER），可能是字符串编号；BUSINESSUNITID 是 NUMBER → 不一致是 source 设计问题，照搬即可
4. **PROGRESS 字段单位待确认**：0-1 还是 0-100？(PROJECT.PROGRESS, DELIVERABLE.PROGRESS) — Phase 1.2 sample 验证
5. **PROJECT.TYPE 取值**：是 "Fixed-Price"/"Time and Materials" 还是缩写？— Phase 1.2 验证
6. **PROJECT.STATUS, DELIVERABLE.STATUS 取值** — Phase 1.2 验证
7. **PROJECTEXPENSE.IS_BILLABLE** = NUMBER → 应该是 0/1 → 确认
8. **CONSULTANTTITLEHISTORY.EVENT_TYPE 取值**（"hire"/"promotion"/"raise"?）— Phase 1.2 验证
9. **PROJECT.PRICE 在 T&M 项目里是否 NULL** — Phase 1.2 验证（决定 contract_value 是否 NULL）

---

## Phase 1.2 — 关键取值确认（已完成部分）

### PROJECT 表（2026-05-03 验证）

- **TYPE 取值**：`"Fixed"`（17 行）/ `"Time and Material"`（7 行）
  - ⚠️ 不是 D2 写的 "Fixed-Price" / "T&M"，dbt 里要按 source 实际值判断
- **STATUS 取值**：`"Not Started"`（3）/ `"In Progress"`（18）/ `"Completed"`（3）
- **PROGRESS**：0-100 百分比（不是 0-1）
- **PRICE 行为**：
  - Fixed 项目：100% 有值，范围 $183,855 ~ $2,111,927
  - T&M 项目：100% 为 NULL → 验证 D2 `contract_value` 在 T&M 应为 NULL

### TITLE 表（2026-05-03 验证）

```
T1 Junior Consultant   (level 1)
T2 Consultant          (level 2)
T3 Senior Consultant   (level 3)
T4 Lead Consultant     (level 4)
T5 Project Manager     (level 5)
T6 Vice President      (level 6)
```

DimConsultantTitle.title_level 可在 dbt 里用 CASE WHEN 直接 hardcode 1-6。

### BUSINESSUNIT 表（2026-05-03 验证）⚡

```
ID=1 North America
ID=2 Central and South America
ID=3 EMEA
ID=4 Asia Pacific
```

**重要**：BU name **本身就是 geographic region**——D2 设计的 `geographic_region` 是冗余字段，可以删掉，直接用 `bu_name`。

### DELIVERABLE 表（2026-05-03 验证）

- **PRICE**：113 行中 86 行有值，27 行 NULL（推测 NULL = T&M 项目的 deliverable）
- **INVOICED_DATE**：113 行中只 17 行有值——baseline 里 FP 收入事件稀少
- **PROGRESS**：0-100 同 PROJECT.PROGRESS（一致 ✓）
- **STATUS**：`Not Started` 60 / `In Progress` 27 / `Completed` 26（取值同 PROJECT.STATUS ✓）

### CONSULTANTTITLEHISTORY 表（2026-05-03 验证）⚠️

EVENT_TYPE 只有两种：
- `Hire` = 108 行（每个 consultant 一条 hire）
- `Layoff` = 4 行
- **❌ 无 Promotion / Raise 事件**

**含义**：
- baseline (`CONSULTING` schema) 里 SCD2 没用（无历史变化）
- 但 D3 任务的 `CONSULTING_UPDATED` schema 可能加入 Promotion 事件——这正是 incremental ELT 的演示场景
- **设计上保留 SCD2**，dbt snapshot 跑一次，等切换到 UPDATE schema 时自动捕获新事件

### PROJECTEXPENSE 表（2026-05-03 验证）

- **IS_BILLABLE**: 0=23 非可计费, 1=49 可计费（二元，68% 计费）
- **CATEGORY** 10 类（DimExpenseCategory 的内容）:
  | Category | Count |
  |----------|-------|
  | Travel | 13 |
  | Subcontractor Fees | 12 |
  | Training | 11 |
  | Software Licenses | 7 |
  | Telecommunication | 6 |
  | Client Entertainment | 5 |
  | Legal and Professional Fees | 5 |
  | Office Supplies | 5 |
  | Equipment | 4 |
  | Miscellaneous | 4 |

---

## Phase 1 完成总结

✅ 拉清了 17 张 source 表的全部 schema
✅ 确认了 D2 6 个待验证取值
✅ 发现 D2 设计要修订的字段：
   - `DimBusinessUnit.geographic_region` → 删除（BU name 即 region）
   - `DimClient.industry` → 删除（source 没有）
   - `PROJECT.TYPE` 取值 → "Fixed" / "Time and Material"（不是 D2 写的）
   - `PROGRESS` → 0-100（不是 0-1）
✅ 发现 D2 没用上但有用的 source 字段：
   - `PROJECT.ESTIMATED_BUDGET`（计划成本）
   - `DELIVERABLE.PRICE` + `INVOICED_DATE`（FP 按 deliverable 收入确认）
✅ 发现 SCD2 在 baseline 里"用不上"，但要为 incremental 演示保留
✅ 拿到 6 个 title 层级、4 个 BU、10 个 expense category 的硬编码值

## 下一步：Phase 2 — D2 设计修订

产出：
- `Financial_DataMart_Design_v2.md`（最终字段清单 + 与 D2 的差异）
- `Financial_DataMart_v2.drawio`（修订版 star schema）
