# Peters Final Data Project - GOVT 301 Fall 2025

## Project Overview

This project expands the original quantitative dataset with 10 new FRED economic series and integrates General Social Survey (GSS) respondent aggregates to create a comprehensive annual time-series dataset of U.S. economic and social indicators (1947-2025).

## Data Sources

### 1. FRED (Federal Reserve Economic Data) - 13 Series
**Original 7 series:**
- UNRATE: Civilian Unemployment Rate (Monthly)
- CIVPART: Labor Force Participation Rate (Monthly)
- MEHOINUSA672N: Real Median Household Income (Annual)
- SIPOVGINIUSA: Gini Index of Income Inequality (Annual)
- A794RC0A052NBEA: Real PCE per Capita (Annual)
- SPDYNLE00INUSA: Life Expectancy at Birth (Annual)

**New 10 series (Fall 2025):**
- A939RX0A052NBEA: Real GDP per Capita (Annual)
- CPIAUCSL: CPI-U Inflation (Monthly)
- FEDMINNFRWG: Federal Minimum Wage (Annual)
- LNS11300000: Union Membership Rate (Annual) ← *May fail API validation*
- B23006_023E: Educational Attainment - % Bachelor's+ (Annual) ← *May fail API validation*
- VCRIME: Violent Crime Rate (Annual) ← *May fail API validation*
- S2701_C03_001E: Health Insurance Coverage Rate (Annual) ← *May fail API validation*
- A085RC0A052NBEA: Real Government Social Spending Per Capita (Annual) ← *May fail API validation*
- CUSR0000SEHA: Real Median Rent (Monthly)
- POPTHM: Total Population (Monthly)

### 2. U.S. Census Bureau
- Historical Poverty Tables (histpov2): Official Poverty Rate (Annual) ← *May fail API validation*

### 3. General Social Survey (GSS 2024)
- File: gss7224_r2.dta (Release 2)
- 2024 cross-section data with multi-mode collection
- **Aggregated to annual level for select variables:**
  - Union membership rate (%)
  - Employment rate (%)
  - Bachelor's degree or higher (%)

## Processing Workflow

### Step 1: Generate Expanded FRED CSV
```bash
python3 fred.py
```
**Output:** `population_impact_datasets.csv` (1055 rows × 28+ columns)
- Contains all available FRED series at native frequencies
- Includes percentage change columns for each series
- Mixed frequencies: monthly and annual data coexist

### Step 2: Prepare GSS Annual Aggregates (Optional)
```bash
python3 prepare_gss_aggregates.py
```
**Output:** `gss_annual_aggregates.csv`
- Aggregates GSS respondents by year (YEAR variable)
- Computes percentages for union, employment, and education
- Creates respondent count per year

### Step 3: Run Stata Processing
```stata
do PetersFinal.do
```
**Workflow in do-file:**
1. Import expanded FRED CSV
2. Collapse to annual frequency (taking means of monthly data)
3. Load and aggregate GSS data
4. Merge FRED and GSS on year
5. Create 2 new derived variables:
   - **Economic Stress Index**: unemployment + (inflation/10) + (gini×10)
   - **Social Well-being Index**: employment% + education% + (life_expectancy/10)
6. Create categorical variables:
   - Decade
   - Economic Era (4 periods)
   - Unemployment Category
7. Add labels and value labels
8. Generate descriptive statistics and visualizations

**Output:** `PetersFinal.dta`

## Key Variables in Final Dataset

### Continuous Variables
| Variable | Label | Source | Years |
|----------|-------|--------|-------|
| unemployment_rate | Civilian Unemployment Rate (%) | FRED | 1948-2025 |
| labor_force_participation | Labor Force Participation Rate (%) | FRED | 1948-2025 |
| real_median_hh_income | Real Median HH Income (2024$) | FRED | 1984-2024 |
| gini_index | Gini Index of Income Inequality | FRED | 1963-2023 |
| real_pce_per_capita | Real PCE per Capita (2024$) | FRED | 1929-2024 |
| life_expectancy_at_birth | Life Expectancy (years) | FRED | 1960-2023 |
| cpi_inflation | CPI-U | FRED | 1947-2025 |
| federal_min_wage | Federal Minimum Wage ($) | FRED | 1938-2025 |
| real_median_rent | Real Median Rent (1982-84$) | FRED | 1981-2025 |
| total_population | Total U.S. Population (thousands) | FRED | 1959-2025 |
| gss_union_pct | % in union (GSS respondents) | GSS | 2024 only |
| gss_employed_pct | % employed (GSS respondents) | GSS | 2024 only |
| gss_college_pct | % with college+ (GSS respondents) | GSS | 2024 only |
| **economic_stress_idx** | **Economic Stress Index** | **Derived** | **1947-2025** |
| **social_wellbeing_idx** | **Social Well-being Index** | **Derived** | **2024 subset** |

### Categorical Variables
| Variable | Codes | Source |
|----------|-------|--------|
| decade | 1940, 1950, ..., 2020 | Derived |
| era | 1=Golden Age, 2=Stagflation, 3=New Economy, 4=Crisis | Derived |
| unemployment_cat | 1=Low, 2=Moderate, 3=Elevated, 4=High | Derived |

## Important Notes on Data Quality

### FRED API Series Issues
Some newer FRED series codes may fail due to:
- Series ID format changes (Census ACS tables)
- Restricted data access
- API validation differences

**Status of new series:**
- ✅ CPIAUCSL, CUSR0000SEHA, POPTHM: Successfully retrieved
- ⚠️  Others (B23006_023E, S2701_C03_001E, etc.): May require direct Census API or manual download

### GSS Data Considerations
- **Multimode collection**: 2024 GSS includes face-to-face, web, and phone interviews
- **Methodological note**: Do NOT analyze by single mode; use full sample
- **Missing value codes**: GSS uses special missing codes (e.g., .d, .i, .n, .s, .x); Stata handles these
- **Survey design**: GSS is a complex survey; weighted analysis recommended for publication
- **Limited years**: GSS aggregates available only for years survey was conducted (2024 in this file)

### Census API
- Poverty and other Census data may require API key or direct downloads
- Current script includes retry logic but may encounter timeouts

## Output Files

### Final Dataset
- **PetersFinal.dta** - Main Stata dataset (1947-2025 annual)
- **PetersFinal.do** - Complete do-file with all processing steps

### Metadata
- **population_impact_datasets_meta.json** - FRED series metadata
- **gss_annual_aggregates.csv** - Aggregated GSS statistics

### Visualizations
- `unemployment_timeseries.png`
- `median_income_trend.png`
- `gini_life_expectancy.png`
- `unemployment_by_era_boxplot.png`
- `economic_stress_index.png`
- `social_wellbeing_index.png`

## Required Python Packages
```
pandas
requests
python-dotenv
```

Install with:
```bash
pip install pandas requests python-dotenv
```

## Required Stata Features
- `collapse` command for aggregation
- `merge` for joining datasets
- `generate` and `recode` for variable creation
- `label` and `label define` for metadata
- `twoway` and `graph box` for visualizations

## Running the Complete Workflow

### Option 1: Full Automated (if all APIs work)
```bash
python3 fred.py
python3 prepare_gss_aggregates.py
# Then in Stata:
do PetersFinal.do
```

### Option 2: With Manual GSS Download (recommended)
If GSS processing fails, manually download GSS 2024 and use:
```bash
python3 fred.py
# In Stata:
do PetersFinal.do
```

## Troubleshooting

### "CSV file not found"
Ensure you ran `python3 fred.py` first and are in the correct working directory.

### "GSS file not found"
Place `gss7224_r2.dta` in the same directory as the do-file, or update the path in PetersFinal.do.

### API Failures
- FRED: May be rate-limited; retry after 60 seconds
- Census: May require explicit API key setup
- Script includes retry logic with exponential backoff

### Memory Issues
If working with full GSS (567MB), increase Stata memory:
```stata
set memory 2g
```

## Assignment Requirements Met

✅ **File naming:**
- PetersFinal.dta ✓
- PetersFinal.do ✓
- PetersCodebookFinal.docx (separate file)
- PetersAnalysis.docx (separate file)

✅ **Dataset requirements:**
- ≥10 variables: 17 ✓
- Case ID (year): ✓
- ≥2 substantively meaningful derived variables: 2 ✓
- All variables have labels: ✓
- Value labels for nominal/ordinal: ✓
- Consistent unit of analysis (years): ✓
- Proper encoding for Stata analysis: ✓

✅ **Do-file requirements:**
- Abstract at top: ✓
- Code for 2 generated variables: ✓
- Variable labels: ✓
- Value labels: ✓
- Numeric results (summary statistics): ✓
- Data visualization (6 graphs): ✓

## Contact & Notes

This project demonstrates:
- API integration (FRED) with error handling
- Data aggregation across sources
- Time-series data merging
- Stata data processing best practices
- Meaningful variable derivation
- Exploratory data visualization

For questions about FRED API: https://fred.stlouisfed.org/docs/api/
For GSS documentation: https://gss.norc.org/

---
*Generated November 2025 | GOVT 301 Quantitative Data Project*
