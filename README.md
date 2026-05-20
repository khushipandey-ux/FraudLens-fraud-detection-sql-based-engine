# FraudLens-fraud-detection-sql-based-engine
FraudLens — Multi Layer Fraud Detection Engine Using SQL
A rule-based fraud detection and scoring system built entirely in MySQL on 284,807 real anonymized credit card transactions. FraudLens goes beyond simple flagging — it scores every transaction from 0 to 100, tiers them into risk levels, compares each transaction against that customer's own spending history, and measures the precision of each detection rule against actual fraud labels.

Why I Built This
Fraud detection is one of the most high stakes problems in banking. Every major bank runs some version of this logic in production. I wanted to understand how analysts think about fraud at a technical level, so I built a complete detection engine from scratch using only SQL — the same tool fraud analysts use every day.

Dataset

Source: Credit Card Fraud Detection — Kaggle (ULB Machine Learning Group)
Size: 284,807 real anonymized transactions from a European bank
Fraud cases: 492 confirmed fraud transactions (0.17% of total)
Features: Time, Amount, Class (fraud label), V1 through V28 (PCA anonymized features)
Why this dataset: Real transactions, severe class imbalance, industry standard benchmark dataset used by data scientists worldwide


Project Architecture
Raw CSV Dataset (284,807 transactions)
        |
        v
MySQL Database — fraud_detection
        |
        v
8 SQL Queries across 3 layers

Layer 1 — Data Exploration
  Query 1: Fraud vs Legitimate distribution
  Query 2: Amount pattern comparison
  Query 3: Peak fraud hours analysis

Layer 2 — Detection Engine
  Query 4: Multi rule fraud scoring engine
  Query 5: Precision measurement per risk tier

Layer 3 — Advanced Analysis
  Query 6: Behavioural baseline — customer level anomaly detection
  Query 7: Velocity detection — transaction frequency analysis
  Query 8: Executive summary report
        |
        v
Risk Tiered Output
HIGH RISK / MEDIUM RISK / LOW RISK

Key Findings
Finding 1 — Fraud is Rare but Costly

Only 0.17% of all transactions are fraud
Fraudulent transactions average $122 vs $88 for legitimate ones
Fraudsters spend 38% more per transaction on average

Finding 2 — Time Patterns Reveal Fraud

Midnight to 4am has the highest fraud concentration
Time based rules contribute 20 points to the fraud score
Peak fraud hour identified through hourly aggregation analysis

Finding 3 — Behavioural Anomalies are the Strongest Signal

Transactions flagged as HIGHLY ABNORMAL — 3 or more standard deviations from customer average — have 2x higher fraud rate than normal transactions
Behavioural baseline catches fraud that amount rules alone would miss
This mirrors how real bank fraud systems compare spending to individual customer history

Finding 4 — Velocity Spikes Indicate Fraud Clusters

High velocity hours show elevated fraud rates
Fraudsters cluster transactions rapidly to use stolen cards before detection
Velocity analysis adds a time frequency dimension beyond simple hour flagging
Detection Rules and Scoring System
RuleLogicPointsLarge AmountTransaction is more than 3x the dataset average40Odd HourTransaction happens between midnight and 4am20Micro TransactionAmount is under $1 — card testing pattern30
Total ScoreRisk Level60 and aboveHIGH RISK20 to 59MEDIUM RISKBelow 20LOW RISK
Maximum possible score is 90 points if all three rules trigger simultaneously.

Feature Engineering
Since the dataset was anonymized via PCA and lacked certain analytical columns, three features were engineered:
Engineered FeatureMethodPurposehour_of_dayFLOOR(Time_seconds / 3600) % 24Convert raw seconds into meaningful hour of daycustomer_idABS(ROUND(V1))Create proxy customer identity from strongest PCA componentdeviation_from_normalAmount minus customer averageMeasure how unusual a transaction is for that specific customerstd_deviations_awayDeviation divided by customer standard deviationNormalize deviation across customers with different spending ranges

SQL Techniques Used
TechniqueWhere AppliedCTEs — Common Table ExpressionsQueries 4, 6, 7, 8 — multi step logic pipelinesWindow Function AVG OVER PARTITION BYQuery 6 — customer level average spendingWindow Function STDDEV OVER PARTITION BYQuery 6 — customer level standard deviationWindow Function COUNT OVER PARTITION BYQuery 7 — hourly transaction frequencyWindow Function RANK OVER ORDER BYQueries 4, 7 — transaction risk rankingCASE WHENAll queries — rule based flagging and scoringSubqueriesQuery 4 — dynamic average threshold calculationFLOOR and MODAll queries — timestamp to hour conversionSTDDEV aggregateQuery 2 — amount distribution analysisSUM with CASE WHENQuery 8 — conditional aggregation for reporting

Query Breakdown
Query 1 — Data Distribution
Business question: How rare is fraud in real life?
Shows exact count and percentage split between fraud and legitimate transactions.
Query 2 — Amount Analysis
Business question: Do fraudsters spend differently than normal customers?
Compares average, minimum, maximum, and standard deviation of transaction amounts by class.
Query 3 — Peak Fraud Hours
Business question: What time of day do fraudsters attack most?
Converts raw seconds to hour of day and ranks hours by fraud percentage.
Query 4 — Fraud Scoring Engine
The core of the project. Three CTEs build a complete pipeline:

fraud_rules applies each detection rule and assigns weighted point scores
fraud_scored sums all rule scores into one total fraud score per transaction
fraud_tiered assigns HIGH, MEDIUM, LOW risk labels and ranks all transactions using RANK window function

Query 5 — Precision Measurement
Business question: Did our rules actually work?
Measures precision at each risk tier — what percentage of flagged transactions were confirmed fraud.
Query 6 — Behavioural Baseline
The most advanced query in the project. For each transaction, calculates that customer's historical average and standard deviation using window functions partitioned by customer ID. Then measures how many standard deviations away the current transaction sits from that baseline. Flags HIGHLY ABNORMAL, ABNORMAL, SLIGHTLY ABNORMAL, and NORMAL behaviour. This is exactly how real bank fraud systems think — not just is this amount large, but is this amount large for this specific customer.
Query 7 — Velocity Detection
Counts transactions per hour using COUNT OVER PARTITION BY window function. Calculates total money moved per hour. Ranks transactions within each hour by amount. Flags HIGH VELOCITY and MEDIUM VELOCITY hours. Measures fraud rate at each velocity level to validate whether transaction speed correlates with fraud.
Query 8 — Executive Summary Report
One single query that joins 4 CTEs to produce a complete management report. Shows total confirmed fraud cases, total fraud volume in dollars, percentage of all money that was fraudulent, peak fraud hour, number of transactions flagged at each risk tier, and precision of the HIGH RISK detection tier. This is the output a fraud analyst presents to their manager every morning.

How to Run This Project
Requirements

MySQL 8.0 or above
VS Code with MySQL extension or MySQL Workbench

Setup
sqlCREATE DATABASE fraud_detection;
USE fraud_detection;
Dataset
Download creditcard.csv from Kaggle:
https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud
Run
Open fraud_detection.sql and run each query section individually by selecting it and pressing Ctrl+Enter in VS Code.

Industries That Use This Type of Analysis

Banking — RBC, TD, Scotiabank, CIBC — stolen card detection
Fintech — Stripe, PayPal, Square — payment fraud prevention
E-commerce — Amazon, Shopify — fake order detection
Insurance — fraudulent claims detection
Healthcare — fraudulent billing detection
Government — tax fraud and benefits fraud detection
