#!/usr/bin/env python3
"""
Patcher: Update mobile dashboard quick actions.
- Add Student -> add_student_mobile
- Collect fee -> Fee Settings (mobile_fee_settings)
"""

DASHBOARD_HTML = "templates/mobile/dashboard.html"

with open(DASHBOARD_HTML, "r") as f:
    content = f.read()

# 1. Update Add Student link
old_add = 'href="{% url \'add_student\' schema_name=tenant.schema_name %}"'
new_add = 'href="{% url \'add_student_mobile\' schema_name=tenant.schema_name %}"'
content = content.replace(old_add, new_add)

# 2. Replace Collect fee with Fee Settings (icon + text + URL)
old_collect = '''    <a href="{% url 'mobile_fee_collection' schema_name=tenant.schema_name %}" class="action-tile">
        <div class="icon">₹</div>
        <strong>Collect fee</strong>
    </a>'''

new_collect = '''    <a href="{% url 'mobile_fee_settings' schema_name=tenant.schema_name %}" class="action-tile">
        <div class="icon">⚙️</div>
        <strong>Fee Settings</strong>
    </a>'''

content = content.replace(old_collect, new_collect)

with open(DASHBOARD_HTML, "w") as f:
    f.write(content)

print("✅ Updated mobile dashboard quick actions.")
print("   - Add Student → add_student_mobile")
print("   - Collect fee → Fee Settings (mobile_fee_settings)")
