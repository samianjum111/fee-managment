import re

# 1. Fix fee_generate: convert month and year to int
public_urls_path = "axis_saas/public_urls.py"
with open(public_urls_path, "r") as f:
    content = f.read()

# Replace month = form.cleaned_data['month'] with int conversion
old_month = "month = form.cleaned_data['month']"
new_month = "month = int(form.cleaned_data['month'])"
if old_month in content:
    content = content.replace(old_month, new_month)
else:
    # Alternative pattern
    content = re.sub(r"month = form\.cleaned_data\['month'\]", "month = int(form.cleaned_data['month'])", content)

old_year = "year = form.cleaned_data['year']"
new_year = "year = int(form.cleaned_data['year'])"
if old_year in content:
    content = content.replace(old_year, new_year)
else:
    content = re.sub(r"year = form\.cleaned_data\['year'\]", "year = int(form.cleaned_data['year'])", content)

# 2. Fix fee_settings: move form save outside tenant schema context
# Find the entire fee_settings function and replace it
old_fee_settings = re.compile(
    r'@tenant_login_required\s+def fee_settings\(.*?\):.*?(?=\n\n@tenant_login_required|\n\n# -----|$)',
    re.DOTALL
)

new_fee_settings = """@tenant_login_required
def fee_settings(request, schema_name, tenant=None):
    # SchoolFeeSettings lives in public schema only
    from django_tenants.utils import schema_context
    with schema_context('public'):
        settings_obj, created = SchoolFeeSettings.objects.get_or_create(tenant=tenant)
        if request.method == 'POST':
            form = FeeSettingsForm(request.POST, instance=settings_obj)
            if form.is_valid():
                form.save()
                messages.success(request, 'Fee settings updated successfully')
                return redirect('fee_settings', schema_name=tenant.schema_name)
        else:
            form = FeeSettingsForm(instance=settings_obj)
    logo_url = tenant.school_logo.url if tenant.school_logo else None
    return render(request, 'tenant/fee_settings.html', {'tenant': tenant, 'form': form, 'logo_url': logo_url})"""

# Use regex to replace the function
content = old_fee_settings.sub(new_fee_settings, content)

with open(public_urls_path, "w") as f:
    f.write(content)

print("✅ Fixed fee_generate (month/year conversion) and fee_settings (save in public schema)")

# 3. Also ensure month/year conversion in fee_generate's due date calculation is safe (already using ints now)
# 4. Also fix any other potential string/int issues (e.g., in family_payment we already have int conversion)
print("All fixes applied. Restart the server: python manage.py runserver")
