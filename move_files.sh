#!/bin/bash

# HIGH PRIORITY - Test/Helper Files
mv check_dofile.py Delete/ 2>/dev/null && echo "✓ Moved check_dofile.py"
mv create_stata_file.py Delete/ 2>/dev/null && echo "✓ Moved create_stata_file.py"
mv inspect_stata_file.py Delete/ 2>/dev/null && echo "✓ Moved inspect_stata_file.py"
mv test_syntax.do Delete/ 2>/dev/null && echo "✓ Moved test_syntax.do"
mv PetersDraft.do Delete/ 2>/dev/null && echo "✓ Moved PetersDraft.do"
mv PetersDraft.dta Delete/ 2>/dev/null && echo "✓ Moved PetersDraft.dta"
mv DoFileTemplate.do Delete/ 2>/dev/null && echo "✓ Moved DoFileTemplate.do"
mv StataExample-ApplyingVariableLabels\&ValueLabels.do Delete/ 2>/dev/null && echo "✓ Moved StataExample-ApplyingVariableLabels&ValueLabels.do"

# MEDIUM PRIORITY - Reference/Documentation
mv assignment.txt Delete/ 2>/dev/null && echo "✓ Moved assignment.txt"
mv GOVT301QuantDataProjectFinal-Fall2025*.pdf Delete/ 2>/dev/null && echo "✓ Moved GOVT301 assignment PDF"
mv GSS\ 2024\ -\ Whats\ New\ R2.pdf Delete/ 2>/dev/null && echo "✓ Moved GSS What's New PDF"
mv GSS\ 2024\ Codebook\ R2.pdf Delete/ 2>/dev/null && echo "✓ Moved GSS Codebook PDF"
mv GSS\ 2024\ Release\ Variables\ R2.pdf Delete/ 2>/dev/null && echo "✓ Moved GSS Release Variables PDF"
mv Release\ Notes\ 7224\ R2.pdf Delete/ 2>/dev/null && echo "✓ Moved Release Notes PDF"
mv ReadMe.txt Delete/ 2>/dev/null && echo "✓ Moved ReadMe.txt"

# LOW PRIORITY - Unused Data
mv cz_allIndicators_allSubgroups.csv Delete/ 2>/dev/null && echo "✓ Moved cz_allIndicators_allSubgroups.csv"

echo ""
echo "All deletable files moved to Delete/ folder!"
