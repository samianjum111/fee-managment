import re

with open("axis_saas/models.py", "r") as f:
    content = f.read()

# Fix extra_charges indentation: replace 7 spaces with 4
content = re.sub(r' {7}extra_charges = models\.JSONField\(.*?\)',
                 '    extra_charges = models.JSONField(default=list, blank=True, help_text="Additional charges for this month\'s fee")',
                 content, flags=re.MULTILINE)

# Remove any leading backslash before single quote in help_text
content = content.replace("month\\'s", "month's")

# Also ensure default_fee_charges is correctly indented (should be 4 spaces)
content = re.sub(r' {7}default_fee_charges = models\.JSONField\(.*?\)',
                 '    default_fee_charges = models.JSONField(default=list, blank=True, help_text="Pre‑filled charges when generating a voucher manually")',
                 content, flags=re.MULTILINE)

with open("axis_saas/models.py", "w") as f:
    f.write(content)

print("✅ Fixed models.py indentation and escaped quotes.")
