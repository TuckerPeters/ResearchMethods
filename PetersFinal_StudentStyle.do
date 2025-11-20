/*===============================================================================
* File:     PetersFinal.do
* Author:   Tucker Peters
* Date:     November 2025
* Purpose:  Analysis of U.S. Economic and Social Indicators
*
* ABSTRACT:
* This analysis examines the relationship between long-term macroeconomic
* trends and social indicators to understand how economic conditions affect
* social outcomes. Using data from FRED (Federal Reserve Economic Data) and
* the General Social Survey (GSS), this study integrates annual economic
* indicators (unemployment, inflation, life expectancy, income inequality)
* with social survey data (employment, education, union membership) across
* 1972-2024. The analysis creates composite measures including an economic
* stress index and unemployment categories to facilitate temporal analysis
* of whether economic stressors correlate with social outcomes.
*
===============================================================================*/

clear all
set more off

* ============================================================================
* Load dataset
* ============================================================================

use "PetersFinal.dta", clear

display "Loaded FRED and GSS merged dataset"
describe
display "Total observations: `=_N'"

* ============================================================================
* Create derived variables using generate command
* ============================================================================
* Assignment requirement: At least 2 substantively meaningful variables created
* using generate and/or recode command

* Variable 1: Unemployment category
* Creates ordinal categorical variable from continuous unemployment rate
generate unemp_category = .
replace unemp_category = 1 if UNEMPLOYMENT_RATE < 4
replace unemp_category = 2 if UNEMPLOYMENT_RATE >= 4 & UNEMPLOYMENT_RATE < 6
replace unemp_category = 3 if UNEMPLOYMENT_RATE >= 6 & UNEMPLOYMENT_RATE < 8
replace unemp_category = 4 if UNEMPLOYMENT_RATE >= 8

label define unemp_cat 1 "Low (<4%)" 2 "Moderate (4-6%)" 3 "Elevated (6-8%)" 4 "High (8%+)"
label values unemp_category unemp_cat

* Variable 2: Economic stress index
* Composite measure combining unemployment, inflation, and inequality
* Higher values indicate greater economic stress
generate econ_stress = UNEMPLOYMENT_RATE + (CPI_INFLATION/10) + (GINI_INDEX * 10)
label variable econ_stress "Economic Stress Index (Composite)"

* Variable 3: Decade
* Helper variable for temporal analysis
generate decade = floor(year/10)*10
label define decade_labels 1920 "1920s" 1930 "1930s" 1940 "1940s" 1950 "1950s" ///
                           1960 "1960s" 1970 "1970s" 1980 "1980s" 1990 "1990s" ///
                           2000 "2000s" 2010 "2010s" 2020 "2020s"
label values decade decade_labels

display "Created 3 new variables: unemp_category, econ_stress, decade"

* ============================================================================
* Variable labels
* ============================================================================

label variable year "Year"
label variable UNEMPLOYMENT_RATE "Unemployment Rate (%)"
label variable LABOR_FORCE_PARTICIPATION "Labor Force Participation Rate (%)"
label variable REAL_MEDIAN_HH_INCOME "Real Median Household Income ($)"
label variable GINI_INDEX "Gini Index (Income Inequality)"
label variable REAL_PCE_PER_CAPITA "Real Personal Consumption Expenditures Per Capita ($)"
label variable LIFE_EXPECTANCY_AT_BIRTH "Life Expectancy at Birth (years)"
label variable CPI_INFLATION "Consumer Price Index - All Urban Consumers"
label variable FEDERAL_MIN_WAGE "Federal Minimum Wage ($)"
label variable REAL_MEDIAN_RENT "Real Median Rent (Index)"
label variable TOTAL_POPULATION "Total U.S. Population"
label variable gss_union_pct "Percent in Labor Union (%)"
label variable gss_work_pct "Percent Employed (%)"
label variable gss_college_pct "Percent with College Degree or Higher (%)"
label variable unemp_category "Unemployment Category"
label variable decade "Decade"

* ============================================================================
* Save final dataset
* ============================================================================

sort year
save "PetersFinal.dta", replace
display "Final dataset saved as PetersFinal.dta"

* ============================================================================
* SUMMARY STATISTICS
* ============================================================================

display _newline(2)
display "=================================================================="
display "SUMMARY STATISTICS: KEY ECONOMIC VARIABLES"
display "=================================================================="

summarize UNEMPLOYMENT_RATE LIFE_EXPECTANCY_AT_BIRTH REAL_MEDIAN_HH_INCOME ///
          GINI_INDEX econ_stress

* ============================================================================
* CROSS-TABULATION: Unemployment Category by Decade
* ============================================================================

display _newline(2)
display "=================================================================="
display "CROSS-TABULATION: Unemployment Category by Decade"
display "=================================================================="

tabulate decade unemp_category, row

* ============================================================================
* DATA VISUALIZATIONS
* ============================================================================

display _newline(2)
display "Creating visualizations..."

* Graph 1: Unemployment Rate Over Time
twoway (line UNEMPLOYMENT_RATE year, lwidth(medium) lcolor(navy)), ///
    title("U.S. Unemployment Rate (1948-2025)") ///
    ytitle("Unemployment Rate (%)") ///
    xtitle("Year") ///
    graphregion(color(white)) ///
    plotregion(color(white))
graph export "unemployment_trend.png", replace width(1000)

* Graph 2: Life Expectancy Over Time
twoway (line LIFE_EXPECTANCY_AT_BIRTH year if !missing(LIFE_EXPECTANCY_AT_BIRTH), ///
        lwidth(medium) lcolor(green)), ///
    title("U.S. Life Expectancy at Birth") ///
    ytitle("Life Expectancy (years)") ///
    xtitle("Year") ///
    graphregion(color(white)) ///
    plotregion(color(white))
graph export "life_expectancy_trend.png", replace width(1000)

* Graph 3: Income Inequality Over Time
twoway (line GINI_INDEX year if !missing(GINI_INDEX), ///
        lwidth(medium) lcolor(red)), ///
    title("Income Inequality (Gini Index) Over Time") ///
    ytitle("Gini Index") ///
    xtitle("Year") ///
    graphregion(color(white)) ///
    plotregion(color(white))
graph export "gini_index_trend.png", replace width(1000)

* Graph 4: Economic Stress Index Over Time
twoway (line econ_stress year if !missing(econ_stress), ///
        lwidth(medium) lcolor(darkred)), ///
    title("Economic Stress Index Over Time") ///
    ytitle("Stress Index") ///
    xtitle("Year") ///
    graphregion(color(white)) ///
    plotregion(color(white))
graph export "economic_stress_trend.png", replace width(1000)

* Graph 5: Box Plot - Unemployment by Decade
graph box UNEMPLOYMENT_RATE, over(decade) ///
    title("Unemployment Rate Distribution by Decade") ///
    ytitle("Unemployment Rate (%)") ///
    graphregion(color(white)) ///
    plotregion(color(white))
graph export "unemployment_by_decade.png", replace width(1000)

* Graph 6: Income vs. Life Expectancy
twoway (line REAL_MEDIAN_HH_INCOME year if !missing(REAL_MEDIAN_HH_INCOME), ///
        lwidth(medium) lcolor(blue) yaxis(1)) ///
       (line LIFE_EXPECTANCY_AT_BIRTH year if !missing(LIFE_EXPECTANCY_AT_BIRTH), ///
        lwidth(medium) lcolor(green) lpattern(dash) yaxis(2)), ///
    title("Real Median Income vs. Life Expectancy") ///
    ytitle("Real Median HH Income ($)", axis(1)) ///
    ytitle("Life Expectancy (years)", axis(2)) ///
    xtitle("Year") ///
    legend(order(1 "Income" 2 "Life Expectancy")) ///
    graphregion(color(white)) ///
    plotregion(color(white))
graph export "income_vs_lifeexp.png", replace width(1000)

display "All visualizations created successfully"
display _newline(2)
display "Analysis complete!"
