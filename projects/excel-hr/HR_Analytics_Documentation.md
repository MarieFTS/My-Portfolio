# HR Analytics & Reporting — Excel Project
**Author:** Marie Odile Fotso
**Tools:** Microsoft Excel, Tableau
**Context:** Jamela Hair Braiding Company · Oct 2022 – Jan 2023

---

## Overview
Designed and maintained an Excel-based HR analytics system to track headcount, PTO balances, and team engagement metrics. Data was cleaned, normalized, and visualized in both Excel and Tableau to support management decision-making.

---

## Workbook Structure

### Sheet 1 — Employee Master
| Column | Description |
|--------|-------------|
| Employee_ID | Unique identifier |
| First_Name / Last_Name | Employee name |
| Department | Braiding / Admin / Management |
| Role | Job title |
| Start_Date | Hire date |
| Status | Active / On Leave / Terminated |
| Full_Time | Yes / No |
| Hourly_Rate | Pay rate |

### Sheet 2 — Headcount Tracker
Monthly snapshot of active headcount per department.

**Key Formula — Active Headcount:**
```excel
=COUNTIFS(MasterData[Status],"Active",MasterData[Department],A2)
```

**Turnover Rate (monthly):**
```excel
=COUNTIFS(Exits[Exit_Month],B1)/AVERAGE(Headcount[Start],Headcount[End])
```

### Sheet 3 — PTO Log
Tracks PTO requests, approvals, and remaining balances per employee.

| Column | Description |
|--------|-------------|
| Employee_ID | FK to Employee Master |
| Request_Date | Date submitted |
| Start_Date | PTO start |
| End_Date | PTO end |
| Days_Requested | Calculated working days |
| Status | Approved / Pending / Denied |
| Balance_Before | Hours before request |
| Balance_After | Hours after approval |

**Working days formula (excluding weekends):**
```excel
=NETWORKDAYS(D2, E2) - 1
```

**Remaining PTO balance:**
```excel
=VLOOKUP(A2, PTOAllocation[#All], 3, FALSE) - SUMIF(PTOLog[Employee_ID], A2, PTOLog[Days_Used])
```

### Sheet 4 — Engagement Metrics
Monthly survey scores (1–5 scale) across 5 dimensions:
- Job Satisfaction
- Work-Life Balance
- Team Collaboration
- Management Support
- Growth Opportunities

**Department average:**
```excel
=AVERAGEIF(MasterData[Department], $A2, EngagementData[Score])
```

**Trend indicator (vs prior month):**
```excel
=IF(B2>B1, "▲", IF(B2<B1, "▼", "→"))
```

### Sheet 5 — Dashboard (Summary)
Auto-updating KPI dashboard using dynamic named ranges and charts.

**Key KPIs tracked:**
- Total headcount (this month vs last month)
- New hires / exits this month
- Turnover rate %
- Average PTO utilization %
- Average engagement score (all departments)
- Department engagement comparison (bar chart)

---

## Key Formulas Reference

```excel
-- Dynamic headcount count
=COUNTA(MasterData[Employee_ID])

-- % change month over month
=IFERROR((C2-B2)/B2, 0)

-- PTO utilization rate
=SUMIF(PTOLog[Status],"Approved",PTOLog[Days_Requested])
 / SUMIF(MasterData[Status],"Active",PTOAllocation[Annual_Days])

-- Engagement score color scale (Conditional Formatting)
-- Green if ≥ 4.0, Yellow if 3.0–3.9, Red if < 3.0

-- XLOOKUP for employee details
=XLOOKUP(A2, MasterData[Employee_ID], MasterData[Department], "Not Found")
```

---

## Tableau Dashboard (linked)
The cleaned Excel data was imported into Tableau to build an interactive dashboard with:
- Headcount trend line (12-month rolling)
- Department breakdown donut chart
- PTO heatmap by month and department
- Engagement score radar chart per department
- Turnover rate KPI card with sparkline

---

## Key Results
- Reduced manual reporting time by ~3 hours/week
- Identified highest PTO utilization in the braiding department (72%)
- Engagement score improved 0.4 points after management feedback session
- Turnover rate tracked from 18% → 11% over 3 months
