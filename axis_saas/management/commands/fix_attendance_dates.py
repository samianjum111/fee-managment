"""
Fix existing GymAttendance records: ensure date field matches the local date of check_in.
Run: python3 manage.py fix_attendance_dates
"""
from django.core.management.base import BaseCommand
from django_tenants.utils import schema_context
from axis_saas.models import SchoolClient, GymAttendance
from django.utils import timezone

class Command(BaseCommand):
    help = 'Fix attendance dates to match check_in local date'

    def handle(self, *args, **options):
        tenants = SchoolClient.objects.filter(is_active=True).exclude(schema_name='public')
        total_fixed = 0
        for tenant in tenants:
            self.stdout.write(f"Processing tenant: {tenant.schema_name}")
            with schema_context(tenant.schema_name):
                fixed = 0
                for att in GymAttendance.objects.all():
                    correct_date = timezone.localdate(att.check_in)
                    if att.date != correct_date:
                        att.date = correct_date
                        att.save(update_fields=['date'])
                        fixed += 1
                        self.stdout.write(f"  Fixed attendance {att.id}: {att.date} -> {correct_date}")
                total_fixed += fixed
                self.stdout.write(self.style.SUCCESS(f"Fixed {fixed} records in {tenant.schema_name}"))
        self.stdout.write(self.style.SUCCESS(f"Total fixed: {total_fixed}"))
