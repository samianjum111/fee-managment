import os

patcher_code = """import os
import re

admin_path = 'axis_saas/admin.py'

if os.path.exists(admin_path):
    with open(admin_path, 'r') as f:
        content = f.read()

    # Define the new custom field inside StudentAdmin and update fieldsets
    old_fieldsets = '''    fieldsets = (
        ('Core Enrollment Records', {
            'fields': ('name', 'roll_number', 'status')
        }),
        ('Academic & Class Placement', {
            'fields': ('grade', 'section', 'admission_date')
        }),
        ('Parental & Verification Matrix', {
            'fields': ('father_name', 'father_cnic', 'parent_mobile')
        }),
        ('Demographics & Contextual Information', {
            'fields': ('gender', 'date_of_birth', 'address', 'photo', 'notes'),
            'classes': ('collapse',),
        }),
    )'''

    new_fieldsets = '''    readonly_fields = ('display_student_fee',)

    fieldsets = (
        ('Core Enrollment Records', {
            'fields': ('name', 'roll_number', 'status')
        }),
        ('Academic & Class Placement', {
            'fields': ('grade', 'section', 'admission_date')
        }),
        ('Parental & Verification Matrix', {
            'fields': ('father_name', 'father_cnic', 'parent_mobile')
        }),
        ('Financial Status Matrix', {
            'fields': ('display_student_fee', 'custom_fee'),
            'description': 'Current fee parameters loaded dynamically via matching class standard configurations.',
        }),
    )

    def display_student_fee(self, obj):
        if obj.pk:
            return f"RS {obj.custom_fee}"
        return "Will be computed based on selected class standard fee roster."
    display_student_fee.short_description = "Active Monthly Fee Structure"'''

    # Replace old fieldsets structure with the modified one
    if old_fieldsets in content:
        content = content.replace(old_fieldsets, new_fieldsets)
        
        # Adjust get_readonly_fields method to append dynamically without overwriting
        old_readonly_method = '''    def get_readonly_fields(self, request, obj=None):
        if obj:
            return self.readonly_fields + ('roll_number',)
        return self.readonly_fields'''
        
        new_readonly_method = '''    def get_readonly_fields(self, request, obj=None):
        base_fields = list(self.readonly_fields)
        if obj:
            base_fields.append('roll_number')
        return tuple(base_fields)'''
        
        content = content.replace(old_readonly_method, new_readonly_method)

        with open(admin_path, 'w') as f:
            f.write(content)
        print("✅ StudentAdmin panel successfully updated! Demographics removed, Financial Status Matrix applied.")
    else:
        print("❌ Error: Could not find matching signature inside axis_saas/admin.py. Check formatting alignment.")
else:
    print("❌ Error: axis_saas/admin.py file not found.")
"""

# Write the temporary patcher execution script
with open('patch_admin.py', 'w') as f:
    f.write(patcher_code)

# Run the python patcher to inject updates into code
os.system('python3 patch_admin.py')

# Clean up / self-destruct the patcher file to avoid terminal clutter
if os.path.exists('patch_admin.py'):
    os.remove('patch_admin.py')
