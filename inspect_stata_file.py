#!/usr/bin/env python3
"""
inspect_stata_file.py

Reads and displays the contents of the Stata .dta file to verify
variable labels, value labels, and data without needing Stata.
"""

import pandas as pd

print("=" * 80)
print("INSPECTING: PetersDraft.dta")
print("=" * 80)

# Read the Stata file
df = pd.read_stata("PetersDraft.dta")

print("\n1. DATASET OVERVIEW")
print("-" * 80)
print(f"Number of observations: {len(df)}")
print(f"Number of variables: {len(df.columns)}")
print(f"Year range: {df['year'].min():.0f} to {df['year'].max():.0f}")

print("\n2. VARIABLE NAMES AND LABELS")
print("-" * 80)
# Get variable labels from Stata file metadata
reader = pd.io.stata.StataReader("PetersDraft.dta")
var_labels = reader.variable_labels()
reader.close()

for i, col in enumerate(df.columns, 1):
    label = var_labels.get(col, "No label")
    print(f"{i:2d}. {col:20s} - {label}")

print("\n3. VALUE LABELS (for categorical variables)")
print("-" * 80)

# Read value labels
reader = pd.io.stata.StataReader("PetersDraft.dta")
value_labels = reader.value_labels()
reader.close()

if value_labels:
    for var_name, labels in value_labels.items():
        print(f"\n{var_name}:")
        for code, label in sorted(labels.items()):
            print(f"  {code} = {label}")
else:
    print("No value labels found in file")

print("\n4. FIRST 10 OBSERVATIONS")
print("-" * 80)
print(df.head(10).to_string(index=False))

print("\n5. LAST 10 OBSERVATIONS")
print("-" * 80)
print(df.tail(10).to_string(index=False))

print("\n6. DESCRIPTIVE STATISTICS")
print("-" * 80)
print(df.describe().to_string())

print("\n7. MISSING DATA SUMMARY")
print("-" * 80)
missing = df.isnull().sum()
total = len(df)
for col in df.columns:
    n_missing = missing[col]
    pct_missing = (n_missing / total) * 100
    if n_missing > 0:
        print(f"{col:20s}: {n_missing:3d} missing ({pct_missing:5.1f}%)")

print("\n8. FREQUENCY TABLES FOR CATEGORICAL VARIABLES")
print("-" * 80)

print("\nDecade:")
print(df['decade'].value_counts().sort_index())

print("\nEconomic Era:")
print(df['econ_era'].value_counts().sort_index())

print("\nUnemployment Category:")
print(df['unemp_cat'].value_counts().sort_index())

print("\n" + "=" * 80)
print("Inspection complete!")
print("=" * 80)
