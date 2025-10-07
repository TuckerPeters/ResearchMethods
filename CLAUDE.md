# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SimpleFred is a Python data collection tool that fetches economic and population impact datasets from FRED (Federal Reserve Economic Data) API and U.S. Census Bureau, merges them at their native frequencies, and outputs a unified CSV file with metadata. This is an academic project for a Stata data analysis course (GOVT 301).

## Key Commands

### Running the Data Collection Script
```bash
python3 fred.py
```

### Setting Up the Environment
```bash
# Create virtual environment (if needed)
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # On macOS/Linux
# venv\Scripts\activate   # On Windows

# Install dependencies
pip install requests pandas python-dotenv
```

### FRED API Key Configuration
The script requires a FRED API key. Set it via:
- Environment variable: `export FRED_API_KEY=your_key_here`
- Or create a `.env` file with: `FRED_API_KEY=your_key_here`
- Falls back to hardcoded key if not set (present in code)

## Architecture

### Main Script: fred.py

**Core Functionality:**
- Fetches 7 population-impact economic datasets from FRED and Census APIs
- Performs outer join merge on dates, preserving each series' native frequency
- Outputs CSV with percentage change columns for all time series
- Generates metadata JSON sidecar with series information

**Data Sources (Series IDs):**
1. UNRATE - Civilian Unemployment Rate (Monthly)
2. CIVPART - Labor Force Participation Rate (Monthly)
3. MEHOINUSA672N - Real Median Household Income (Annual)
4. SIPOVGINIUSA - Gini Index of Income Inequality (Annual)
5. A794RC0A052NBEA - Real PCE per Capita (Annual)
6. SPDYNLE00INUSA - Life Expectancy at Birth (Annual, World Bank via FRED)
7. Census histpov2 - Official Poverty Rate (Annual, from Census API)

**Key Functions:**
- `fred_series_metadata(series_id)` - Fetches FRED series metadata
- `fred_series_df(series_id, col_name)` - Returns DataFrame and metadata for a FRED series
- `census_poverty_rate_df()` - Fetches Census poverty data with retry logic
- `build_and_save_csv()` - Main orchestration function that fetches all series, merges, calculates percentage changes, and writes outputs

**Output Files:**
- `population_impact_datasets.csv` - Merged dataset with columns for each series and their percentage changes
- `population_impact_datasets_meta.json` - Metadata including frequencies, date ranges, units, and notes

**Data Processing:**
- Outer join preserves different frequencies (monthly vs annual)
- Missing values (NA) appear between lower-frequency observations
- Percentage change calculated using pandas `pct_change()` on each series
- All dates formatted as YYYY-MM-DD strings

**Error Handling:**
- HTTP requests include retry logic (MAX_RETRIES=3, exponential backoff)
- Census API failures handled gracefully (returns empty DataFrame)
- Missing or malformed values converted to NaN

### Academic Context

This codebase supports a Stata data analysis assignment (see assignment.txt). The Python script generates the base dataset, which is then imported into Stata for:
- Variable labeling and value labeling
- Descriptive statistics and tabulations
- Data visualization
- Codebook generation

The .do file templates in the repository show the expected Stata workflow structure.

## Dependencies

**Python:** 3.12+ (tested with 3.13.7)

**Required packages:**
- `requests` - HTTP API calls to FRED and Census
- `pandas` - Data manipulation and merging
- `python-dotenv` - Optional .env file loading for API key

**Standard library:**
- `os`, `sys`, `csv`, `json`, `time`, `math`, `logging`, `datetime`, `typing`

## Notes

- The script does NOT resample frequencies - it preserves native granularity
- FRED API timeout is 25 seconds per request
- Census poverty API can be brittle; failures are non-fatal
- The script is designed as a one-time data pull, not for continuous monitoring
- Hardcoded API key is present as fallback (consider security implications for production use)
