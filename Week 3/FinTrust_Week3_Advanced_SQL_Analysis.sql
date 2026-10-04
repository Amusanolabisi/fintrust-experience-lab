-- Q1: Rank each customer by total transaction value WITHIN their own segment
-- (window function: RANK() + PARTITION BY)
WITH customer_totals AS (
SELECT c.customer_id, c.customer_segment,
SUM(t.amount_ngn) AS total_value
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_segment
)
SELECT customer_segment, customer_id, total_value,
RANK() OVER (PARTITION BY customer_segment ORDER BY total_value DESC) AS rank_in_segment
FROM customer_totals
ORDER BY customer_segment, rank_in_segment
LIMIT 20;


-- Q2: Customer-level transaction frequency, bucketed into High/Medium/Low activity
-- (CTE + CASE)
WITH txn_per_customer AS (
SELECT customer_id, COUNT(*) AS txn_count
FROM transactions
GROUP BY customer_id
)
SELECT
CASE WHEN txn_count >= 10 THEN 'High (10+)'
WHEN txn_count >= 5 THEN 'Medium (5-9)'
ELSE 'Low (1-4)'
END AS activity_band,
COUNT(*) AS num_customers,
ROUND(AVG(txn_count), 2) AS avg_txns_in_band
FROM txn_per_customer
GROUP BY activity_band
ORDER BY avg_txns_in_band DESC;


-- Q3: Month-over-month transaction trend with % change
-- (window function: LAG())
WITH monthly AS (
SELECT DATE_TRUNC('month', txn_datetime) AS month,
COUNT(*) AS txn_count,
SUM(amount_ngn) AS total_value
FROM transactions
GROUP BY DATE_TRUNC('month', txn_datetime)
)
SELECT month, txn_count, total_value,
LAG(txn_count) OVER (ORDER BY month) AS prev_month_count,
ROUND((txn_count - LAG(txn_count) OVER (ORDER BY month)) * 100.0
/ NULLIF(LAG(txn_count) OVER (ORDER BY month), 0), 1) AS pct_change
FROM monthly
ORDER BY month;


-- Q4: High-value transactions — flag anything above the 90th percentile FOR ITS OWN TYPE
-- (window function: PERCENTILE_CONT)
WITH type_thresholds AS (
SELECT transaction_type,
PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY amount_ngn) AS p90_value
FROM transactions
GROUP BY transaction_type
)
SELECT t.transaction_id, t.transaction_type, t.amount_ngn, t.customer_id
FROM transactions t
JOIN type_thresholds tt ON t.transaction_type = tt.transaction_type
WHERE t.amount_ngn > tt.p90_value
ORDER BY t.amount_ngn DESC
LIMIT 20;


-- Q5: Success rate by Segment x Channel combined (deeper than Week 2's single-variable view)
-- (CASE inside SUM, multi-column GROUP BY)
SELECT c.customer_segment, t.channel,
COUNT(*) AS total_txns,
SUM(CASE WHEN t.transaction_status = 'Successful' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS success_rate_pct
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id
GROUP BY c.customer_segment, t.channel
ORDER BY success_rate_pct ASC
LIMIT 10;


-- Q6: Within each segment, what share of RISK-FLAGGED value comes from the top 3 riskiest transactions?
-- (CTE + window function: ROW_NUMBER, cumulative SUM)
WITH risk_txns AS (
SELECT c.customer_segment, t.transaction_id, t.amount_ngn,
ROW_NUMBER() OVER (PARTITION BY c.customer_segment ORDER BY t.amount_ngn DESC) AS rn
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id
WHERE t.risk_review_flag = 'Yes'
)
SELECT customer_segment, transaction_id, amount_ngn, rn
FROM risk_txns
WHERE rn <= 3
ORDER BY customer_segment, rn;


-- Q7: International vs. domestic, broken down BY SEGMENT (not just overall)
-- (JOIN + CASE + multi-column GROUP BY)
SELECT c.customer_segment, t.international_transaction,
COUNT(*) AS txn_count,
ROUND(AVG(t.amount_ngn), 2) AS avg_amount,
ROUND(SUM(CASE WHEN t.risk_review_flag = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS risk_rate_pct
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id
GROUP BY c.customer_segment, t.international_transaction
ORDER BY c.customer_segment, t.international_transaction;


-- Q8: Digital engagement quartiles vs. transaction behavior
-- (window function: NTILE())
WITH engagement_quartiles AS (
SELECT customer_id, digital_engagement_score,
NTILE(4) OVER (ORDER BY digital_engagement_score) AS engagement_quartile
FROM customers
)
SELECT eq.engagement_quartile,
COUNT(DISTINCT eq.customer_id) AS num_customers,
COUNT(t.transaction_id) AS total_txns,
ROUND(COUNT(t.transaction_id) * 1.0 / COUNT(DISTINCT eq.customer_id), 2) AS avg_txns_per_customer
FROM engagement_quartiles eq
LEFT JOIN transactions t ON eq.customer_id = t.customer_id
GROUP BY eq.engagement_quartile
ORDER BY eq.engagement_quartile;