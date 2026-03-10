-- ============================================================
-- PROJECT: IT Support Analytics Dashboard
-- Author:  Marie Odile Fotso
-- Tools:   SQL (MySQL), Tableau / Power BI
-- Context: CyberMunk IT Support · May 2024 – Present
-- Description: Analyzes helpdesk ticket data to identify
--   trends, optimize response times, and support reporting.
--   Contributed to a 20% reduction in ticket resolution time.
-- ============================================================


-- ============================================================
-- STEP 1: Schema Setup
-- ============================================================

CREATE DATABASE IF NOT EXISTS it_support;
USE it_support;

CREATE TABLE tickets (
    ticket_id       INT PRIMARY KEY AUTO_INCREMENT,
    created_at      DATETIME,
    resolved_at     DATETIME,
    category        VARCHAR(100),   -- e.g. Network, Software, Hardware
    priority        ENUM('Low','Medium','High','Critical'),
    status          ENUM('Open','In Progress','Resolved','Closed'),
    assigned_agent  VARCHAR(100),
    student_id      INT,
    description     TEXT,
    resolution_note TEXT
);

CREATE TABLE agents (
    agent_id    INT PRIMARY KEY AUTO_INCREMENT,
    agent_name  VARCHAR(100),
    team        VARCHAR(50),
    hire_date   DATE
);


-- ============================================================
-- STEP 2: Core Metrics View
-- ============================================================

CREATE OR REPLACE VIEW ticket_metrics AS
SELECT
    ticket_id,
    created_at,
    resolved_at,
    category,
    priority,
    status,
    assigned_agent,
    -- Resolution time in minutes
    TIMESTAMPDIFF(MINUTE, created_at, resolved_at)       AS resolution_minutes,
    -- Resolution time in hours
    ROUND(TIMESTAMPDIFF(MINUTE, created_at, resolved_at)
          / 60.0, 2)                                     AS resolution_hours,
    -- SLA flag: Critical ≤4h, High ≤8h, Medium ≤24h, Low ≤72h
    CASE
        WHEN priority = 'Critical' AND
             TIMESTAMPDIFF(HOUR, created_at, resolved_at) <= 4  THEN 'Met'
        WHEN priority = 'High'     AND
             TIMESTAMPDIFF(HOUR, created_at, resolved_at) <= 8  THEN 'Met'
        WHEN priority = 'Medium'   AND
             TIMESTAMPDIFF(HOUR, created_at, resolved_at) <= 24 THEN 'Met'
        WHEN priority = 'Low'      AND
             TIMESTAMPDIFF(HOUR, created_at, resolved_at) <= 72 THEN 'Met'
        WHEN resolved_at IS NULL THEN 'Pending'
        ELSE 'Breached'
    END AS sla_status,
    -- Day of week
    DAYNAME(created_at)                                  AS day_of_week,
    -- Hour of day (for peak time analysis)
    HOUR(created_at)                                     AS hour_of_day,
    -- Month
    DATE_FORMAT(created_at, '%Y-%m')                     AS month
FROM tickets;


-- ============================================================
-- STEP 3: Resolution Time Analysis
-- ============================================================

-- Average resolution time by category
SELECT
    category,
    COUNT(*)                                       AS total_tickets,
    ROUND(AVG(resolution_minutes), 0)              AS avg_resolution_min,
    ROUND(MIN(resolution_minutes), 0)              AS min_resolution_min,
    ROUND(MAX(resolution_minutes), 0)              AS max_resolution_min,
    ROUND(AVG(resolution_hours), 2)                AS avg_resolution_hrs
FROM ticket_metrics
WHERE resolved_at IS NOT NULL
GROUP BY category
ORDER BY avg_resolution_min;

-- Average resolution time by priority
SELECT
    priority,
    COUNT(*)                                       AS tickets,
    ROUND(AVG(resolution_hours), 2)                AS avg_hrs,
    SUM(CASE WHEN sla_status = 'Met'      THEN 1 ELSE 0 END) AS sla_met,
    SUM(CASE WHEN sla_status = 'Breached' THEN 1 ELSE 0 END) AS sla_breached,
    ROUND(SUM(CASE WHEN sla_status = 'Met' THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 1)                   AS sla_compliance_pct
FROM ticket_metrics
WHERE resolved_at IS NOT NULL
GROUP BY priority
ORDER BY FIELD(priority, 'Critical','High','Medium','Low');


-- ============================================================
-- STEP 4: Monthly Trend (tracks the 20% improvement)
-- ============================================================

SELECT
    month,
    COUNT(*)                                        AS total_tickets,
    SUM(CASE WHEN status = 'Resolved' THEN 1 ELSE 0 END) AS resolved,
    ROUND(AVG(resolution_hours), 2)                 AS avg_resolution_hrs,
    ROUND(SUM(CASE WHEN sla_status = 'Met' THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 1)                    AS sla_pct,
    -- Month-over-month change in avg resolution time
    ROUND(AVG(resolution_hours)
        - LAG(AVG(resolution_hours)) OVER (ORDER BY month), 2) AS mom_change_hrs
FROM ticket_metrics
GROUP BY month
ORDER BY month;


-- ============================================================
-- STEP 5: Peak Volume Analysis
-- ============================================================

-- Tickets by hour of day (identify rush hours)
SELECT
    hour_of_day,
    COUNT(*)                                        AS ticket_count,
    ROUND(AVG(resolution_hours), 2)                 AS avg_resolution_hrs
FROM ticket_metrics
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- Tickets by day of week
SELECT
    day_of_week,
    COUNT(*)                                        AS ticket_count,
    ROUND(AVG(resolution_hours), 2)                 AS avg_resolution_hrs
FROM ticket_metrics
GROUP BY day_of_week
ORDER BY FIELD(day_of_week,
    'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday');


-- ============================================================
-- STEP 6: Agent Performance
-- ============================================================

SELECT
    assigned_agent,
    COUNT(*)                                        AS tickets_handled,
    ROUND(AVG(resolution_hours), 2)                 AS avg_resolution_hrs,
    SUM(CASE WHEN sla_status = 'Met'      THEN 1 ELSE 0 END) AS sla_met,
    ROUND(SUM(CASE WHEN sla_status = 'Met' THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 1)                    AS sla_compliance_pct,
    SUM(CASE WHEN priority IN ('High','Critical') THEN 1 ELSE 0 END) AS critical_tickets
FROM ticket_metrics
WHERE resolved_at IS NOT NULL
GROUP BY assigned_agent
ORDER BY tickets_handled DESC;


-- ============================================================
-- STEP 7: Category Frequency (FAQ Guide Inputs)
-- ============================================================

SELECT
    category,
    COUNT(*)                                        AS occurrences,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM tickets), 1) AS pct_of_total,
    ROUND(AVG(resolution_hours), 2)                 AS avg_resolution_hrs
FROM ticket_metrics
GROUP BY category
ORDER BY occurrences DESC;


-- ============================================================
-- STEP 8: Open Tickets Summary (real-time dashboard feed)
-- ============================================================

SELECT
    priority,
    category,
    COUNT(*)                                        AS open_count,
    MAX(TIMESTAMPDIFF(HOUR, created_at, NOW()))     AS oldest_ticket_hrs
FROM tickets
WHERE status IN ('Open', 'In Progress')
GROUP BY priority, category
ORDER BY FIELD(priority, 'Critical','High','Medium','Low');


-- ============================================================
-- STEP 9: Stored Procedure — Recalculate KPIs for a Month
-- ============================================================

DELIMITER $$
CREATE PROCEDURE monthly_kpi_report(IN report_month VARCHAR(7))
BEGIN
    SELECT
        report_month                                       AS month,
        COUNT(*)                                           AS total_tickets,
        ROUND(AVG(resolution_hours), 2)                    AS avg_resolution_hrs,
        ROUND(SUM(CASE WHEN sla_status = 'Met' THEN 1 ELSE 0 END)
              * 100.0 / COUNT(*), 1)                       AS sla_compliance_pct,
        SUM(CASE WHEN status = 'Resolved' THEN 1 ELSE 0 END) AS resolved_count,
        SUM(CASE WHEN status IN ('Open','In Progress') THEN 1 ELSE 0 END) AS open_count
    FROM ticket_metrics
    WHERE month = report_month;
END$$
DELIMITER ;

-- Usage:
-- CALL monthly_kpi_report('2024-10');
