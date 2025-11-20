#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
prepare_gss_aggregates.py

Pre-processes GSS 2024 data to create annual aggregates of key variables
that will be merged with FRED economic data. This reduces processing burden
on Stata and allows for more flexible variable selection.

Input:  gss7224_r2.dta
Output: gss_annual_aggregates.csv

Variables aggregated:
  - Union membership rate (%)
  - Employment rate (%)
  - Bachelor's degree or higher (%)
  - Average income (mean)
  - Count of respondents per year
"""

import pandas as pd
import numpy as np
import logging
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
)

# Configuration
GSS_INPUT = "gss7224_r2.dta"
OUTPUT_CSV = "gss_annual_aggregates.csv"

def prepare_gss_data():
    """Load GSS data, aggregate by year, export CSV."""

    logging.info(f"Loading GSS data from {GSS_INPUT}...")
    try:
        df = pd.read_stata(GSS_INPUT)
    except Exception as e:
        logging.error(f"Failed to load GSS data: {e}")
        return

    logging.info(f"Loaded {len(df)} respondents with {len(df.columns)} variables")

    # Identify year column
    year_col = None
    for col in ['YEAR', 'year', 'Year']:
        if col in df.columns:
            year_col = col
            break

    if year_col is None:
        logging.error("Could not find year column in GSS data")
        return

    logging.info(f"Using year column: {year_col}")

    # Filter to years with sufficient respondent counts (optional)
    df['year'] = df[year_col].astype(int)

    # Create binary indicators for key variables
    indicators = {}

    # Union membership
    if 'UNION' in df.columns or 'union' in df.columns:
        union_col = 'UNION' if 'UNION' in df.columns else 'union'
        df['union_indicator'] = (df[union_col] == 1).astype(float)
        indicators['gss_union_pct'] = 'union_indicator'
        logging.info(f"Union membership: {df[union_col].value_counts().to_dict()}")

    # Employment status
    if 'WRKSTAT' in df.columns or 'wrkstat' in df.columns:
        wrkstat_col = 'WRKSTAT' if 'WRKSTAT' in df.columns else 'wrkstat'
        df['employed_indicator'] = (df[wrkstat_col] == 1).astype(float)
        indicators['gss_employed_pct'] = 'employed_indicator'
        logging.info(f"Employment: {df[wrkstat_col].value_counts().head(3).to_dict()}")

    # College education (Bachelor's+)
    if 'DEGREE' in df.columns or 'degree' in df.columns:
        degree_col = 'DEGREE' if 'DEGREE' in df.columns else 'degree'
        # Typically: 0=<HS, 1=HS, 2=Some College, 3=Bachelor's, 4=Graduate
        df['college_indicator'] = (df[degree_col] >= 3).astype(float)
        indicators['gss_college_pct'] = 'college_indicator'
        logging.info(f"Education: {df[degree_col].value_counts().sort_index().to_dict()}")

    # Income
    income_cols = ['REALINC', 'realinc', 'INCOME', 'income']
    income_col = next((col for col in income_cols if col in df.columns), None)
    if income_col:
        df['income_value'] = df[income_col]
        indicators['gss_avg_income'] = 'income_value'
        logging.info(f"Income available: {df[income_col].describe()}")

    # Aggregate by year
    logging.info("Aggregating data by year...")

    agg_dict = {}
    for output_name, indicator_col in indicators.items():
        agg_dict[indicator_col] = 'mean'
    agg_dict['year'] = 'count'  # count respondents

    aggregated = df.groupby('year').agg(agg_dict).reset_index()
    aggregated = aggregated.rename(columns={'year': 'respondent_count'})

    # Scale percentages to 0-100
    for col in aggregated.columns:
        if 'pct' in col and col != 'respondent_count':
            aggregated[col] = aggregated[col] * 100

    # Sort and clean
    aggregated = aggregated.sort_values('year').reset_index(drop=True)

    logging.info(f"Aggregated to {len(aggregated)} years")
    logging.info(f"\nAggregated data:\n{aggregated.head(10)}")

    # Export to CSV
    logging.info(f"Exporting to {OUTPUT_CSV}...")
    aggregated.to_csv(OUTPUT_CSV, index=False)

    logging.info("Done.")

if __name__ == "__main__":
    prepare_gss_data()
