"""
FinTrust Digital Bank Experience Lab - Week 1 data profiling
Track: Data Analytics | Author: Olabisi Amusan

Profiles the synthetic FinTrust customer and transaction datasets:
structure, missing values, duplicates, the customer-transaction join,
data-quality checks and a few early KPI baselines.
No cleaning is done here; this only inspects the raw data.

Usage:
    python profile_fintrust.py
    python profile_fintrust.py --customers path/to/customers.csv --transactions path/to/transactions.csv
"""

import argparse

import pandas as pd

pd.set_option("display.width", 200)
pd.set_option("display.max_columns", 50)


def section(title):
    print(f"\n{'=' * 70}\n{title}\n{'=' * 70}")


def profile_table(name, df):
    """Shape, data types, missing values and duplicates for one table."""
    section(f"{name.upper()}: STRUCTURE")
    print(f"Records: {len(df):,} | Columns: {df.shape[1]}")
    summary = pd.DataFrame({
        "dtype": df.dtypes.astype(str),
        "missing": df.isna().sum(),
        "missing_%": (df.isna().mean() * 100).round(2),
        "unique": df.nunique(),
    })
    print(summary)
    print(f"\nFully duplicated rows: {df.duplicated().sum()}")


def profile_values(df, categorical, numerical):
    """Category counts and numeric summaries."""
    for col in categorical:
        print(f"\n{col}")
        print(df[col].value_counts(dropna=False).to_string())
    print("\nNumerical summary")
    print(df[numerical].describe(percentiles=[0.05, 0.5, 0.95]).T.round(2))


def check_relationship(cust, txn):
    """How the two tables link through Customer_ID."""
    section("RELATIONSHIP: CUSTOMER_ID JOIN")
    print(f"Duplicate Customer_ID in customers: {cust['Customer_ID'].duplicated().sum()}")
    print(f"Duplicate Transaction_ID in transactions: {txn['Transaction_ID'].duplicated().sum()}")
    print(f"Transactions with no matching customer: {(~txn['Customer_ID'].isin(cust['Customer_ID'])).sum()}")
    print(f"Customers with no transactions: {(~cust['Customer_ID'].isin(txn['Customer_ID'])).sum()}")
    per_cust = txn.groupby("Customer_ID").size()
    print(f"Transactions per customer: min {per_cust.min()}, mean {per_cust.mean():.1f}, max {per_cust.max()}")


def quality_checks(cust, txn):
    """Checks for the data-quality issues documented in the Week 1 report."""
    section("DATA-QUALITY CHECKS")
    merged = txn.merge(cust, on="Customer_ID", how="left")
    when = pd.to_datetime(txn["Transaction_DateTime"], errors="coerce")

    print(f"Unparseable dates: {when.isna().sum()} | Range: {when.min()} to {when.max()}")
    print(f"Transactions with amount <= 0: {(txn['Amount_NGN'] <= 0).sum()}")

    both = (txn["Device_Type"].isna() & txn["Location"].isna()).sum()
    either = (txn["Device_Type"].isna() | txn["Location"].isna()).sum()
    print(f"Rows missing both Device_Type and Location: {both} | missing at least one: {either}")

    print("\n1) Device_Type vs Channel (counts):")
    print(pd.crosstab(txn["Channel"], txn["Device_Type"].fillna("(missing)")))

    print(f"\n2) Transaction Location equals customer City: {(merged['Location'] == merged['City']).mean():.1%}"
          " (random assignment across 8 cities would give about 12.5%)")
    print(f"3) Preferred_Channel equals Channel used: {(merged['Preferred_Channel'] == merged['Channel']).mean():.1%}")

    print("\n4) Transactions by Account_Status:")
    print(merged.groupby("Account_Status").agg(
        customers=("Customer_ID", "nunique"), transactions=("Transaction_ID", "count")))

    print("\n5) Transactions per hour of day (flat = synthetic pattern):")
    print(when.dt.hour.value_counts().sort_index().to_dict())
    print("Transactions per weekday:", when.dt.day_name().value_counts().to_dict())

    amt = txn["Amount_NGN"]
    print(f"\n6) Amount skew: median {amt.median():,.0f} | mean {amt.mean():,.0f} | max {amt.max():,.0f}")


def early_signals(cust, txn):
    """Baseline KPIs and first look at status and risk patterns."""
    section("EARLY KPI BASELINES AND SIGNALS")
    when = pd.to_datetime(txn["Transaction_DateTime"], errors="coerce")
    flagged = txn["Risk_Review_Flag"].eq("Yes")

    print(f"Total volume: {len(txn):,} | Total value: NGN {txn['Amount_NGN'].sum():,.0f}")
    print("Volume by month:", txn.groupby(when.dt.to_period("M")).size().to_dict())
    print("\nStatus share (%):")
    print((txn["Transaction_Status"].value_counts(normalize=True) * 100).round(1).to_string())
    print("\nChannel share (%):")
    print((txn["Channel"].value_counts(normalize=True) * 100).round(1).to_string())
    print(f"\nRisk review rate: {flagged.mean():.1%}")
    for col in ["International_Transaction", "Transaction_Type", "Transaction_Status", "Channel"]:
        print(f"\nRisk review rate by {col} (%):")
        print((flagged.groupby(txn[col]).mean() * 100).round(1).to_string())

    top5 = txn["Amount_NGN"] >= txn["Amount_NGN"].quantile(0.95)
    print(f"\nRisk review rate, top 5% by amount: {flagged[top5].mean():.1%} | rest: {flagged[~top5].mean():.1%}")

    by_cust = txn.groupby("Customer_ID")["Amount_NGN"].sum().sort_values(ascending=False)
    top10 = by_cust.head(int(len(cust) * 0.10)).sum() / by_cust.sum()
    print(f"Share of value from top 10% of customers: {top10:.1%}")


def main():
    parser = argparse.ArgumentParser(description="Profile the FinTrust customer and transaction data.")
    parser.add_argument("--customers", default="data/FinTrust_Customer_Data.csv")
    parser.add_argument("--transactions", default="data/FinTrust_Transaction_Data.csv")
    args = parser.parse_args()

    cust = pd.read_csv(args.customers)
    txn = pd.read_csv(args.transactions)

    profile_table("Customer data", cust)
    profile_values(
        cust,
        ["Gender", "City", "Customer_Segment", "Account_Type",
         "Monthly_Income_Band", "Preferred_Channel", "Account_Status"],
        ["Age", "Tenure_Months", "Digital_Engagement_Score"],
    )

    profile_table("Transaction data", txn)
    profile_values(
        txn,
        ["Transaction_Type", "Channel", "Device_Type", "Location",
         "International_Transaction", "Transaction_Status", "Risk_Review_Flag"],
        ["Amount_NGN"],
    )

    check_relationship(cust, txn)
    quality_checks(cust, txn)
    early_signals(cust, txn)


if __name__ == "__main__":
    main()
