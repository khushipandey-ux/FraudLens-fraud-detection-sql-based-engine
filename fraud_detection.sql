-- ============================================
-- PROJECT: CREDIT CARD FRAUD DETECTION ENGINE
-- Author: Khushi Pandey
-- Database: MySQL
-- Dataset: 284,807 real credit card transactions
-- Goal: Flag and score suspicious transactions
-- ============================================


-- ============================================
-- STEP 1: UNDERSTAND THE DATA
-- ============================================

-- How many transactions do we have and how many are fraud?
-- Business Question: How rare is fraud in real life?
SELECT
    CASE WHEN Class = 0 THEN 'Legitimate' ELSE 'Fraud' END AS transaction_type,
    COUNT(*) AS total_transactions,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM transactions), 2) AS percentage
FROM transactions
GROUP BY Class;

-- ============================================
-- STEP 2: COMPARE FRAUD VS LEGITIMATE AMOUNTS
-- ============================================

-- Business Question: Do fraudsters spend differently?
SELECT
    CASE WHEN Class = 0 THEN 'Legitimate' ELSE 'Fraud' END AS transaction_type,
    ROUND(AVG(Amount), 2) AS avg_amount,
    ROUND(MIN(Amount), 2) AS min_amount,
    ROUND(MAX(Amount), 2) AS max_amount,
    ROUND(STDDEV(Amount), 2) AS std_deviation
FROM transactions
GROUP BY Class;

-- ============================================
-- STEP 3: FIND THE MOST DANGEROUS HOURS
-- ============================================

-- Business Question: What time of day do fraudsters attack?
SELECT
    FLOOR(Time_seconds / 3600) % 24 AS hour_of_day,
    COUNT(*) AS total_transactions,
    SUM(Class) AS fraud_count,
    ROUND(SUM(Class) * 100.0 / COUNT(*), 2) AS fraud_percentage
FROM transactions
GROUP BY hour_of_day
ORDER BY fraud_percentage DESC
LIMIT 10;

-- ============================================
-- STEP 4: FRAUD DETECTION ENGINE
-- Using CTEs + Window Functions + CASE WHEN
-- ============================================

-- HOW IT WORKS:
-- We apply 3 rules to every transaction
-- Each rule adds points to a fraud score
-- Rule 1: Large amount (40 points)
-- Rule 2: Odd hour midnight to 4am (20 points)
-- Rule 3: Micro transaction under $1 (30 points)
-- Score 60+ = HIGH RISK
-- Score 20-59 = MEDIUM RISK
-- Score below 20 = LOW RISK

WITH fraud_rules AS (
    SELECT
        Amount,
        FLOOR(Time_seconds / 3600) % 24 AS hour_of_day,
        Class AS actual_fraud,
        CASE WHEN Amount > (SELECT AVG(Amount) * 3 FROM transactions) THEN 40 ELSE 0 END AS score_large_amount,
        CASE WHEN FLOOR(Time_seconds / 3600) % 24 BETWEEN 0 AND 4 THEN 20 ELSE 0 END AS score_odd_hour,
        CASE WHEN Amount < 1 THEN 30 ELSE 0 END AS score_micro_txn,
        AVG(Amount) OVER (PARTITION BY FLOOR(Time_seconds / 3600) % 24) AS avg_amount_that_hour
    FROM transactions
),
fraud_scored AS (
    SELECT
        Amount,
        hour_of_day,
        actual_fraud,
        avg_amount_that_hour,
        score_large_amount,
        score_odd_hour,
        score_micro_txn,
        score_large_amount + score_odd_hour + score_micro_txn AS fraud_score
    FROM fraud_rules
),
fraud_tiered AS (
    SELECT
        Amount,
        hour_of_day,
        actual_fraud,
        fraud_score,
        score_large_amount,
        score_odd_hour,
        score_micro_txn,
        ROUND(avg_amount_that_hour, 2) AS avg_amount_that_hour,
        CASE
            WHEN fraud_score >= 60 THEN 'HIGH RISK'
            WHEN fraud_score >= 20 THEN 'MEDIUM RISK'
            ELSE 'LOW RISK'
        END AS risk_level,
        RANK() OVER (ORDER BY fraud_score DESC) AS risk_rank
    FROM fraud_scored
)
SELECT * FROM fraud_tiered
ORDER BY fraud_score DESC
LIMIT 100;

-- ============================================
-- STEP 5: HOW ACCURATE ARE OUR RULES?
-- ============================================

-- Business Question: Did our rules actually catch real fraud?
-- Precision = of what we flagged, how much was real fraud?
WITH fraud_rules AS (
    SELECT
        Amount,
        FLOOR(Time_seconds / 3600) % 24 AS hour_of_day,
        Class AS actual_fraud,
        CASE WHEN Amount > (SELECT AVG(Amount) * 3 FROM transactions) THEN 40 ELSE 0 END AS score_large_amount,
        CASE WHEN FLOOR(Time_seconds / 3600) % 24 BETWEEN 0 AND 4 THEN 20 ELSE 0 END AS score_odd_hour,
        CASE WHEN Amount < 1 THEN 30 ELSE 0 END AS score_micro_txn
    FROM transactions
),
fraud_scored AS (
    SELECT
        actual_fraud,
        score_large_amount + score_odd_hour + score_micro_txn AS fraud_score
    FROM fraud_rules
),
fraud_tiered AS (
    SELECT
        actual_fraud,
        fraud_score,
        CASE
            WHEN fraud_score >= 60 THEN 'HIGH RISK'
            WHEN fraud_score >= 20 THEN 'MEDIUM RISK'
            ELSE 'LOW RISK'
        END AS risk_level
    FROM fraud_scored
)
SELECT
    risk_level,
    COUNT(*) AS total_flagged,
    SUM(actual_fraud) AS real_fraud_caught,
    COUNT(*) - SUM(actual_fraud) AS false_positives,
    ROUND(SUM(actual_fraud) * 100.0 / COUNT(*), 2) AS precision_percentage
FROM fraud_tiered
GROUP BY risk_level
ORDER BY FIELD(risk_level, 'HIGH RISK', 'MEDIUM RISK', 'LOW RISK');




-- QUERY 6: BEHAVIOURAL BASELINE
 WITH cb AS
  (SELECT customer_id, Amount, 
  Class AS actual_fraud,
   AVG(Amount) OVER (PARTITION BY customer_id) AS cust_avg, 
   STDDEV(Amount) OVER (PARTITION BY customer_id) AS cust_std, 
   COUNT(*) OVER (PARTITION BY customer_id) AS cust_total FROM transactions),
    bf AS (SELECT customer_id, Amount, actual_fraud, cust_avg, cust_std, cust_total, 
    ROUND(Amount - cust_avg, 2) AS deviation, CASE WHEN cust_std = 0 THEN 'NORMAL' WHEN (Amount - cust_avg) / cust_std > 3 THEN
     'HIGHLY ABNORMAL' WHEN (Amount - cust_avg) / cust_std > 2 THEN 'ABNORMAL' 
     WHEN (Amount - cust_avg) / cust_std > 1 THEN 'SLIGHTLY ABNORMAL' ELSE 'NORMAL' END AS behaviour_flag FROM cb) 
     SELECT behaviour_flag, COUNT(*) AS total_transactions, SUM(actual_fraud) AS fraud_caught, COUNT(*) - SUM(actual_fraud) AS false_positives, 
     ROUND(AVG(Amount), 2) AS avg_amount, ROUND(SUM(actual_fraud) * 100.0 / COUNT(*), 2) AS precision_pct FROM bf GROUP BY behaviour_flag ORDER BY precision_pct DESC;


     --QUERY 7 -- VELOCITY DETECTION
-- How many transactions happened within every 1 hour window?
-- This catches fraudsters who make multiple purchases rapidly

WITH hourly_velocity AS (
    SELECT
        Amount,
        Class AS actual_fraud,
        FLOOR(Time_seconds / 3600) % 24 AS hour_of_day,
        COUNT(*) OVER (PARTITION BY FLOOR(Time_seconds / 3600) % 24) AS transactions_that_hour,
        SUM(Amount) OVER (PARTITION BY FLOOR(Time_seconds / 3600) % 24) AS total_spent_that_hour,
        RANK() OVER (PARTITION BY FLOOR(Time_seconds / 3600) % 24 ORDER BY Amount DESC) AS rank_within_hour
    FROM transactions
),
velocity_flagged AS (
    SELECT
        Amount,
        actual_fraud,
        hour_of_day,
        transactions_that_hour,
        total_spent_that_hour,
        rank_within_hour,
        CASE
            WHEN transactions_that_hour > 5000 THEN 'HIGH VELOCITY'
            WHEN transactions_that_hour > 3000 THEN 'MEDIUM VELOCITY'
            ELSE 'NORMAL'
        END AS velocity_flag
    FROM hourly_velocity
)
SELECT
    hour_of_day,
    velocity_flag,
    COUNT(*) AS total_transactions,
    SUM(actual_fraud) AS fraud_in_this_group,
    ROUND(AVG(Amount), 2) AS avg_amount,
    ROUND(SUM(actual_fraud) * 100.0 / COUNT(*), 2) AS fraud_rate
FROM velocity_flagged
GROUP BY hour_of_day, velocity_flag
ORDER BY fraud_rate DESC;






--- QUERY 8: FRAUD SUMMARY REPORT
-- One query that tells the complete fraud story
-- Shows total fraud, money lost, peak hour, and detection accuracy

WITH base_stats AS (
    -- Overall transaction statistics
    SELECT
        COUNT(*) AS total_transactions,
        SUM(Class) AS total_fraud,
        SUM(Amount) AS total_volume,
        SUM(CASE WHEN Class = 1 THEN Amount ELSE 0 END) AS fraud_volume,
        AVG(Amount) AS avg_transaction,
        MAX(Amount) AS largest_transaction
    FROM transactions
),
hourly_fraud AS (
    -- Find the single most dangerous hour of the day
    SELECT
        FLOOR(Time_seconds / 3600) % 24 AS hour_of_day,
        SUM(Class) AS fraud_count
    FROM transactions
    GROUP BY hour_of_day
    ORDER BY fraud_count DESC
    LIMIT 1
),
fraud_rules AS (
    -- Apply scoring rules to every transaction
    SELECT
        CASE WHEN Amount > (SELECT AVG(Amount) * 3 FROM transactions) THEN 40 ELSE 0 END +
        CASE WHEN FLOOR(Time_seconds / 3600) % 24 BETWEEN 0 AND 4 THEN 20 ELSE 0 END +
        CASE WHEN Amount < 1 THEN 30 ELSE 0 END AS fraud_score,
        Class
    FROM transactions
),
risk_summary AS (
    -- Count how many transactions fell into each risk tier
    SELECT
        SUM(CASE WHEN fraud_score >= 60 THEN 1 ELSE 0 END) AS high_risk_count,
        SUM(CASE WHEN fraud_score >= 20 AND fraud_score < 60 THEN 1 ELSE 0 END) AS medium_risk_count,
        SUM(CASE WHEN fraud_score >= 60 AND Class = 1 THEN 1 ELSE 0 END) AS high_risk_fraud_caught
    FROM fraud_rules
)
SELECT
    b.total_transactions,
    b.total_fraud AS confirmed_fraud_cases,
    ROUND(b.total_fraud * 100.0 / b.total_transactions, 2) AS fraud_rate_percent,
    ROUND(b.total_volume, 2) AS total_transaction_volume,
    ROUND(b.fraud_volume, 2) AS total_fraud_volume,
    ROUND(b.fraud_volume * 100.0 / b.total_volume, 2) AS fraud_volume_percent,
    ROUND(b.avg_transaction, 2) AS avg_transaction_amount,
    h.hour_of_day AS peak_fraud_hour,
    r.high_risk_count AS transactions_flagged_high_risk,
    r.medium_risk_count AS transactions_flagged_medium_risk,
    r.high_risk_fraud_caught AS confirmed_fraud_in_high_risk,
    ROUND(r.high_risk_fraud_caught * 100.0 / r.high_risk_count, 2) AS high_risk_precision_percent
FROM base_stats b, hourly_fraud h, risk_summary r;