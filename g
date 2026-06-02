#!/usr/bin/env python3
import re
import shutil
from pathlib import Path

MODELS_PATH = Path("axis_saas/models.py")
BACKUP_PATH = MODELS_PATH.with_suffix(".py.bak")

CORRECTED_CLASS = '''class GymAttendance(models.Model):
    customer = models.ForeignKey(GymCustomer, on_delete=models.CASCADE, related_name='attendances')
    date = models.DateField(default=date.today)
    check_in = models.DateTimeField(default=timezone.now)
    check_out = models.DateTimeField(blank=True, null=True)
    notes = models.TextField(blank=True, null=True)
    updated_at = models.DateTimeField(auto_now=True)   # for edit window

    class Meta:
        unique_together = ['customer', 'date']
        ordering = ['-date', '-check_in']

    def is_editable(self):
        """Allow admin to edit any attendance record (no time limit)."""
        return True

    def __str__(self):
        return f"{self.customer.name} - {self.date} - IN:{self.check_in.strftime('%H:%M') if self.check_in else '--'}"'''

def main():
    if not MODELS_PATH.exists():
        print(f"❌ {MODELS_PATH} not found. Run this script from the project root (axis_school_sys).")
        return

    # Backup original
    shutil.copy2(MODELS_PATH, BACKUP_PATH)
    print(f"✅ Backup saved to {BACKUP_PATH}")

    with open(MODELS_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    # Find the old GymAttendance class (from "class GymAttendance" to the next class or end)
    pattern = r'(class GymAttendance\(models\.Model\):.*?)(?=\nclass |\Z)'
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        print("❌ Could not locate GymAttendance class. It may have been modified already.")
        return

    old_class = match.group(1)
    new_content = content.replace(old_class, CORRECTED_CLASS, 1)

    with open(MODELS_PATH, "w", encoding="utf-8") as f:
        f.write(new_content)

    print("✅ GymAttendance class corrected (is_editable method properly indented).")
    print("\n➡️  Restart your Django development server (Ctrl+C then python3 manage.py runserver)")

if __name__ == "__main__":
    main()
