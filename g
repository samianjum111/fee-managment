#!/usr/bin/env python3
"""
Patcher for axis_saas/views.py – adds missing imports:
- Count
- TruncMonth, TruncDay
- defaultdict
"""

import re
import os
import sys

def patch_views():
    views_path = os.path.join('axis_saas', 'views.py')
    if not os.path.exists(views_path):
        print(f"❌ {views_path} not found. Make sure you run this script from the project root (where manage.py is).")
        sys.exit(1)

    with open(views_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # List of imports to add (if not present)
    imports_to_add = [
        ('from django.db.models import Count', 'from django.db.models import Sum, Q'),
        ('from django.db.models.functions import TruncMonth, TruncDay', 'from django.db.models import Sum, Q'),
        ('from collections import defaultdict', 'from datetime import date, timedelta'),
    ]

    modified = False

    for new_import, after_line in imports_to_add:
        if new_import in content:
            print(f"✓ Already present: {new_import}")
            continue

        # Find the line where we want to insert
        # Use regex to find the after_line (exact match)
        pattern = re.compile(r'^' + re.escape(after_line) + r'$', re.MULTILINE)
        match = pattern.search(content)
        if match:
            insert_pos = match.end()
            # Insert new import after that line
            content = content[:insert_pos] + '\n' + new_import + content[insert_pos:]
            print(f"✅ Added: {new_import}")
            modified = True
        else:
            print(f"⚠️ Could not find anchor line: {after_line} – skipping {new_import}")

    if modified:
        with open(views_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("\n🎉 views.py successfully patched! Restart your Django development server now.")
    else:
        print("\n✨ No changes needed – all imports are already in place.")

if __name__ == '__main__':
    patch_views()
