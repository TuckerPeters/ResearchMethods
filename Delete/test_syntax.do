* Quick syntax check - don't run full analysis
clear all
set more off

* Test 1: Check if CSV exists
capture confirm file "population_impact_datasets.csv"
if _rc == 0 {
    display "✓ CSV file found"
} else {
    display "✗ CSV file NOT found - need to run fred.py first"
}

* Test 2: Check if GSS file exists
capture confirm file "gss7224_r2.dta"
if _rc == 0 {
    display "✓ GSS file found"
} else {
    display "✗ GSS file NOT found"
}

* Test 3: Try loading CSV (just describe, don't keep it)
capture noisily insheet using "population_impact_datasets.csv", clear comma
if _rc == 0 {
    display "✓ CSV loads successfully"
    describe in 1/5
} else {
    display "✗ CSV failed to load"
}

display _newline
display "Syntax tests complete"
