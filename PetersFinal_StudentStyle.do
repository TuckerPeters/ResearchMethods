/*===============================================================================
* File:     PetersFinal.do
* Author:   Tucker Peters
* Date:     November 2025
* Purpose:  Analysis of U.S. Economic and Social Indicators
*
* This do-file loads economic data from FRED and merges it with General Social
* Survey data, then creates some derived variables and looks at patterns over time.
===============================================================================*/

clear all
set more off
insheet using "population_impact_datasets.csv", clear comma

* this is just to verify if it works
describe
display "Loaded data with `=_N' rows"

* Parsing the date column so its properly set up
generate year_date = date(date, "YMD")
format year_date %td
generate year = year(year_date)

* We have monthly data for some series and annual for others so we need to figure out how to translate it to annual 

collapse (mean) unemployment_rate labor_force_participation real_median_hh_income /// *COME BACK TO / CHECK*
         gini_index real_pce_per_capita life_expectancy_at_birth ///
         cpi_inflation federal_min_wage real_median_rent total_population, by(year)

display "After collapsing to annual: `=_N' rows"
list year unemployment_rate life_expectancy_at_birth in 1/5

tempfile fred_yearly
save `fred_yearly'

* Load GSS
use "gss7224_r2.dta", clear
display "GSS file loaded"

* Look for the year variable *dk if else works but hopefully python style if else works*
capture describe year
if _rc == 0 {
    display "Found 'year' variable"
} else { 
    capture describe YEAR
    if _rc == 0 {
        rename YEAR year
        display "Renamed YEAR to year"
    }
}

* Create some flags for variables we want to aggregate
* Union membership - did respondent say yes to union?
generate in_union = (union == 1) if !missing(union)

* Are they employed? 
generate working = (wrkstat == 1) if !missing(wrkstat)

* Do they have a college degree? 
generate college = (degree >= 3) if !missing(degree)

collapse (mean) in_union working college (count) n_respondents = in_union, by(year)

* Convert to percentages 
replace in_union = in_union * 100
replace working = working * 100
replace college = college * 100

* Rename so they're clearer
rename in_union gss_union_pct
rename working gss_work_pct
rename college gss_college_pct

display "GSS data aggregated by year"
list year gss_union_pct gss_work_pct gss_college_pct in 1/5

* Save this!!
tempfile gss_yearly
save `gss_yearly'

* Now merge the two datasets together
use `fred_yearly', clear
merge 1:1 year using `gss_yearly', generate(merge_check)
* merge_check should tell us which years have both datasets

* merge checl
tabulate merge_check
display "Merge complete"

* ============================================================================
* Creating some new vars
* ============================================================================

* Variable 1: Unemployment category - is unemployment low, medium, high?
generate unemp_category = .
replace unemp_category = 1 if unemployment_rate < 4
replace unemp_category = 2 if unemployment_rate >= 4 & unemployment_rate < 6
replace unemp_category = 3 if unemployment_rate >= 6 & unemployment_rate < 8
replace unemp_category = 4 if unemployment_rate >= 8

label define unemp_cat 1 "Low" 2 "Moderate" 3 "Elevated" 4 "High"
label values unemp_category unemp_cat

* Variable 2: Economic stress index
* Try to combine unemployment, inflation, and inequality into one number
* Higher = more stress
generate econ_stress = unemployment_rate + (cpi_inflation/10) + (gini_index * 10)
label variable econ_stress "Economic Stress Index"

* Variable 3: Decade
generate decade = floor(year/10)*10
label define decade_labels 1940 "1940s" 1950 "1950s" 1960 "1960s" 1970 "1970s" ///
                           1980 "1980s" 1990 "1990s" 2000 "2000s" 2010 "2010s" 2020 "2020s"
label values decade decade_labels

display "Created 3 new variables: unemp_category, econ_stress, decade"

* ============================================================================
* Add labels to everything
* ============================================================================

label variable year "Year"
label variable unemployment_rate "Unemployment Rate (%)"
label variable labor_force_participation "Labor Force Participation (%)"
label variable real_median_hh_income "Real Median HH Income"
label variable gini_index "Gini Index (Inequality)"
label variable real_pce_per_capita "Real PCE Per Capita"
label variable life_expectancy_at_birth "Life Expectancy (years)"
label variable cpi_inflation "CPI Inflation Index"
label variable federal_min_wage "Federal Minimum Wage"
label variable real_median_rent "Real Median Rent"
label variable total_population "Total Population"
label variable gss_union_pct "% in Union (GSS)"
label variable gss_work_pct "% Working (GSS)"
label variable gss_college_pct "% College Grad (GSS)"
label variable unemp_category "Unemployment Category"
label variable decade "Decade"

* ============================================================================
* Save the final dataset
* ============================================================================

sort year
save "PetersFinal.dta", replace
display "Final dataset saved!"
describe
summarize

* ============================================================================
* Summary statistics
* ============================================================================

display _newline(2)
display "============================================================"
display "SUMMARY STATISTICS FOR KEY VARIABLES"
display "============================================================"

summarize unemployment_rate life_expectancy_at_birth real_median_hh_income ///
          gini_index econ_stress

* Look at each variable separately with more details
foreach var of varlist unemployment_rate labor_force_participation ///
                      life_expectancy_at_birth real_median_hh_income {
    display _newline(1)
    display "--- `var' ---"
    summarize `var', detail
}

* ============================================================================
* Look at unemployment by decade
* ============================================================================

display _newline(2)
display "Unemployment by Decade:"
tabulate decade unemp_category, row

* ============================================================================
* Create some graphs
* ============================================================================

display _newline(2)
display "Creating graphs..."

* Graph 1: Unemployment over time
twoway (line unemployment_rate year, lwidth(medium) lcolor(navy)), ///
    title("U.S. Unemployment Rate (1948-2025)") ///
    ytitle("Unemployment Rate (%)") ///
    xtitle("Year") ///
    ylabel(0(2)10) ///
    graphregion(color(white)) ///
    plotregion(color(white))
graph export "unemployment.png", replace width(1000)

* Graph 2: Life expectancy trend
twoway (line life_expectancy_at_birth year if !missing(life_expectancy_at_birth), ///
        lwidth(medium) lcolor(green)), ///
    title("U.S. Life Expectancy at Birth") ///
    ytitle("Life Expectancy (years)") ///
    xtitle("Year") ///
    graphregion(color(white)) ///
    plotregion(color(white))
graph export "life_expectancy.png", replace width(1000)

* Graph 3: Gini index (inequality) over time
twoway (line gini_index year if !missing(gini_index), ///
        lwidth(medium) lcolor(red)), ///
    title("Income Inequality (Gini Index)") ///
    ytitle("Gini Index") ///
    xtitle("Year") ///
    graphregion(color(white)) ///
    plotregion(color(white))
graph export "gini_index.png", replace width(1000)

* Graph 4: Box plot of unemployment by decade
graph box unemployment_rate, over(decade) ///
    title("Unemployment Distribution by Decade") ///
    ytitle("Unemployment Rate (%)") ///
    graphregion(color(white)) ///
    plotregion(color(white))
graph export "unemployment_by_decade.png", replace width(1000)

* Graph 5: Economic stress index
twoway (line econ_stress year if !missing(econ_stress), ///
        lwidth(medium) lcolor(darkred)), ///
    title("Economic Stress Index Over Time") ///
    ytitle("Stress Index") ///
    xtitle("Year") ///
    graphregion(color(white)) ///
    plotregion(color(white))
graph export "economic_stress.png", replace width(1000)

* Graph 6: Income and life expectancy together
twoway (line real_median_hh_income year if !missing(real_median_hh_income), ///
        lwidth(medium) lcolor(blue) yaxis(1)) ///
       (line life_expectancy_at_birth year if !missing(life_expectancy_at_birth), ///
        lwidth(medium) lcolor(green) lpattern(dash) yaxis(2)), ///
    title("Income vs. Life Expectancy") ///
    ytitle("Real Median HH Income", axis(1)) ///
    ytitle("Life Expectancy (years)", axis(2)) ///
    xtitle("Year") ///
    legend(order(1 "Income" 2 "Life Expectancy")) ///
    graphregion(color(white)) ///
    plotregion(color(white))
graph export "income_vs_lifeexp.png", replace width(1000)

display "All graphs saved!"
display _newline(2)
display "Analysis complete."
