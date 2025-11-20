#!/usr/bin/env python3
"""Check Stata do-files for common syntax issues"""

import re

def check_dofile(filename):
    print(f"\n{'='*70}")
    print(f"Checking: {filename}")
    print('='*70)
    
    with open(filename, 'r') as f:
        lines = f.readlines()
    
    issues = []
    
    # Check for unmatched quotes
    for i, line in enumerate(lines, 1):
        # Skip comments
        if line.strip().startswith('*'):
            continue
        # Check for obvious syntax issues
        if 'generate' in line and '=' not in line and 'generate' in line:
            # This might be incomplete
            if not any(x in line for x in ['=', 'if', 'replace']):
                issues.append(f"Line {i}: Possible incomplete generate statement")
    
    # Count key commands
    commands = {
        'insheet': len([l for l in lines if 'insheet' in l]),
        'collapse': len([l for l in lines if 'collapse' in l]),
        'generate': len([l for l in lines if 'generate' in l]),
        'label': len([l for l in lines if 'label ' in l]),
        'twoway': len([l for l in lines if 'twoway' in l]),
        'graph': len([l for l in lines if 'graph' in l]),
    }
    
    print(f"✓ Total lines: {len(lines)}")
    print(f"✓ Commands found:")
    for cmd, count in commands.items():
        print(f"  • {cmd}: {count}")
    
    if issues:
        print(f"\n⚠ Potential issues:")
        for issue in issues:
            print(f"  • {issue}")
    else:
        print("\n✓ No obvious syntax issues detected")
    
    return len(issues) == 0

# Test both do-files
files = ['PetersFinal_StudentStyle.do', 'PetersFinal.do']
all_ok = True
for f in files:
    ok = check_dofile(f)
    all_ok = all_ok and ok

print(f"\n{'='*70}")
if all_ok:
    print("✓ Both do-files look good!")
else:
    print("⚠ Some potential issues found")
print('='*70)
