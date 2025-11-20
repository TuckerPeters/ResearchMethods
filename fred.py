#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
population_impact_datasets.py

Pulls 17 population-impact datasets and writes a single, merged CSV at each series'
native (maximum available) frequency. It does NOT resample; merge is an outer join
on the date index, so lower-frequency series will have NA between observations.

Datasets (source → series_id / endpoint):
  1) FRED: Civilian Unemployment Rate (UNRATE)                [Monthly]
  2) FRED: Labor Force Participation Rate (CIVPART)           [Monthly]
  3) FRED: Real Median Household Income (MEHOINUSA672N)       [Annual]
  4) FRED: Gini Index of Income Inequality (SIPOVGINIUSA)     [Annual]
  5) FRED: Real PCE per Capita (A794RC0A052NBEA)              [Annual]
  6) U.S. Census: Official Poverty Rate (Historical – histpov2)[Annual]
  7) Life Expectancy at Birth (proxy via World Bank on FRED)   [Annual]
     FRED composite code: SPDYNLE00INUSA (USA life expectancy)
  8) FRED: Real GDP per Capita (A939RX0A052NBEA)              [Annual]
  9) FRED: Inflation - CPI-U (CPIAUCSL)                       [Monthly]
 10) FRED: Federal Minimum Wage (FEDMINNFRWG)                 [Annual]
 11) FRED: Union Membership Rate (LNS11300000)                [Annual]
 12) FRED: Educational Attainment - % Bachelor's+ (B23006_023E) [Annual]
 13) FRED: Violent Crime Rate (VCRIME)                        [Annual]
 14) FRED: Health Insurance Coverage Rate (S2701_C03_001E)     [Annual]
 15) FRED: Real Government Social Spending Per Capita (A085RC0A052NBEA) [Annual]
 16) FRED: Real Median Rent (CUSR0000SEHA)                    [Monthly]
 17) FRED: Total Population (POPTHM)                          [Monthly]

Notes:
- FRED API key is read from the environment variable FRED_API_KEY.
  If absent, falls back to your known key: d8ba72083bb7547c67856b5acb8b6be9
- If a .env file is present, it will be loaded automatically (python-dotenv).
- The Census poverty endpoint can be brittle; failures are handled gracefully.
- Output CSV: ./population_impact_datasets.csv
- A sidecar JSON file ./population_impact_datasets_meta.json records series metadata,
  including detected frequency and date coverage.

Python: 3.12+
"""

import os
import sys
import csv
import json
import time
import math
import logging
from typing import Dict, List, Optional, Tuple

from datetime import datetime
import requests
import pandas as pd

# Attempt to load .env if present
try:
    from dotenv import load_dotenv  # type: ignore
    load_dotenv()
except Exception:
    pass

# -----------------------
# Config & Logging
# -----------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

FRED_API_KEY = os.getenv("FRED_API_KEY", "d8ba72083bb7547c67856b5acb8b6be9")

FRED_OBS_URL = "https://api.stlouisfed.org/fred/series/observations"
FRED_SERIES_URL = "https://api.stlouisfed.org/fred/series"

OUTPUT_CSV = "./population_impact_datasets.csv"
OUTPUT_DTA = "./population_impact_datasets.dta"
OUTPUT_META_JSON = "./population_impact_datasets_meta.json"

REQ_TIMEOUT = 25  # seconds
MAX_RETRIES = 3
RETRY_SLEEP = 1.5  # seconds


# -----------------------
# HTTP helper
# -----------------------

def _http_get_json(url: str, params: Dict[str, str]) -> Optional[dict]:
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            r = requests.get(url, params=params, timeout=REQ_TIMEOUT)
            r.raise_for_status()
            return r.json()
        except Exception as e:
            logging.warning(f"[retry {attempt}/{MAX_RETRIES}] GET {url} failed: {e}")
            if attempt < MAX_RETRIES:
                time.sleep(RETRY_SLEEP * attempt)
    return None


# -----------------------
# FRED helpers
# -----------------------

def fred_series_metadata(series_id: str) -> Optional[dict]:
    """
    Fetch series metadata from FRED. Returns the first item from 'seriess' or None.
    Includes fields like 'frequency', 'frequency_short', 'observation_start', 'observation_end'.
    """
    params = {
        "series_id": series_id,
        "api_key": FRED_API_KEY,
        "file_type": "json",
    }
    js = _http_get_json(FRED_SERIES_URL, params)
    if not js or "seriess" not in js or not js["seriess"]:
        logging.warning(f"No metadata returned for {series_id}")
        return None
    return js["seriess"][0]


def fred_series_df(series_id: str, col_name: Optional[str] = None) -> Tuple[pd.DataFrame, dict]:
    """
    Fetch a FRED series at full available history (no start/end limits).
    Returns (df, meta), where:
      df -> columns ['date', col_name], dates as YYYY-MM-DD
      meta -> {'series_id', 'frequency', 'frequency_short', 'observation_start', 'observation_end'}
    """
    if not col_name:
        col_name = series_id

    meta_raw = fred_series_metadata(series_id) or {}
    meta = {
        "series_id": series_id,
        "frequency": meta_raw.get("frequency"),
        "frequency_short": meta_raw.get("frequency_short"),
        "observation_start": meta_raw.get("observation_start"),
        "observation_end": meta_raw.get("observation_end"),
        "title": meta_raw.get("title"),
        "units": meta_raw.get("units"),
        "seasonal_adjustment": meta_raw.get("seasonal_adjustment"),
        "notes": meta_raw.get("notes"),
    }

    params = {
        "series_id": series_id,
        "api_key": FRED_API_KEY,
        "file_type": "json",
        # Intentionally no observation_start/end to get full series
    }
    js = _http_get_json(FRED_OBS_URL, params)
    if js is None or "observations" not in js:
        logging.error(f"FRED observations fetch failed for {series_id}")
        return pd.DataFrame(columns=["date", col_name]), meta

    rows = []
    for obs in js["observations"]:
        d = obs.get("date")
        v = obs.get("value")
        if d is None:
            continue
        try:
            val = float(v) if v not in (None, ".", "") else math.nan
        except Exception:
            val = math.nan
        rows.append((d, val))

    df = pd.DataFrame(rows, columns=["date", col_name])
    df["date"] = pd.to_datetime(df["date"], errors="coerce").dt.strftime("%Y-%m-%d")
    return df, meta


# -----------------------
# GSS data extraction and aggregation
# -----------------------

def gss_aggregate_by_year(gss_dta_path: str) -> Tuple[pd.DataFrame, dict]:
    """
    Load GSS data and aggregate key social variables to annual level.
    Extracts: union membership, employment status, educational attainment.

    Returns (df, meta) where:
      df -> columns ['year', 'gss_union_pct', 'gss_work_pct', 'gss_college_pct']
      meta -> metadata about the GSS dataset
    """
    try:
        logging.info(f"Loading GSS data from {gss_dta_path}...")
        gss = pd.read_stata(gss_dta_path, convert_categoricals=False)
        logging.info(f"GSS loaded: {gss.shape[0]} respondents, {gss.shape[1]} variables")

        # Identify year variable (might be 'year' or 'YEAR')
        year_col = None
        for candidate in ['year', 'YEAR', 'Year']:
            if candidate in gss.columns:
                year_col = candidate
                break

        if year_col is None:
            raise ValueError("No 'year' or 'YEAR' column found in GSS data")

        # Create binary flags for aggregation
        gss['in_union'] = (gss.get('union') == 1).astype(float)  # Union membership
        gss['working'] = (gss.get('wrkstat') == 1).astype(float)  # Employed
        gss['college'] = (gss.get('degree', 0) >= 3).astype(float)  # College degree+

        # Aggregate to annual level
        agg_dict = {
            'in_union': 'mean',
            'working': 'mean',
            'college': 'mean',
        }

        gss_annual = gss.groupby(year_col)[['in_union', 'working', 'college']].agg(agg_dict).reset_index()
        gss_annual.rename(columns={year_col: 'year'}, inplace=True)

        # Convert to percentages and rename
        gss_annual['gss_union_pct'] = gss_annual['in_union'] * 100
        gss_annual['gss_work_pct'] = gss_annual['working'] * 100
        gss_annual['gss_college_pct'] = gss_annual['college'] * 100

        # Keep only year and percentage columns
        gss_annual = gss_annual[['year', 'gss_union_pct', 'gss_work_pct', 'gss_college_pct']]
        gss_annual['year'] = gss_annual['year'].astype(int)

        meta = {
            "series_id": "GSS_AGGREGATED",
            "frequency": "Annual",
            "frequency_short": "A",
            "observation_start": str(int(gss_annual['year'].min())),
            "observation_end": str(int(gss_annual['year'].max())),
            "title": "General Social Survey - Aggregated Indicators",
            "units": "Percent (%)",
            "seasonal_adjustment": "Not Seasonally Adjusted",
            "notes": "Aggregated from individual respondent-level GSS data. Union: % members; Working: % employed; College: % with bachelor's degree or higher.",
        }

        logging.info(f"GSS aggregated to {len(gss_annual)} years: {meta['observation_start']} → {meta['observation_end']}")
        return gss_annual, meta

    except FileNotFoundError:
        logging.warning(f"GSS file not found at {gss_dta_path}. Skipping GSS data.")
        return pd.DataFrame(columns=['year', 'gss_union_pct', 'gss_work_pct', 'gss_college_pct']), {
            "series_id": "GSS_AGGREGATED",
            "frequency": "Annual",
            "frequency_short": "A",
            "observation_start": None,
            "observation_end": None,
            "title": "General Social Survey - Aggregated Indicators (NOT LOADED)",
            "units": "Percent (%)",
            "notes": "GSS file not found. Skipped."
        }
    except Exception as e:
        logging.error(f"Error loading/aggregating GSS data: {e}")
        return pd.DataFrame(columns=['year', 'gss_union_pct', 'gss_work_pct', 'gss_college_pct']), {
            "series_id": "GSS_AGGREGATED",
            "notes": f"Error: {str(e)}"
        }


# -----------------------
# Census poverty
# -----------------------

def census_poverty_rate_df() -> Tuple[pd.DataFrame, dict]:
    """
    Fetch official poverty rate time series from Census 'histpov2' (Historical Poverty Tables).
    API (best-effort):
      https://api.census.gov/data/timeseries/poverty/histpov2?get=YEAR,AGE,POV_RATE&time=from+1959+to+2024

    Filter for "All people" (AGE variants: "All people", "All People", "0").
    Returns (df, meta), df columns: ['date', 'POVERTY_RATE_OFFICIAL'], annual 12-31 dating.
    """
    url = "https://api.census.gov/data/timeseries/poverty/histpov2"
    params = {
        "get": "YEAR,AGE,POV_RATE",
        "time": "from+1959+to+2024",
    }

    meta = {
        "series_id": "CENSUS_HISTPOV2_POV_RATE_ALL_PEOPLE",
        "frequency": "Annual",
        "frequency_short": "A",
        "observation_start": None,
        "observation_end": None,
        "title": "Official Poverty Rate (All People)",
        "units": "Percent",
        "seasonal_adjustment": "Not Seasonally Adjusted",
        "notes": "U.S. Census Historical Poverty Tables (histpov2); filtered for 'All people'.",
    }

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            r = requests.get(url, params=params, timeout=REQ_TIMEOUT)
            r.raise_for_status()
            js = r.json()
            header = js[0]
            rows = js[1:]

            idx_year = header.index("YEAR") if "YEAR" in header else None
            idx_age = header.index("AGE") if "AGE" in header else None
            idx_rate = header.index("POV_RATE") if "POV_RATE" in header else None
            if None in (idx_year, idx_age, idx_rate):
                raise ValueError("Census poverty: unexpected columns")

            KEEP_AGE = {"All people", "All People", "0"}
            recs = []
            years = []
            for rrow in rows:
                yr = str(rrow[idx_year]).strip()
                age = str(rrow[idx_age]).strip()
                rate = rrow[idx_rate]
                if age not in KEEP_AGE:
                    continue
                try:
                    val = float(rate)
                except Exception:
                    val = math.nan
                dt = f"{yr}-12-31"
                recs.append((dt, val))
                years.append(yr)

            if not recs:
                raise ValueError("Census poverty: no 'All people' rows matched")

            df = pd.DataFrame(recs, columns=["date", "POVERTY_RATE_OFFICIAL"])
            df = df.drop_duplicates(subset=["date"]).sort_values("date")
            if years:
                meta["observation_start"] = f"{min(years)}-12-31"
                meta["observation_end"] = f"{max(years)}-12-31"
            return df, meta
        except Exception as e:
            logging.warning(f"[retry {attempt}/{MAX_RETRIES}] Census poverty fetch failed: {e}")
            if attempt < MAX_RETRIES:
                time.sleep(RETRY_SLEEP * attempt)

    logging.error("Census poverty API unreachable or schema unexpected; skipping poverty series.")
    return pd.DataFrame(columns=["date", "POVERTY_RATE_OFFICIAL"]), meta


# -----------------------
# Main build
# -----------------------

def build_and_save_csv(output_path: str = OUTPUT_CSV, meta_out: str = OUTPUT_META_JSON, gss_dta_path: str = "gss7224_r2.dta") -> None:
    """
    Fetch all series at their native highest frequency, outer-join on 'date', and write CSV.
    Also merges GSS aggregated social indicators by year.
    Writes a JSON sidecar with metadata and detected frequencies.
    """
    logging.info("Starting dataset collection...")

    fred_specs: List[Dict[str, str]] = [
        # Original 7 series
        {"id": "UNRATE",            "col": "UNEMPLOYMENT_RATE"},
        {"id": "CIVPART",           "col": "LABOR_FORCE_PARTICIPATION"},
        {"id": "MEHOINUSA672N",     "col": "REAL_MEDIAN_HH_INCOME"},
        {"id": "SIPOVGINIUSA",      "col": "GINI_INDEX"},
        {"id": "A794RC0A052NBEA",   "col": "REAL_PCE_PER_CAPITA"},
        {"id": "SPDYNLE00INUSA",    "col": "LIFE_EXPECTANCY_AT_BIRTH"},  # World Bank via FRED
        # New 10 series (Fall 2025)
        {"id": "A939RX0A052NBEA",   "col": "REAL_GDP_PER_CAPITA"},
        {"id": "CPIAUCSL",          "col": "CPI_INFLATION"},
        {"id": "FEDMINNFRWG",       "col": "FEDERAL_MIN_WAGE"},
        {"id": "LNS11300000",       "col": "UNION_MEMBERSHIP_RATE"},
        {"id": "B23006_023E",       "col": "EDUCATION_BACHELORS_PLUS"},
        {"id": "VCRIME",            "col": "VIOLENT_CRIME_RATE"},
        {"id": "S2701_C03_001E",    "col": "HEALTH_INSURANCE_COVERAGE"},
        {"id": "A085RC0A052NBEA",   "col": "GOVT_SOCIAL_SPENDING_PER_CAP"},
        {"id": "CUSR0000SEHA",      "col": "REAL_MEDIAN_RENT"},
        {"id": "POPTHM",            "col": "TOTAL_POPULATION"},
    ]

    dfs: List[pd.DataFrame] = []
    meta_list: List[dict] = []

    # Fetch FRED series at full history + collect metadata/frequency
    for i, spec in enumerate(fred_specs, start=1):
        sid = spec["id"]
        col = spec["col"]
        logging.info(f"[{i}/{len(fred_specs)}] Fetching FRED {sid} → {col}")
        df, meta = fred_series_df(sid, col)
        if df.empty:
            logging.error(f"Empty DataFrame for {sid} ({col}).")
        dfs.append(df)
        meta_list.append(meta)
        logging.info(
            f"  • {sid} frequency: {meta.get('frequency')} ({meta.get('frequency_short')}); "
            f"range: {meta.get('observation_start')} → {meta.get('observation_end')}"
        )

    # Fetch Census poverty (annual)
    logging.info(f"[{len(fred_specs)+1}/{len(fred_specs)+1}] Fetching Census Official Poverty Rate")
    census_df, census_meta = census_poverty_rate_df()
    dfs.append(census_df)
    meta_list.append(census_meta)
    logging.info(
        f"  • Census Poverty frequency: {census_meta.get('frequency')} "
        f"({census_meta.get('frequency_short')}); range: "
        f"{census_meta.get('observation_start')} → {census_meta.get('observation_end')}"
    )

    # Fetch GSS aggregated data (annual)
    logging.info(f"[{len(fred_specs)+2}/{len(fred_specs)+2}] Loading and aggregating GSS data")
    gss_df, gss_meta = gss_aggregate_by_year(gss_dta_path)
    if not gss_df.empty:
        dfs.append(gss_df)
        meta_list.append(gss_meta)
        logging.info(
            f"  • GSS frequency: {gss_meta.get('frequency')} "
            f"({gss_meta.get('frequency_short')}); range: "
            f"{gss_meta.get('observation_start')} → {gss_meta.get('observation_end')}"
        )
    else:
        logging.warning("GSS data not available; continuing with FRED and Census data only.")

    # Merge FRED/Census data on date; then merge GSS data on year
    logging.info("Merging date-based datasets (FRED/Census) on 'date' (outer join)…")

    # Separate GSS data from FRED/Census data
    gss_included = False
    gss_data = None
    fred_census_dfs = []

    for d in dfs:
        if 'year' in d.columns and 'date' not in d.columns:
            gss_data = d
            gss_included = True
        else:
            fred_census_dfs.append(d)

    # Merge FRED/Census datasets on date
    merged = None
    for d in fred_census_dfs:
        if merged is None:
            merged = d
        else:
            merged = pd.merge(merged, d, on="date", how="outer")

    if merged is None or merged.empty:
        logging.error("No FRED/Census data fetched; nothing to write.")
        sys.exit(2)

    # Extract year from date and merge with GSS data
    merged["date"] = pd.to_datetime(merged["date"], errors="coerce")
    merged["year"] = merged["date"].dt.year.astype("Int64")  # Use nullable integer type
    merged = merged.sort_values("date").reset_index(drop=True)
    merged["date"] = merged["date"].dt.strftime("%Y-%m-%d")

    # Merge with GSS data on year if available
    if gss_included and gss_data is not None and not gss_data.empty:
        logging.info("Merging GSS aggregated data on 'year'…")
        gss_data["year"] = gss_data["year"].astype("Int64")
        merged = pd.merge(merged, gss_data, on="year", how="left")

    # Add percentage change columns for each series
    logging.info("Calculating percentage changes for each series…")
    value_columns = [col for col in merged.columns if col not in ("date", "year")]

    for col in value_columns:
        pct_col = f"{col}_PCT_CHANGE"
        # Calculate percent change from previous non-null value
        # This handles different frequencies (monthly vs annual) automatically
        pct_change = merged[col].pct_change() * 100
        # Replace infinity values with NaN (these occur when previous value was 0)
        pct_change = pct_change.replace([float('inf'), float('-inf')], float('nan'))
        merged[pct_col] = pct_change

    # Reorder columns: date, year, then pairs of (value, pct_change) for each series
    column_order = ["date", "year"]
    for col in value_columns:
        column_order.append(col)
        column_order.append(f"{col}_PCT_CHANGE")
    merged = merged[column_order]

    # Write CSV
    logging.info(f"Writing CSV → {output_path}")
    merged.to_csv(output_path, index=False, quoting=csv.QUOTE_MINIMAL)

    # Prepare for Stata export: drop completely empty columns
    merged_for_stata = merged.dropna(axis=1, how='all')
    logging.info(f"Dropped {len(merged.columns) - len(merged_for_stata.columns)} completely empty columns")

    # Write Stata .dta file
    logging.info(f"Writing Stata .dta → {OUTPUT_DTA}")
    merged_for_stata.to_stata(OUTPUT_DTA, write_index=False)

    # Write metadata sidecar
    logging.info(f"Writing metadata JSON → {meta_out}")
    with open(meta_out, "w", encoding="utf-8") as f:
        json.dump(
            {
                "generated_at": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
                "series_metadata": meta_list,
                "notes": (
                    "Frequencies are as reported by FRED metadata or defined for Census. "
                    "Merged CSV preserves native frequencies; expect NA between lower-frequency "
                    "observations. Consider aligning to a common frequency in downstream analysis. "
                    "Each series has a corresponding _PCT_CHANGE column showing the percentage change "
                    "from the previous available observation, automatically handling different reporting "
                    "frequencies (e.g., monthly vs. annual)."
                ),
            },
            f,
            ensure_ascii=False,
            indent=2,
        )

    logging.info("Done.")


# -----------------------
# Entrypoint
# -----------------------

if __name__ == "__main__":
    try:
        if not FRED_API_KEY or not FRED_API_KEY.strip():
            logging.error("FRED_API_KEY not set. Export FRED_API_KEY or provide it in a .env file.")
            sys.exit(1)

        build_and_save_csv(OUTPUT_CSV, OUTPUT_META_JSON)
    except KeyboardInterrupt:
        logging.error("Interrupted by user.")
        sys.exit(130)
    except Exception as e:
        logging.exception(f"Fatal error: {e}")
        sys.exit(1)
