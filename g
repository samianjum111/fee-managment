#!/usr/bin/env python3
"""
Patcher for gym attendance time display:
- Converts UTC datetime fields to local timezone (Asia/Karachi) before formatting.
- Affects gym_attendance_data_api, gym_checkin_api, gym_edit_attendance (GET).
"""

import re
import os

VIEWS_FILE = "axis_saas/views.py"

def patch_attendance_time_display():
    with open(VIEWS_FILE, "r") as f:
        content = f.read()

    # Helper function to format local time
    # We'll add a small helper at the top of the file if not present
    if "def local_time_str(dt):" not in content:
        local_time_func = """
def local_time_str(dt):
    \"\"\"Convert aware datetime to local timezone and return formatted time string.\"\"\"
    if not dt:
        return ''
    from django.utils import timezone
    local = timezone.localtime(dt)
    return local.strftime('%H:%M')
"""
        # Insert after the imports section (after the last import)
        # Find a suitable place: after the last 'from ... import ...' line
        lines = content.split('\n')
        insert_idx = 0
        for i, line in enumerate(lines):
            if line.startswith('from ') or line.startswith('import '):
                insert_idx = i + 1
        lines.insert(insert_idx, local_time_func)
        content = '\n'.join(lines)
        print("✅ Added local_time_str helper function.")
    else:
        print("local_time_str already exists.")

    # Patch gym_attendance_data_api
    # Find the section where check_in_time and check_out_time are set
    # In gym_attendance_data_api, we have:
    # 'check_in_time': a.check_in.strftime('%H:%M'),
    # 'check_out_time': a.check_out.strftime('%H:%M'),
    pattern = r"(check_in_time': a\.check_in\.strftime\('%H:%M'\))"
    replacement = r"check_in_time': local_time_str(a.check_in)"
    content = re.sub(pattern, replacement, content)

    pattern = r"(check_out_time': a\.check_out\.strftime\('%H:%M'\))"
    replacement = r"check_out_time': local_time_str(a.check_out)"
    content = re.sub(pattern, replacement, content)

    # Also in active list: 'check_in_time': a.check_in.strftime('%H:%M'),
    pattern = r"('check_in_time': a\.check_in\.strftime\('%H:%M'\)[,\n])"
    replacement = r"'check_in_time': local_time_str(a.check_in),"
    content = re.sub(pattern, replacement, content)

    # Patch gym_checkin_api
    # In gym_checkin_api, we have: 'check_in_time': attendance.check_in.strftime('%H:%M'),
    pattern = r"('check_in_time': attendance\.check_in\.strftime\('%H:%M'\))"
    replacement = r"'check_in_time': local_time_str(attendance.check_in)"
    content = re.sub(pattern, replacement, content)

    # Patch gym_edit_attendance GET response (sends ISO strings; keep as is because JS Date handles UTC)
    # No change needed, but ensure that check_in/check_out are sent as ISO strings (they already are).

    # Also patch the history duration calculation: if duration_minutes is stored, it's fine.

    # Write back
    with open(VIEWS_FILE, "w") as f:
        f.write(content)
    print("✅ Patched time display to use local timezone.")
    return True

def main():
    if not os.path.exists(VIEWS_FILE):
        print(f"Error: {VIEWS_FILE} not found. Run script from project root.")
        return

    patch_attendance_time_display()
    print("\n🎉 Timezone fix applied! Restart Django server.")
    print("Now check-in/out times will display correctly in local time (Asia/Karachi).")

if __name__ == "__main__":
    main()
