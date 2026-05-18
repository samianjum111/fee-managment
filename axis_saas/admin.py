from django.contrib import admin
from django_tenants.admin import TenantAdminMixin
from django import forms
from django.utils.safestring import mark_safe
from django.core.exceptions import ValidationError
from .models import SchoolClient


class TenantOnlyAdminMixin:
    def has_module_permission(self, request):
        return request.tenant.schema_name != 'public'
    def has_view_permission(self, request, obj=None):
        return request.tenant.schema_name != 'public'
    def has_add_permission(self, request):
        return request.tenant.schema_name != 'public'
    def has_change_permission(self, request, obj=None):
        return request.tenant.schema_name != 'public'
    def has_delete_permission(self, request, obj=None):
        return request.tenant.schema_name != 'public'

class PublicOnlyAdminMixin:
    def has_module_permission(self, request):
        return request.tenant.schema_name == 'public'
    def has_view_permission(self, request, obj=None):
        return request.tenant.schema_name == 'public'

    def get_queryset(self, request):
        # Explicitly filters out the 'public' master tenant row from the display matrix
        qs = super().get_queryset(request)
        return qs.exclude(schema_name='public')
    def has_add_permission(self, request):
        return request.tenant.schema_name == 'public'
    def has_change_permission(self, request, obj=None):
        return request.tenant.schema_name == 'public'
    def has_delete_permission(self, request, obj=None):
        return request.tenant.schema_name == 'public'

class SchoolClientForm(forms.ModelForm):
    class Meta:
        model = SchoolClient
        fields = ['name', 'schema_name', 'admin_username', 'admin_password', 'is_active']
        widgets = {
            'admin_password': forms.PasswordInput(render_value=True),
        }

    def clean_schema_name(self):
        schema = self.cleaned_data.get('schema_name')
        if self.instance.pk and self.instance.schema_name == 'public' and schema != 'public':
            raise ValidationError("CRITICAL ERROR: The core public operational schema token cannot be renamed.")
        return schema

@admin.register(SchoolClient)
class SchoolClientAdmin(TenantAdminMixin, admin.ModelAdmin):
    form = SchoolClientForm
    list_display = ('name', 'schema_name', 'admin_username', 'is_active', 'created_on', 'get_admin_url_link')
    readonly_fields = ('school_admin_portal_url',)
    
    fieldsets = (
        ('Master Identity Matrix', {
            'fields': ('name', 'schema_name', 'is_active')
        }),
        ('Dynamic Sub-Tenant Authority Provisioning', {
            'fields': ('admin_username', 'admin_password'),
        }),
        ('Generated Access Routes', {
            'fields': ('school_admin_portal_url',),
            'description': 'Once saved, the system automatically builds the exact landing gate link for this school node below.'
        }),
    )

    def get_readonly_fields(self, request, obj=None):
        # If modifying the absolute root 'public' schema, lock the fields down to prevent human errors
        if obj and obj.schema_name == 'public':
            return self.readonly_fields + ('schema_name', 'admin_username', 'is_active')
        return self.readonly_fields

    def has_delete_permission(self, request, obj=None):
        # ABSOLUTE KILL SWITCH BLOCK: Completely bars the system from ever deleting the public master node via GUI
        if obj and obj.schema_name == 'public':
            return False
        return request.tenant.schema_name == 'public'

    def school_admin_portal_url(self, obj):
        if obj.pk and obj.schema_name != 'public':
            target_url = f"http://{obj.schema_name}.localhost:8000/admin/"
            return mark_safe(f'<a href="{target_url}" target="_blank" style="background: #10b981; color: white; padding: 8px 16px; border-radius: 6px; text-decoration: none; font-weight: bold; display: inline-block;">🚀 Open {obj.name} Admin Panel</a>')
        return "Link will be generated automatically after you click Save below."
    
    school_admin_portal_url.short_description = "Direct Admin Access Gate"

    def get_admin_url_link(self, obj):
        if obj.schema_name != 'public':
            target_url = f"http://{obj.schema_name}.localhost:8000/admin/"
            return mark_safe(f'<a href="{target_url}" target="_blank" style="color: #38bdf8; font-weight: bold;">Open Portal</a>')
        return "MASTER NODE"
    get_admin_url_link.short_description = "Quick Portal Link"

    def has_module_permission(self, request):
        return request.tenant.schema_name == 'public'

    def has_view_permission(self, request, obj=None):
        return request.tenant.schema_name == 'public'

    def get_queryset(self, request):
        # Explicitly filters out the 'public' master tenant row from the display matrix
        qs = super().get_queryset(request)
        return qs.exclude(schema_name='public')


# --- AXIS Student Registry Injection ---
from .models import Student

@admin.register(Student)
class StudentAdmin(TenantOnlyAdminMixin, admin.ModelAdmin):
    list_display = ('roll_number', 'name', 'grade', 'section', 'status', 'enrolled_on')
    list_filter = ('grade', 'section', 'status', 'gender')
    search_fields = ('name', 'roll_number', 'father_name', 'father_cnic')
    ordering = ('-enrolled_on',)
    
    readonly_fields = ('display_student_fee',)

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
    display_student_fee.short_description = "Active Monthly Fee Structure"
    
    def get_readonly_fields(self, request, obj=None):
        base_fields = list(self.readonly_fields)
        if obj:
            base_fields.append('roll_number')
        return tuple(base_fields)

# --- AXIS Fee Structure Registry Injection ---
from .models import FeeStructure

@admin.register(FeeStructure)
class FeeStructureAdmin(TenantOnlyAdminMixin, admin.ModelAdmin):
    list_display = ('grade', 'monthly_fee', 'updated_at')
    search_fields = ('grade',)
