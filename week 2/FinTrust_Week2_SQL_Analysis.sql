-- create the customers table
CREATE TABLE customers (
customer_id VARCHAR(20) PRIMARY KEY,
customer_name VARCHAR(100),
age INT,
gender VARCHAR(20),
city VARCHAR(50),
customer_segment VARCHAR(50),
account_type VARCHAR(50),
tenure_months INT,
digital_engagement_score NUMERIC(5,2),
monthly_income_band VARCHAR(50),
preferred_channel VARCHAR(50),
account_status VARCHAR(20)
);

-- create the transactions table
CREATE TABLE transactions (
transaction_id VARCHAR(20) PRIMARY KEY,
customer_id VARCHAR(20) REFERENCES customers(customer_id),
transaction_datetime TEXT,
transaction_type VARCHAR(50),
amount_ngn NUMERIC(14,2),
channel VARCHAR(30),
device_type VARCHAR(30),
location VARCHAR(50),
international_transaction VARCHAR(5),
transaction_status VARCHAR(20),
risk_review_flag VARCHAR(5)
);

-- 3. Confirm both tables exist
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

-- Load customers FIRST (transactions depends on it)
-- Then load transactions

-- Verify row counts
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM transactions;

-- Fix the datetime column (locale-proof, explicit format mask)
ALTER TABLE transactions ADD COLUMN txn_datetime TIMESTAMP;

UPDATE transactions
SET txn_datetime = TO_TIMESTAMP(transaction_datetime, 'MM/DD/YYYY HH24:MI');

-- Verify it worked (should return 0)
SELECT COUNT(*) FROM transactions WHERE txn_datetime IS NULL;

-- Question 1: Which customer segment generates the most transaction volume?
SELECT c.customer_segment, COUNT(*) AS txn_count, SUM(t.amount_ngn) AS total_value
FROM transactions t JOIN customers c ON t.customer_id = c.customer_id
GROUP BY c.customer_segment
ORDER BY total_value DESC;

-- Question 2: Average transactions per customer, by account type
SELECT c.account_type, COUNT(*)::numeric / COUNT(DISTINCT c.customer_id) AS avg_txns_per_customer
FROM transactions t JOIN customers c ON t.customer_id = c.customer_id
GROUP BY c.account_type;

-- Question 3: Total and average value by transaction type
SELECT transaction_type, COUNT(*) AS n, SUM(amount_ngn) AS total_value, AVG(amount_ngn) AS avg_value
FROM transactions
GROUP BY transaction_type
ORDER BY total_value DESC;

-- Question 4: Share of total transaction value by type
SELECT transaction_type,
SUM(amount_ngn) AS total_value,
ROUND(SUM(amount_ngn) * 100.0 / (SELECT SUM(amount_ngn) FROM transactions), 2) AS pct_of_total
FROM transactions
GROUP BY transaction_type
ORDER BY pct_of_total DESC;

-- Question 5: Channel volume and average transaction value
SELECT channel, COUNT(*) AS txn_count, AVG(amount_ngn) AS avg_value
FROM transactions
GROUP BY channel
ORDER BY txn_count DESC;

-- Question 6: Success rate by channel
SELECT channel,
COUNT(*) AS total,
SUM(CASE WHEN transaction_status = 'Successful' THEN 1 ELSE 0 END) AS successful,
ROUND(SUM(CASE WHEN transaction_status = 'Successful' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),2) AS success_rate_pct
FROM transactions
GROUP BY channel
ORDER BY success_rate_pct ASC;

-- Question 7: Risk-review rate by customer segment
SELECT c.customer_segment,
COUNT(*) AS total_txns,
SUM(CASE WHEN t.risk_review_flag = 'Yes' THEN 1 ELSE 0 END) AS flagged,
ROUND(SUM(CASE WHEN t.risk_review_flag = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),2) AS risk_rate_pct
FROM transactions t JOIN customers c ON t.customer_id = c.customer_id
GROUP BY c.customer_segment
ORDER BY risk_rate_pct DESC;

-- Question 8: Are international transactions flagged more often?
SELECT international_transaction,
COUNT(*) AS total,
SUM(CASE WHEN risk_review_flag = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS risk_rate_pct
FROM transactions
GROUP BY international_transaction;