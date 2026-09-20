# FinTrust Digital Bank Experience Lab: Data Analytics Track

Data analytics work for the FinTrust Digital Bank Experience Lab, a 4-week project run by AnalystLab Africa. FinTrust is a fictional digital bank, and all data in this project is synthetic and used for educational purposes only.

## Project goal

FinTrust has customer and transaction data but no integrated view of it. My track turns that data into business intelligence: profiling and cleaning the data, defining KPIs, finding patterns in customer and transaction behaviour, and building a Power BI dashboard for management.

## Current status

- [x] Week 1: Business understanding, data profiling, analytical questions, KPI plan, dashboard wireframe
- [ ] Week 2: Data cleaning, SQL and Python analysis, early dashboard
- [ ] Week 3: Completed and validated dashboard, outputs for integration
- [ ] Week 4: Testing, refinement, recommendations and final presentation

## Repository structure

- docs/    Week 1 submission report (Word and PDF)
- data/    Synthetic FinTrust customer and transaction data
- scripts/ Python profiling script (SQL, Pandas and Power BI files will be added in Weeks 2 to 4)

## Data

- Customer data: 1,500 records, 12 columns
- Transaction data: 12,000 records, 11 columns, covering 1 Jan to 31 Mar 2026
- The two tables link through Customer_ID (one customer to many transactions)

## Key Week 1 findings

Data quality (raw data, before any cleaning):
- 96 missing Device_Type and 96 missing Location values in the transaction data (188 rows affected)
- Device_Type does not match Channel (for example, ATM transactions recorded on Android devices)
- Transaction location matches the customer's home city in only 12.7% of cases, close to random
- Dormant and Restricted customers still made transactions, so Account_Status may not reflect status at transaction time
- Transactions are spread evenly across hours and weekdays, which points to synthetic generation
- Amounts are heavily skewed (median about NGN 10.3k, mean about NGN 46.7k)

Early business signals (to be validated in Week 2):
- Transaction success rate is 90.5%; 5.3% failed and 2.7% were reversed
- 19.6% of transactions are flagged for risk review
- International transactions are flagged far more often than domestic ones (36.9% vs 18.9%)
- The top 10% of customers account for about 26% of total transaction value

## Planned KPIs

1. Total transaction volume
2. Total transaction value
3. Average transaction value (with median)
4. Transaction success rate
5. Failed and reversed rate
6. Risk review rate
7. Channel share
8. Average transactions per customer

## Dashboard plan

Four Power BI pages: Executive Overview, Customer Behaviour, Transactions and Channels, and Status and Risk, with filters for date, channel, transaction type, status, segment, account status and city.

## Tools

Python (Pandas), SQL, Power BI (DAX), Excel

## Limitations

- The data is synthetic, so findings may not reflect real banking behaviour.
- Risk_Review_Flag is a synthetic label and not a real fraud determination.
- The transactions cover only 3 months, so there is no yearly or seasonal analysis.
- There is no fee, revenue or failure-reason data.

## How to run the profiling script

pip install pandas
python scripts/profile_fintrust.py

## Author

Olabisi Amusan
LinkedIn: linkedin.com/in/amusanolabisi
