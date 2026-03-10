-- ============================================================
-- PROJECT: Customer Segmentation Analysis
-- Author:  Marie Odile Fotso
-- Tools:   SQL (MySQL)
-- Date:    Jan 2023 – May 2023
-- Description: Segments retail customers based on purchasing
--              behavior and demographics using RFM analysis.
-- ============================================================


-- ============================================================
-- STEP 1: Database & Table Setup
-- ============================================================

CREATE DATABASE IF NOT EXISTS customer_analytics;
USE customer_analytics;

CREATE TABLE customers (
    customer_id   INT PRIMARY KEY AUTO_INCREMENT,
    first_name    VARCHAR(50),
    last_name     VARCHAR(50),
    email         VARCHAR(100),
    gender        ENUM('M','F','Other'),
    age           INT,
    city          VARCHAR(100),
    state         VARCHAR(50),
    join_date     DATE
);

CREATE TABLE orders (
    order_id      INT PRIMARY KEY AUTO_INCREMENT,
    customer_id   INT,
    order_date    DATE,
    total_amount  DECIMAL(10,2),
    category      VARCHAR(50),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);


-- ============================================================
-- STEP 2: RFM Metrics — Recency, Frequency, Monetary
-- ============================================================

-- Calculate raw RFM values per customer
CREATE OR REPLACE VIEW rfm_raw AS
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name)              AS customer_name,
    c.city,
    c.state,
    c.age,
    c.gender,
    DATEDIFF(CURDATE(), MAX(o.order_date))               AS recency_days,
    COUNT(o.order_id)                                    AS frequency,
    ROUND(SUM(o.total_amount), 2)                        AS monetary_value,
    ROUND(AVG(o.total_amount), 2)                        AS avg_order_value
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id, customer_name, c.city, c.state, c.age, c.gender;


-- ============================================================
-- STEP 3: RFM Scoring (1–5 scale)
-- ============================================================

CREATE OR REPLACE VIEW rfm_scores AS
SELECT *,
    -- Recency: lower days = better score
    CASE
        WHEN recency_days <= 30  THEN 5
        WHEN recency_days <= 60  THEN 4
        WHEN recency_days <= 120 THEN 3
        WHEN recency_days <= 180 THEN 2
        ELSE 1
    END AS recency_score,

    -- Frequency: more orders = higher score
    CASE
        WHEN frequency >= 20 THEN 5
        WHEN frequency >= 12 THEN 4
        WHEN frequency >= 6  THEN 3
        WHEN frequency >= 2  THEN 2
        ELSE 1
    END AS frequency_score,

    -- Monetary: higher spend = higher score
    CASE
        WHEN monetary_value >= 5000 THEN 5
        WHEN monetary_value >= 2000 THEN 4
        WHEN monetary_value >= 800  THEN 3
        WHEN monetary_value >= 200  THEN 2
        ELSE 1
    END AS monetary_score
FROM rfm_raw;


-- ============================================================
-- STEP 4: Customer Segmentation
-- ============================================================

CREATE OR REPLACE VIEW customer_segments AS
SELECT *,
    (recency_score + frequency_score + monetary_score) AS rfm_total,
    CASE
        WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4
            THEN 'Champions'
        WHEN recency_score >= 3 AND frequency_score >= 3 AND monetary_score >= 3
            THEN 'Loyal Customers'
        WHEN recency_score >= 4 AND frequency_score <= 2
            THEN 'Recent Customers'
        WHEN recency_score <= 2 AND frequency_score >= 4
            THEN 'At Risk'
        WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score >= 3
            THEN 'Cannot Lose Them'
        WHEN recency_score >= 3 AND frequency_score >= 2
            THEN 'Potential Loyalists'
        WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score <= 2
            THEN 'Lost'
        ELSE 'Others'
    END AS segment
FROM rfm_scores;


-- ============================================================
-- STEP 5: Segment Summary Report
-- ============================================================

SELECT
    segment,
    COUNT(*)                                    AS customer_count,
    ROUND(AVG(monetary_value), 2)               AS avg_spend,
    ROUND(AVG(frequency), 1)                    AS avg_orders,
    ROUND(AVG(recency_days), 0)                 AS avg_days_since_purchase,
    ROUND(SUM(monetary_value), 2)               AS total_revenue
FROM customer_segments
GROUP BY segment
ORDER BY total_revenue DESC;


-- ============================================================
-- STEP 6: Demographics Breakdown per Segment
-- ============================================================

-- Age group distribution
SELECT
    segment,
    CASE
        WHEN age < 25  THEN '18–24'
        WHEN age < 35  THEN '25–34'
        WHEN age < 45  THEN '35–44'
        WHEN age < 55  THEN '45–54'
        ELSE '55+'
    END                   AS age_group,
    COUNT(*)              AS count
FROM customer_segments
GROUP BY segment, age_group
ORDER BY segment, age_group;

-- Gender distribution
SELECT
    segment,
    gender,
    COUNT(*)                                       AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER
        (PARTITION BY segment), 1)                 AS pct
FROM customer_segments
GROUP BY segment, gender
ORDER BY segment;

-- Top cities per segment
SELECT
    segment,
    city,
    state,
    COUNT(*) AS customer_count
FROM customer_segments
GROUP BY segment, city, state
ORDER BY segment, customer_count DESC;


-- ============================================================
-- STEP 7: Top Customers per Segment
-- ============================================================

SELECT
    segment,
    customer_name,
    city,
    frequency           AS total_orders,
    monetary_value      AS total_spent,
    recency_days        AS days_since_last_order
FROM customer_segments
WHERE segment = 'Champions'
ORDER BY monetary_value DESC
LIMIT 20;


-- ============================================================
-- STEP 8: Category Preferences by Segment
-- ============================================================

SELECT
    cs.segment,
    o.category,
    COUNT(o.order_id)           AS order_count,
    ROUND(SUM(o.total_amount),2) AS revenue
FROM customer_segments cs
JOIN orders o ON cs.customer_id = o.customer_id
GROUP BY cs.segment, o.category
ORDER BY cs.segment, revenue DESC;
