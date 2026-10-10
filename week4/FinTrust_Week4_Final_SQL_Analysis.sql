-- ============================================================
-- FinTrust Week 4 — Final SQL Analysis
-- ============================================================

-- ============================================================
-- Question 1: Which customer segment generates the most transaction value?
-- Technique: JOIN + GROUP BY + aggregation
-- ============================================================
SELECT c.customer_segment, COUNT(*) AS txn_count, SUM(t.amount_ngn) AS total_value
FROM transactions t JOIN customers c ON t.customer_id = c.customer_id
GROUP BY c.customer_segment
ORDER BY total_value DESC;
-- Reveals: Everyday leads on total value (about ₦261M) because it is the largest
-- segment (711 customers). Value per customer is similar across segments
-- (roughly ₦365K-₦388K), so segment size, not richness, drives the totals.


-- ============================================================
-- Question 2: Success rate by channel
-- Technique: CASE inside aggregation
-- ============================================================
SELECT channel,
COUNT(*) AS total,
ROUND(SUM(CASE WHEN transaction_status = 'Successful' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
2) AS success_rate_pct
FROM transactions
GROUP BY channel
ORDER BY success_rate_pct ASC;
-- Reveals: Mobile App has the lowest success rate (89.75%) and ATM the highest
-- (91.70%).


-- ============================================================
-- Question 3: Rank each customer by transaction value within their own segment
-- Technique: CTE + window function (RANK, PARTITION BY)
-- ============================================================
WITH customer_totals AS (
    SELECT c.customer_id, c.customer_segment, SUM(t.amount_ngn) AS total_value
    FROM transactions t JOIN customers c ON t.customer_id = c.customer_id
    GROUP BY c.customer_id, c.customer_segment
)
SELECT customer_segment, customer_id, total_value,
       RANK() OVER (PARTITION BY customer_segment ORDER BY total_value DESC) AS rank_in_segment
FROM customer_totals
ORDER BY customer_segment, rank_in_segment;
-- Reveals: The highest-value individual customers inside each segment, so
-- retention effort can target specific accounts instead of whole segments.


-- ============================================================
-- Question 4: Monthly trend with a day-normalized rate
-- Technique: CTE + window function (LAG)
-- ============================================================
WITH monthly AS (
    SELECT DATE_TRUNC('month', txn_datetime) AS month, COUNT(*) AS txn_count
    FROM transactions
    GROUP BY DATE_TRUNC('month', txn_datetime)
)
SELECT month, txn_count,
ROUND(txn_count / EXTRACT(DAY FROM (month + INTERVAL '1 month' - INTERVAL '1 day')), 1) AS daily_rate,
LAG(txn_count) OVER (ORDER BY month) AS prev_month_count
FROM monthly
ORDER BY month;
-- Reveals: Raw counts (4,133 / 3,734 / 4,133) make February look like a dip, but
-- the daily rate is flat (about 133 per day). The dip is a calendar artifact.


-- ============================================================
-- Question 5: Risk-review rate for high-value vs. normal transactions
-- (high-value = top 10% within each transaction type)
-- Technique: CTE + PERCENTILE_CONT + CASE
-- ============================================================
WITH type_thresholds AS (
    SELECT transaction_type, PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY amount_ngn) AS p90_value
    FROM transactions
    GROUP BY transaction_type
)
SELECT (t.amount_ngn > tt.p90_value) AS is_high_value,
COUNT(*) AS txn_count,
ROUND(SUM(CASE WHEN t.risk_review_flag = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS risk_rate_pct
FROM transactions t
JOIN type_thresholds tt ON t.transaction_type = tt.transaction_type
GROUP BY (t.amount_ngn > tt.p90_value)
ORDER BY is_high_value;
-- Reveals: High-value transactions are flagged for review 29.5% of the time versus
-- 18.5% for the rest, roughly 1.6x higher.


-- ============================================================
-- Question 6: Success rate by segment and channel together
-- Technique: JOIN + CASE + multi-column GROUP BY
-- ============================================================
SELECT c.customer_segment, t.channel,
COUNT(*) AS total_txns,
ROUND(SUM(CASE WHEN t.transaction_status = 'Successful' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
2) AS success_rate_pct
FROM transactions t JOIN customers c ON t.customer_id = c.customer_id
GROUP BY c.customer_segment, t.channel
ORDER BY success_rate_pct ASC
LIMIT 5;
-- Reveals: The weakest pairing is Student customers on Web (88.1%), slightly below
-- Mobile App's worst segment (Student, 88.5%). The problem is narrower than "Mobile App".


-- ============================================================
-- Question 7: International vs. domestic risk-review rate, by segment
-- Technique: JOIN + CASE + multi-column GROUP BY
-- ============================================================
SELECT c.customer_segment, t.international_transaction,
COUNT(*) AS txn_count,
ROUND(SUM(CASE WHEN t.risk_review_flag = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS risk_rate_pct
FROM transactions t JOIN customers c ON t.customer_id = c.customer_id
GROUP BY c.customer_segment, t.international_transaction
ORDER BY c.customer_segment, t.international_transaction;
-- Reveals: International transactions are flagged about twice as often as domestic
-- ones in every segment (33-41% vs. 19-20%), highest for SME at 40.6%.


-- ============================================================
-- Question 8: Digital engagement quartile vs. transaction frequency
-- Technique: CTE + window function (NTILE) + LEFT JOIN
-- ============================================================
WITH engagement_quartiles AS (
    SELECT customer_id, NTILE(4) OVER (ORDER BY digital_engagement_score) AS engagement_quartile
    FROM customers
)
SELECT eq.engagement_quartile,
       COUNT(DISTINCT eq.customer_id) AS num_customers,
       ROUND(COUNT(t.transaction_id) * 1.0 / COUNT(DISTINCT eq.customer_id), 2) AS avg_txns_per_customer
FROM engagement_quartiles eq
LEFT JOIN transactions t ON eq.customer_id = t.customer_id
GROUP BY eq.engagement_quartile
ORDER BY eq.engagement_quartile;
-- Reveals: Average transactions per customer is nearly flat across quartiles
-- (about 7.9 to 8.3), so engagement score does not predict activity.