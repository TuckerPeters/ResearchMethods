/*===============================================================================
* File:     PetersFinal.do
* Author:   Tucker Peters
* Date:     November 2025
* Purpose:  Final analysis of U.S. Economic and Social Indicators (1947-2025)
*           with expanded FRED series and GSS survey data aggregates
*
* Description:
*   This do-file processes an expanded time-series dataset containing annual
*   observations of key economic and social indicators. Data sources include:
*   - FRED (Federal Reserve Economic Data): 13 series
*   - U.S. Census Bureau: Poverty rate
*   - General Social Survey (GSS 2024): Annual aggregates of select variables
*
*   The dataset spans 1947-2025 with variables including unemployment, inflation,
*   income inequality, government spending, educational attainment, and social
*   attitudes (aggregated from GSS respondents).
*
* Input:    population_impact_datasets.csv, gss7224_r2.dta
* Output:   PetersFinal.dta, descriptive statistics, visualizations
===============================================================================*/

clear all
set more off

* Set working directory (adjust path as needed)
* cd "/path/to/your/files"

/*===============================================================================
* PART 1: IMPORT AND PREPARE EXPANDED FRED CSV DATA
===============================================================================*/

display _newline(2)
display "================================================================================"
display "PART 1: IMPORTING AND PREPARING FRED DATA"
display "================================================================================"

* Import the expanded CSV file with 13+ FRED series
insheet using "population_impact_datasets.csv", clear comma

* Convert date string to Stata date
generate year_date = date(date, "YMD")
format year_date %td
generate year = year(year_date)

* For annual analysis, keep only year-end (December 31st) observations
* This ensures we have one observation per year per series
keep if month(year_date) == 12 | (month(year_date) == 1 & year == year[_n+1] - 1)

* Actually, let's just aggregate to annual: keep unique year values
* For mixed frequencies, collapse to annual means
collapse (mean) unemployment_rate labor_force_participation real_median_hh_income ///
         gini_index real_pce_per_capita life_expectancy_at_birth ///
         cpi_inflation federal_min_wage real_median_rent total_population, by(year)

describe
summarize year

display "FRED data prepared: `=_N' annual observations"

/*===============================================================================
* PART 2: PREPARE GSS AGGREGATES BY YEAR
===============================================================================*/

display _newline(2)
display "================================================================================"
display "PART 2: PREPARING GSS DATA - AGGREGATING BY YEAR"
display "================================================================================"

* Temporarily save current dataset
tempfile fred_data
save `fred_data'

* Load GSS data
use "gss7224_r2.dta", clear

* Identify year variable
capture describe year
if _rc == 0 {
    display "YEAR variable found in GSS"
} else {
    display "Looking for year-related variable..."
    capture describe YEAR
    if _rc == 0 {
        display "YEAR (uppercase) found"
        rename YEAR year
    }
}

* Create flags for respondents with non-missing key variables
* Union membership: indicator for being in union
generate union_flag = (union == 1) if !missing(union)

* Employment: 1 if working, 0 otherwise
generate employed_flag = (wrkstat == 1) if !missing(wrkstat)

* Bachelor's degree or higher: 1 if DEGREE >= 3, 0 otherwise
* (assume 3=bachelors, 4=graduate)
generate college_educated_flag = (degree >= 3) if !missing(degree)

* Aggregate to annual level
collapse (mean) union_flag employed_flag college_educated_flag ///
         (count) resp_count = union_flag, by(year)

* Rename aggregated variables for clarity
rename union_flag gss_union_pct
rename employed_flag gss_employed_pct
rename college_educated_flag gss_college_pct

* Scale percentages to 0-100 range
foreach var of varlist gss_union_pct gss_employed_pct gss_college_pct {
    replace `var' = `var' * 100 if !missing(`var')
}

label variable gss_union_pct "% respondents in union (GSS annual)"
label variable gss_employed_pct "% respondents employed (GSS annual)"
label variable gss_college_pct "% respondents with college+ degree (GSS annual)"

tempfile gss_data
save `gss_data'

display "GSS data aggregated: `=_N' annual observations with averages"

/*===============================================================================
* PART 3: MERGE FRED AND GSS DATA
===============================================================================*/

display _newline(2)
display "================================================================================"
display "PART 3: MERGING FRED AND GSS DATASETS"
display "================================================================================"

use `fred_data', clear

merge 1:1 year using `gss_data', generate(merge_status)
* merge_status: 1=Fred only, 2=GSS only, 3=both

describe merge_status
tabulate merge_status

/*===============================================================================
* PART 4: CREATE NEW DERIVED VARIABLES
===============================================================================*/

display _newline(2)
display "================================================================================"
display "PART 4: CREATING DERIVED VARIABLES"
display "================================================================================"

* Variable 1: Economic Stress Index
* Combines unemployment, inflation, and income inequality
* Normalize each component and compute composite score
generate economic_stress_idx = .
replace economic_stress_idx = unemployment_rate + (cpi_inflation/10) + (gini_index*10) ///
        if !missing(unemployment_rate) & !missing(cpi_inflation) & !missing(gini_index)

label variable economic_stress_idx "Economic Stress Index (unemployment + inflation/10 + gini*10)"

* Variable 2: Social Well-being Indicator
* Combines employment rates, education attainment, and life expectancy
* (Only available where GSS data overlaps with economic data)
generate social_wellbeing_idx = .
replace social_wellbeing_idx = gss_employed_pct + gss_college_pct + (life_expectancy_at_birth/10) ///
        if !missing(gss_employed_pct) & !missing(gss_college_pct) & !missing(life_expectancy_at_birth)

label variable social_wellbeing_idx "Social Well-being Index (employment% + education% + life_exp/10)"

display "Derived variables created."
summarize economic_stress_idx social_wellbeing_idx

/*===============================================================================
* PART 5: CREATE CATEGORICAL VARIABLES
===============================================================================*/

display _newline(2)
display "================================================================================"
display "PART 5: CREATING CATEGORICAL VARIABLES"
display "================================================================================"

* Decade variable
generate decade = floor(year/10)*10
label variable decade "Decade"
label define decade_lbl 1940 "1940s" 1950 "1950s" 1960 "1960s" 1970 "1970s" ///
                        1980 "1980s" 1990 "1990s" 2000 "2000s" 2010 "2010s" 2020 "2020s"
label values decade decade_lbl

* Era classification (economic periods)
generate era = .
replace era = 1 if year >= 1947 & year <= 1974  /* Post-war Golden Age */
replace era = 2 if year >= 1975 & year <= 1991  /* Stagflation & Adjustment */
replace era = 3 if year >= 1992 & year <= 2007  /* New Economy & Boom */
replace era = 4 if year >= 2008                 /* Financial Crisis & After */

label variable era "Economic Era"
label define era_lbl 1 "Post-war Golden Age (1947-1974)" ///
                     2 "Stagflation & Adjustment (1975-1991)" ///
                     3 "New Economy & Boom (1992-2007)" ///
                     4 "Financial Crisis & After (2008+)"
label values era era_lbl

* Unemployment category
generate unemployment_cat = .
replace unemployment_cat = 1 if unemployment_rate < 4 & !missing(unemployment_rate)
replace unemployment_cat = 2 if unemployment_rate >= 4 & unemployment_rate < 6 & !missing(unemployment_rate)
replace unemployment_cat = 3 if unemployment_rate >= 6 & unemployment_rate < 8 & !missing(unemployment_rate)
replace unemployment_cat = 4 if unemployment_rate >= 8 & !missing(unemployment_rate)

label variable unemployment_cat "Unemployment Category"
label define unemp_lbl 1 "Low (<4%)" 2 "Moderate (4-6%)" 3 "Elevated (6-8%)" 4 "High (8%+)"
label values unemployment_cat unemp_lbl

display "Categorical variables created."

/*===============================================================================
* PART 6: ADD VARIABLE LABELS
===============================================================================*/

display _newline(2)
display "================================================================================"
display "PART 6: ADDING VARIABLE LABELS"
display "================================================================================"

label variable year "Year"
label variable unemployment_rate "Civilian Unemployment Rate (%)"
label variable labor_force_participation "Labor Force Participation Rate (%)"
label variable real_median_hh_income "Real Median Household Income (2024 $)"
label variable gini_index "Gini Index of Income Inequality"
label variable real_pce_per_capita "Real Personal Consumption Expenditures Per Capita (2024 $)"
label variable life_expectancy_at_birth "Life Expectancy at Birth (years)"
label variable cpi_inflation "Consumer Price Index - U (monthly average)"
label variable federal_min_wage "Federal Minimum Wage ($)"
label variable real_median_rent "Real Median Rent (monthly, 1982-84 $)"
label variable total_population "Total U.S. Population (thousands)"
label variable merge_status "Merge Status (1=Fred, 2=GSS, 3=Both)"

display "Variable labels applied."

/*===============================================================================
* PART 7: SAVE FINAL DATASET
===============================================================================*/

display _newline(2)
display "================================================================================"
display "PART 7: SAVING FINAL DATASET"
display "================================================================================"

* Sort by year for clarity
sort year

* Save as Stata dataset
save "PetersFinal.dta", replace

display "Final dataset saved as: PetersFinal.dta"
describe
summarize

/*===============================================================================
* PART 8: DESCRIPTIVE STATISTICS - CONTINUOUS VARIABLES
===============================================================================*/

display _newline(2)
display "================================================================================"
display "DESCRIPTIVE STATISTICS: CONTINUOUS VARIABLES"
display "================================================================================"

summarize year unemployment_rate labor_force_participation real_median_hh_income ///
          gini_index real_pce_per_capita life_expectancy_at_birth ///
          economic_stress_idx social_wellbeing_idx

display _newline(2)
foreach var of varlist unemployment_rate labor_force_participation real_median_hh_income ///
                      gini_index real_pce_per_capita life_expectancy_at_birth ///
                      economic_stress_idx social_wellbeing_idx {
    display "Variable: `:variable label `var''"
    summarize `var', detail
    display _newline(1)
}

/*===============================================================================
* PART 9: TABULATIONS - CATEGORICAL VARIABLES
===============================================================================*/

display _newline(2)
display "================================================================================"
display "TABULATIONS: CATEGORICAL VARIABLES"
display "================================================================================"

display _newline(1)
display "Decade Distribution:"
tabulate decade, missing

display _newline(1)
display "Economic Era Distribution:"
tabulate era, missing

display _newline(1)
display "Unemployment Category Distribution:"
tabulate unemployment_cat, missing

display _newline(1)
display "Era by Unemployment Category (row percentages):"
tabulate era unemployment_cat, row missing

/*===============================================================================
* PART 10: DATA VISUALIZATION
===============================================================================*/

display _newline(2)
display "================================================================================"
display "DATA VISUALIZATION"
display "================================================================================"

* Graph 1: Time series of unemployment rate
twoway (line unemployment_rate year, lwidth(medium) lcolor(navy)), ///
    title("U.S. Unemployment Rate Over Time", size(medium)) ///
    subtitle("Annual Data, 1947-2025", size(small)) ///
    ytitle("Unemployment Rate (%)") ///
    xtitle("Year") ///
    xlabel(1950(10)2020, angle(45)) ///
    ylabel(0(2)12, angle(0)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    note("Source: FRED (Series: UNRATE)")
graph export "unemployment_timeseries.png", replace width(1200)

* Graph 2: Real median household income trend
twoway (line real_median_hh_income year, lwidth(medium) lcolor(forest_green)), ///
    title("Real Median Household Income Trend", size(medium)) ///
    subtitle("Annual Data, 1984-2024 (2024 dollars)", size(small)) ///
    ytitle("Real Median HH Income ($)") ///
    xtitle("Year") ///
    xlabel(1985(5)2025, angle(45)) ///
    ylabel(, format(%9.0fc) angle(0)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    note("Source: FRED (Series: MEHOINUSA672N)")
graph export "median_income_trend.png", replace width(1200)

* Graph 3: Income inequality (Gini) and life expectancy dual axis
twoway (line gini_index year if !missing(gini_index), ///
        lwidth(medium) lcolor(cranberry) yaxis(1)) ///
       (line life_expectancy_at_birth year if !missing(life_expectancy_at_birth), ///
        lwidth(medium) lcolor(forest_green) lpattern(dash) yaxis(2)), ///
    title("Income Inequality vs. Life Expectancy", size(medium)) ///
    subtitle("Annual Data, 1960-2024", size(small)) ///
    ytitle("Gini Index", axis(1)) ///
    ytitle("Life Expectancy (years)", axis(2)) ///
    xtitle("Year") ///
    xlabel(1960(10)2020, angle(45)) ///
    ylabel(, angle(0) axis(1)) ///
    ylabel(70(2)80, angle(0) axis(2)) ///
    legend(order(1 "Gini Index" 2 "Life Expectancy") ///
           position(6) rows(1)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    note("Sources: FRED (SIPOVGINIUSA, SPDYNLE00INUSA)")
graph export "gini_life_expectancy.png", replace width(1200)

* Graph 4: Box plot of unemployment by economic era
graph box unemployment_rate, over(era, label(angle(45) labsize(small))) ///
    title("Unemployment Rate Distribution by Economic Era", size(medium)) ///
    ytitle("Unemployment Rate (%)") ///
    ylabel(0(2)12, angle(0)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    note("Source: FRED (Series: UNRATE)")
graph export "unemployment_by_era_boxplot.png", replace width(1200)

* Graph 5: Economic Stress Index over time
twoway (line economic_stress_idx year if !missing(economic_stress_idx), ///
        lwidth(medium) lcolor(navy)), ///
    title("Economic Stress Index Over Time", size(medium)) ///
    subtitle("Composite of unemployment, inflation, and inequality", size(small)) ///
    ytitle("Economic Stress Index") ///
    xtitle("Year") ///
    xlabel(1950(10)2020, angle(45)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    note("Index = unemployment% + (inflation/10) + (gini*10)")
graph export "economic_stress_index.png", replace width(1200)

* Graph 6: Social Well-being Index where available (limited by GSS data)
twoway (line social_wellbeing_idx year if !missing(social_wellbeing_idx), ///
        lwidth(medium) lcolor(forest_green)), ///
    title("Social Well-being Index (Where GSS Data Available)", size(medium)) ///
    subtitle("Composite of employment, education, and life expectancy", size(small)) ///
    ytitle("Social Well-being Index") ///
    xtitle("Year") ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    note("Index = employment% + education% + (life_expectancy/10)")
graph export "social_wellbeing_index.png", replace width(1200)

display _newline(2)
display "================================================================================"
display "Analysis complete! Graphs saved to working directory."
display "================================================================================"
