#!/usr/bin/env python3
"""
mobile_nav_patcher.py
Fixes the bottom nav "Collect" link to use mobile_fee_collection instead of fee_collection.
Run: python3 mobile_nav_patcher.py
"""

import re
from pathlib import Path

BASE_DIR = Path(__file__).parent
MOBILE_BASE = BASE_DIR / "templates" / "mobile" / "base.html"

def patch_mobile_base():
    if not MOBILE_BASE.exists():
        print(f"❌ File not found: {MOBILE_BASE}")
        return

    with open(MOBILE_BASE, "r") as f:
        content = f.read()

    # Look for the bottom nav "Collect" link
    # We'll replace the url tag with the mobile version
    old_href = r"{% url 'fee_collection' schema_name=tenant.schema_name %}"
    new_href = "{% url 'mobile_fee_collection' schema_name=tenant.schema_name %}"

    if old_href not in content:
        print("⚠️ Could not find the exact 'fee_collection' URL tag in mobile/base.html")
        # Fallback: try to replace the whole <a> tag using regex
        pattern = r'<a href="{% url \'fee_collection\' schema_name=tenant\.schema_name %}" class="nav-item {% if \'fee_collection\' in request\.resolver_match\.url_name %}active{% endif %}>'
        if re.search(pattern, content):
            new_tag = '<a href="{% url \'mobile_fee_collection\' schema_name=tenant.schema_name %}" class="nav-item {% if \'fee_collection\' in request.resolver_match.url_name %}active{% endif %}>'
            content = re.sub(pattern, new_tag, content)
            print("✅ Patched using regex fallback")
        else:
            print("❌ Could not find any matching pattern. Please update manually.")
            return
    else:
        content = content.replace(old_href, new_href)
        print("✅ Replaced fee_collection with mobile_fee_collection in bottom nav")

    with open(MOBILE_BASE, "w") as f:
        f.write(content)

    print("✅ Mobile base template updated. Restart server to apply changes.")

if __name__ == "__main__":
    patch_mobile_base()
