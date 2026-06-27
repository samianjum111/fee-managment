#!/usr/bin/env python3
"""
Fix missing mobile_defaulters_view in public_urls.py
Run: python fix_mobile_defaulters_view.py
"""

import re
from pathlib import Path

PUBLIC_URLS = Path("axis_saas/public_urls.py")

def add_mobile_defaulters_view():
    if not PUBLIC_URLS.exists():
        print("❌ public_urls.py nahi mila")
        return

    content = PUBLIC_URLS.read_text()

    # Already defined?
    if "mobile_defaulters_view = portal_wrapper" in content:
        print("✅ mobile_defaulters_view already exists, no changes needed.")
        return

    # Insert after an existing similar definition (e.g., gym_settings_view)
    if "gym_settings_view = portal_wrapper" in content:
        # Insert right after that line
        lines = content.splitlines()
        new_lines = []
        inserted = False
        for line in lines:
            new_lines.append(line)
            if not inserted and "gym_settings_view = portal_wrapper" in line:
                new_lines.append("mobile_defaulters_view = portal_wrapper(login_required_for_schema(mobile_defaulters))")
                inserted = True
        content = "\n".join(new_lines)
        print("✅ Inserted after gym_settings_view")
    else:
        # Fallback: insert right before urlpatterns
        content = content.replace(
            "urlpatterns = [",
            "mobile_defaulters_view = portal_wrapper(login_required_for_schema(mobile_defaulters))\n\nurlpatterns = ["
        )
        print("✅ Inserted before urlpatterns")

    PUBLIC_URLS.write_text(content)
    print("✅ Fix applied. Restart server now.")

if __name__ == "__main__":
    add_mobile_defaulters_view()
