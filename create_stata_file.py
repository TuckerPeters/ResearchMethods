#!/usr/bin/env python3
"""
create_stata_file.py

Converts the population_impact_datasets.csv into a Stata .dta file with:
- Proper variable labels
- Selected key variables (simplifying from 14 to more manageable set)
- Year-based aggregation for annual analysis
- Categorical variables for data visualization

This creates an annual time-series dataset suitable for Stata analysis.
"""

import pandas as pd
import numpy as np

# Read the CSV
print("Reading population_impact_datasets.csv...")
df = pd.read_csv("population_impact_datasets.csv")
df['date'] = pd.to_datetime(df['date'])

# Extract year and month
df['year'] = df['date'].dt.year
df['month'] = df['date'].dt.month

# Create annual dataset by taking December values (or last available value of year)
# For monthly data: use December values
# For annual data: use the value that exists (typically Jan 1 of that year)

print("Creating annual aggregation...")
annual_data = []

for year in sorted(df['year'].unique()):
    year_data = df[df['year'] == year]

    # For monthly series, prefer December; otherwise take last available
    monthly_dec = year_data[year_data['month'] == 12]

    if len(monthly_dec) > 0:
        # Use December data for monthly series
        unemp = monthly_dec['UNEMPLOYMENT_RATE'].values[0]
        lfpr = monthly_dec['LABOR_FORCE_PARTICIPATION'].values[0]
    else:
        # Take last available value for the year
        unemp = year_data['UNEMPLOYMENT_RATE'].iloc[-1]
        lfpr = year_data['LABOR_FORCE_PARTICIPATION'].iloc[-1]

    # For annual series, take the non-null value (should be Jan 1)
    annual_series = year_data[year_data['REAL_MEDIAN_HH_INCOME'].notna()]
    if len(annual_series) > 0:
        income = annual_series['REAL_MEDIAN_HH_INCOME'].iloc[0]
    else:
        income = np.nan

    gini_series = year_data[year_data['GINI_INDEX'].notna()]
    if len(gini_series) > 0:
        gini = gini_series['GINI_INDEX'].iloc[0]
    else:
        gini = np.nan

    pce_series = year_data[year_data['REAL_PCE_PER_CAPITA'].notna()]
    if len(pce_series) > 0:
        pce = pce_series['REAL_PCE_PER_CAPITA'].iloc[0]
    else:
        pce = np.nan

    life_series = year_data[year_data['LIFE_EXPECTANCY_AT_BIRTH'].notna()]
    if len(life_series) > 0:
        life_exp = life_series['LIFE_EXPECTANCY_AT_BIRTH'].iloc[0]
    else:
        life_exp = np.nan

    pov_series = year_data[year_data['POVERTY_RATE_OFFICIAL'].notna()]
    if len(pov_series) > 0:
        poverty = pov_series['POVERTY_RATE_OFFICIAL'].iloc[0]
    else:
        poverty = np.nan

    annual_data.append({
        'year': year,
        'unemp_rate': unemp,
        'lfpr': lfpr,
        'med_income': income,
        'gini': gini,
        'pce_capita': pce,
        'life_expect': life_exp,
        'poverty_rate': poverty
    })

stata_df = pd.DataFrame(annual_data)

# Create categorical variables for Stata analysis
# Decade variable (nominal)
stata_df['decade'] = (stata_df['year'] // 10) * 10

# Economic era (ordinal/nominal)
def categorize_era(year):
    if year < 1946:
        return 1  # Pre-WWII/WWII
    elif year < 1973:
        return 2  # Post-war boom
    elif year < 1991:
        return 3  # Stagflation/Reagan era
    elif year < 2008:
        return 4  # Modern growth
    elif year < 2020:
        return 5  # Great Recession recovery
    else:
        return 6  # COVID era

stata_df['econ_era'] = stata_df['year'].apply(categorize_era)

# Unemployment category (ordinal)
def unemp_category(rate):
    if pd.isna(rate):
        return np.nan
    elif rate < 4.0:
        return 1  # Low
    elif rate < 6.0:
        return 2  # Moderate
    elif rate < 8.0:
        return 3  # High
    else:
        return 4  # Very High

stata_df['unemp_cat'] = stata_df['unemp_rate'].apply(unemp_category)

print(f"Created annual dataset with {len(stata_df)} observations from {stata_df['year'].min()} to {stata_df['year'].max()}")
print(f"Variables: {list(stata_df.columns)}")

# Write to Stata format
output_file = "PetersDraft.dta"
print(f"Writing to {output_file}...")

stata_df.to_stata(
    output_file,
    write_index=False,
    version=118,  # Stata 14/15/16/17 format
    variable_labels={
        'year': 'Year',
        'unemp_rate': 'Unemployment Rate (%, December)',
        'lfpr': 'Labor Force Participation Rate (%, December)',
        'med_income': 'Real Median Household Income (2024 dollars)',
        'gini': 'Gini Index of Income Inequality',
        'pce_capita': 'Real Personal Consumption Expenditure per Capita (dollars)',
        'life_expect': 'Life Expectancy at Birth (years)',
        'poverty_rate': 'Official Poverty Rate (%, all people)',
        'decade': 'Decade',
        'econ_era': 'Economic Era',
        'unemp_cat': 'Unemployment Category'
    },
    convert_dates={},  # Don't convert year to Stata date format
)

print(f"Successfully created {output_file}")
print("\nVariable summary:")
print(stata_df.describe())
