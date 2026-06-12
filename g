#!/usr/bin/env python3
"""
Fix duplicate dictionary key in product_detail view.
Run: python3 fix_product_detail_syntax.py
"""

import re
import os

VIEWS_FILE = "axis_saas/views.py"

if not os.path.exists(VIEWS_FILE):
    print(f"❌ {VIEWS_FILE} not found")
    exit(1)

with open(VIEWS_FILE, "r") as f:
    content = f.read()

# Pattern to match the broken line
# It may have varying whitespace, so we use regex
pattern = r"(\s*'recent_buyers':\s*)'recent_buyers':\s*(\[.*?\]),"
replacement = r"\1\2,"

new_content = re.sub(pattern, replacement, content)

if new_content == content:
    print("⚠️ Pattern not found. Trying simpler replacement...")
    # Fallback: replace exact string
    old_str = "'recent_buyers': 'recent_buyers': [{'id': sid, 'name': name} for sid, name in buyer_info.items()][:8],"
    new_str = "'recent_buyers': [{'id': sid, 'name': name} for sid, name in buyer_info.items()][:8],"
    if old_str in content:
        new_content = content.replace(old_str, new_str)
        print("✅ Manual string replacement done")
    else:
        print("❌ Could not locate the broken line. Please edit views.py manually.")
        exit(1)

# Backup original
backup = VIEWS_FILE + ".bak2"
with open(backup, "w") as bf:
    bf.write(content)
print(f"   Backed up: {backup}")

# Write fixed content
with open(VIEWS_FILE, "w") as f:
    f.write(new_content)

print("\n✅ Fixed syntax error in product_detail.")
print("👉 Restart the server: python3 manage.py runserver")
