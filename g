#!/usr/bin/env python3
"""
Restore gym_attendance view that was accidentally removed.
Adds a proper GET-capable definition before the GYM API VIEWS section.
"""
import re
import os

VIEWS_PATH = "axis_saas/views.py"

if not os.path.exists(VIEWS_PATH):
    print(f"❌ {VIEWS_PATH} not found")
    exit(1)

with open(VIEWS_PATH, "r") as f:
    content = f.read()

# Check if gym_attendance already exists (anywhere)
if "def gym_attendance(" in content:
    print("✅ gym_attendance already exists – nothing to do.")
    exit(0)

# The correct definition
new_function = """
@require_tenant_type(['gym'])
def gym_attendance(request, schema_name):
    \"\"\"Attendance management page.\"\"\"
    from django.shortcuts import render
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        context = {
            'tenant': get_tenant(request, schema_name),
            'logo_url': get_tenant(request, schema_name).school_logo.url if get_tenant(request, schema_name).school_logo else None,
        }
        return render(request, 'tenant/gym_attendance.html', context)

"""

# Find the line "# ==================== GYM API VIEWS ===================="
api_section_marker = "# ==================== GYM API VIEWS ===================="
if api_section_marker not in content:
    print("⚠️ Could not find GYM API VIEWS marker. Appending at end.")
    content += "\n\n" + new_function
else:
    # Insert new function right before that marker
    content = content.replace(api_section_marker, new_function + "\n" + api_section_marker)

with open(VIEWS_PATH, "w") as f:
    f.write(content)

print("✅ Added gym_attendance view (GET‑capable).")
print("   Restart the server: python3 manage.py runserver")
