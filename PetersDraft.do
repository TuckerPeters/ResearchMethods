********************************************************************************
* File:     PetersDraft.do
* Author:   Tucker Peters
* Date:     October 6, 2025
* Purpose:  Analysis of U.S. Economic and Population Impact Indicators (1929-2025)
*
* Description:
*   This do-file analyzes a time-series dataset containing annual observations
*   of key economic and social indicators including unemployment, labor force
*   participation, income, inequality, consumption, life expectancy, and poverty.
*   Data sourced from FRED (Federal Reserve Economic Data) and U.S. Census Bureau.
*
* Input:    PetersDraft.dta
* Output:   Summary statistics, tabulations, and visualizations
********************************************************************************

clear all
set more off

* Set working directory to the location of this .do file
* This works on any computer as long as the .dta file is in the same folder
* Method 1: Uncomment and manually set the path to where your files are located
* cd "/path/to/your/files"

* Method 2: Or, before running this .do file, use Stata's File menu to
* "Change Working Directory" to the folder containing both files

* Load the dataset (assumes .dta file is in current working directory)
use "PetersDraft.dta", clear

********************************************************************************
* VARIABLE LABELS AND VALUE LABELS
********************************************************************************
* Note: All variable labels and value labels are already embedded in the
* PetersDraft.dta file. No need to redefine them here.

********************************************************************************
* DESCRIPTIVE STATISTICS - INTERVAL/RATIO VARIABLES
********************************************************************************

display _newline(2)
display "=" * 80
display "DESCRIPTIVE STATISTICS: CONTINUOUS VARIABLES"
display "=" * 80

* Summary statistics for all continuous variables
summarize year unemp_rate lfpr med_income gini pce_capita life_expect poverty_rate

* Detailed statistics
display _newline(2)
display "-" * 80
display "DETAILED STATISTICS BY VARIABLE"
display "-" * 80

foreach var of varlist unemp_rate lfpr med_income gini pce_capita life_expect poverty_rate {
    display _newline(1)
    display "Variable: `:variable label `var''"
    summarize `var', detail
}

********************************************************************************
* TABULATIONS - NOMINAL/ORDINAL VARIABLES
********************************************************************************

display _newline(2)
display "=" * 80
display "TABULATIONS: CATEGORICAL VARIABLES"
display "=" * 80

* Decade distribution
display _newline(1)
display "Decade Distribution:"
tabulate decade, missing

* Economic Era distribution
display _newline(1)
display "Economic Era Distribution:"
tabulate econ_era, missing

* Unemployment Category distribution
display _newline(1)
display "Unemployment Category Distribution:"
tabulate unemp_cat, missing

* Cross-tabulation: Economic Era by Unemployment Category
display _newline(1)
display "Economic Era by Unemployment Category:"
tabulate econ_era unemp_cat, row missing

********************************************************************************
* DATA VISUALIZATION
********************************************************************************

* Graph 1: Time series of unemployment rate over time
twoway (line unemp_rate year, lwidth(medium) lcolor(navy)), ///
    title("U.S. Unemployment Rate Over Time", size(medium)) ///
    subtitle("Annual Data, 1948-2025", size(small)) ///
    ytitle("Unemployment Rate (%)") ///
    xtitle("Year") ///
    xlabel(1950(10)2020, angle(45)) ///
    ylabel(0(2)12, angle(0)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    note("Source: FRED (Series: UNRATE, December values)")
graph export "unemployment_timeseries.png", replace width(1200)

* Graph 2: Life expectancy and poverty rate over time (dual axis)
twoway (line life_expect year if !missing(life_expect), ///
        lwidth(medium) lcolor(forest_green) yaxis(1)) ///
       (line poverty_rate year if !missing(poverty_rate), ///
        lwidth(medium) lcolor(cranberry) lpattern(dash) yaxis(2)), ///
    title("Life Expectancy and Poverty Rate in the U.S.", size(medium)) ///
    subtitle("Annual Data, 1960-2024", size(small)) ///
    ytitle("Life Expectancy (years)", axis(1)) ///
    ytitle("Poverty Rate (%)", axis(2)) ///
    xtitle("Year") ///
    xlabel(1960(10)2020, angle(45)) ///
    ylabel(65(5)80, angle(0) axis(1)) ///
    ylabel(8(2)24, angle(0) axis(2)) ///
    legend(order(1 "Life Expectancy (years)" 2 "Poverty Rate (%)") ///
           position(6) rows(1)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    note("Source: FRED (SPDYNLE00INUSA) and U.S. Census (histpov2)")
graph export "life_expect_poverty.png", replace width(1200)

* Graph 3: Box plot of unemployment by economic era
graph box unemp_rate, over(econ_era, label(angle(45) labsize(small))) ///
    title("Unemployment Rate Distribution by Economic Era", size(medium)) ///
    ytitle("Unemployment Rate (%)") ///
    ylabel(0(2)12, angle(0)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    note("Source: FRED (Series: UNRATE)")
graph export "unemployment_by_era_boxplot.png", replace width(1200)

* Graph 4: Scatter plot - Gini index vs median income
scatter gini med_income if !missing(gini) & !missing(med_income), ///
    mcolor(navy) msymbol(circle) msize(medium) ///
    title("Income Inequality vs. Median Household Income", size(medium)) ///
    subtitle("U.S. Annual Data, 1984-2024", size(small)) ///
    ytitle("Gini Index (higher = more inequality)") ///
    xtitle("Real Median Household Income (2024 dollars)") ///
    ylabel(, angle(0)) ///
    xlabel(, format(%9.0fc)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    note("Sources: FRED (SIPOVGINIUSA, MEHOINUSA672N)")
graph export "gini_vs_income_scatter.png", replace width(1200)

display _newline(2)
display "=" * 80
display "Analysis complete! Graphs saved to working directory."
display "=" * 80
