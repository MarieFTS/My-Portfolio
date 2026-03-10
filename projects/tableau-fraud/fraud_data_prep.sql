-- ============================================================
-- PROJECT: Fraud Detection Dashboard (Data Preparation)
-- Author:  Marie Odile Fotso
-- Tools:   SQL (data prep) → Tableau (visualization)
-- Date:    Sep 2023 – Nov 2023
-- Description: Cleans, transforms, and aggregates transaction
--   data for import into Tableau to build an interactive
--   real-time fraud detection dashboard.
-- ============================================================


-- ============================================================
-- STEP 1: Schema Setup
-- ============================================================

CREATE DATABASE IF NOT EXISTS fraud_detection;
USE fraud_detection;

CREATE TABLE transactions (
    transaction_id  BIGINT PRIMARY KEY,
    trans_datetime  DATETIME,
    cc_num          BIGINT,
    merchant        VARCHAR(200),
    category        VARCHAR(100),
    amt             DECIMAL(10,2),
    first_name      VARCHAR(50),
    last_name       VARCHAR(50),
    city            VARCHAR(100),
    state           CHAR(2),
    zip             VARCHAR(10),
    lat             DECIMAL(9,6),
    `long`          DECIMAL(9,6),
    city_pop        INT,
    job             VARCHAR(100),
    dob             DATE,
    trans_num       VARCHAR(50),
    unix_time       BIGINT,
    merch_lat       DECIMAL(9,6),
    merch_long      DECIMAL(9,6),
    is_fraud        TINYINT(1)   -- 0 = legitimate, 1 = fraud
);


-- ============================================================
-- STEP 2: Data Quality Checks
-- ============================================================

-- Missing values
SELECT
    SUM(transaction_id  IS NULL) AS null_transaction_id,
    SUM(amt             IS NULL) AS null_amt,
    SUM(trans_datetime  IS NULL) AS null_date,
    SUM(merchant        IS NULL) AS null_merchant,
    SUM(is_fraud        IS NULL) AS null_is_fraud
FROM transactions;

-- Duplicate transactions
SELECT trans_num, COUNT(*) AS cnt
FROM transactions
GROUP BY trans_num
HAVING cnt > 1;

-- Amount range sanity check
SELECT
    MIN(amt)  AS min_amount,
    MAX(amt)  AS max_amount,
    AVG(amt)  AS avg_amount,
    STDDEV(amt) AS std_amount
FROM transactions;


-- ============================================================
-- STEP 3: Feature Engineering
-- ============================================================

CREATE OR REPLACE VIEW transactions_enriched AS
SELECT
    transaction_id,
    trans_datetime,
    DATE(trans_datetime)                                    AS trans_date,
    TIME(trans_datetime)                                    AS trans_time,
    HOUR(trans_datetime)                                    AS hour_of_day,
    DAYNAME(trans_datetime)                                 AS day_of_week,
    DATE_FORMAT(trans_datetime, '%Y-%m')                    AS month,
    WEEKOFYEAR(trans_datetime)                              AS week_number,
    cc_num,
    merchant,
    category,
    amt,
    state,
    city_pop,
    is_fraud,

    -- Customer age at transaction time
    TIMESTAMPDIFF(YEAR, dob, DATE(trans_datetime))          AS customer_age,

    -- Distance between customer and merchant (Haversine approx in km)
    ROUND(6371 * 2 * ASIN(SQRT(
        POWER(SIN(RADIANS(merch_lat - lat) / 2), 2) +
        COS(RADIANS(lat)) * COS(RADIANS(merch_lat)) *
        POWER(SIN(RADIANS(merch_long - `long`) / 2), 2)
    )), 2)                                                  AS distance_km,

    -- Amount bucket
    CASE
        WHEN amt < 10   THEN 'Micro (<$10)'
        WHEN amt < 50   THEN 'Small ($10–50)'
        WHEN amt < 200  THEN 'Medium ($50–200)'
        WHEN amt < 500  THEN 'Large ($200–500)'
        ELSE                 'Very Large ($500+)'
    END                                                     AS amount_bucket,

    -- Time of day bucket
    CASE
        WHEN HOUR(trans_datetime) BETWEEN 6  AND 11 THEN 'Morning'
        WHEN HOUR(trans_datetime) BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN HOUR(trans_datetime) BETWEEN 18 AND 21 THEN 'Evening'
        ELSE 'Night'
    END                                                     AS time_of_day
FROM transactions;


-- ============================================================
-- STEP 4: Fraud Rate Analysis
-- ============================================================

-- Overall fraud rate
SELECT
    COUNT(*)                                                AS total_transactions,
    SUM(is_fraud)                                           AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 3)             AS fraud_rate_pct,
    ROUND(SUM(CASE WHEN is_fraud = 1 THEN amt ELSE 0 END), 2) AS total_fraud_amount
FROM transactions;

-- Fraud rate by category
SELECT
    category,
    COUNT(*)                                                AS total,
    SUM(is_fraud)                                           AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2)             AS fraud_rate_pct,
    ROUND(AVG(CASE WHEN is_fraud = 1 THEN amt END), 2)     AS avg_fraud_amount
FROM transactions_enriched
GROUP BY category
ORDER BY fraud_rate_pct DESC;

-- Fraud rate by hour of day
SELECT
    hour_of_day,
    COUNT(*)                                                AS total,
    SUM(is_fraud)                                          AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2)            AS fraud_rate_pct
FROM transactions_enriched
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- Fraud rate by amount bucket
SELECT
    amount_bucket,
    COUNT(*)                                                AS total,
    SUM(is_fraud)                                           AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2)             AS fraud_rate_pct,
    ROUND(AVG(CASE WHEN is_fraud = 1 THEN amt END), 2)     AS avg_fraud_amt
FROM transactions_enriched
GROUP BY amount_bucket
ORDER BY avg_fraud_amt DESC;

-- Fraud rate by state
SELECT
    state,
    COUNT(*)                                                AS total,
    SUM(is_fraud)                                           AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2)             AS fraud_rate_pct,
    ROUND(SUM(CASE WHEN is_fraud = 1 THEN amt ELSE 0 END), 2) AS fraud_amt
FROM transactions_enriched
GROUP BY state
ORDER BY fraud_rate_pct DESC;


-- ============================================================
-- STEP 5: Anomaly Detection — High-Risk Transactions
-- ============================================================

-- Transactions where amount is > 3 standard deviations above mean
SELECT
    transaction_id,
    trans_datetime,
    cc_num,
    merchant,
    category,
    amt,
    state,
    distance_km,
    is_fraud
FROM transactions_enriched
WHERE amt > (
    SELECT AVG(amt) + 3 * STDDEV(amt) FROM transactions
)
ORDER BY amt DESC;

-- Cards with unusual frequency (>10 transactions in one day)
SELECT
    cc_num,
    trans_date,
    COUNT(*)                                                AS daily_transactions,
    SUM(amt)                                                AS daily_spend,
    SUM(is_fraud)                                           AS fraud_flags
FROM transactions_enriched
GROUP BY cc_num, trans_date
HAVING daily_transactions > 10
ORDER BY daily_transactions DESC;

-- High distance transactions (customer far from merchant)
SELECT
    transaction_id,
    trans_datetime,
    merchant,
    category,
    amt,
    distance_km,
    is_fraud
FROM transactions_enriched
WHERE distance_km > 500
ORDER BY distance_km DESC
LIMIT 50;


-- ============================================================
-- STEP 6: Tableau Export Views
-- ============================================================

-- View 1: Daily summary (for time series chart)
CREATE OR REPLACE VIEW tableau_daily_summary AS
SELECT
    trans_date,
    COUNT(*)                                                AS total_transactions,
    SUM(is_fraud)                                           AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 3)             AS fraud_rate,
    ROUND(SUM(amt), 2)                                      AS total_amount,
    ROUND(SUM(CASE WHEN is_fraud=1 THEN amt ELSE 0 END), 2) AS fraud_amount
FROM transactions_enriched
GROUP BY trans_date
ORDER BY trans_date;

-- View 2: Geographic data (for map chart)
CREATE OR REPLACE VIEW tableau_geo_summary AS
SELECT
    state,
    COUNT(*)                                                AS total,
    SUM(is_fraud)                                           AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2)             AS fraud_rate_pct,
    ROUND(SUM(CASE WHEN is_fraud=1 THEN amt ELSE 0 END), 2) AS fraud_amount
FROM transactions_enriched
GROUP BY state;

-- View 3: Full enriched table (for Tableau data source)
SELECT * FROM transactions_enriched LIMIT 500000;
