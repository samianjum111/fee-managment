#!/usr/bin/env python3
"""
Final fix for SESSION_ENGINE error.
Run: python3 fix_session.py
"""

import re
import os

# ---------- 1. Fix SESSION_ENGINE in settings.py ----------
settings_path = 'axis_saas/settings.py'
with open(settings_path, 'r') as f:
    content = f.read()

# Replace SESSION_ENGINE with correct module path (no class)
pattern = r"SESSION_ENGINE\s*=\s*['\"]([^'\"]+)['\"]"
match = re.search(pattern, content)
if match:
    old_engine = match.group(1)
    # If it contains a dot after the module, it's probably wrong
    if old_engine.count('.') >= 2 and 'PublicSchemaSessionStore' in old_engine:
        # Extract module part: axis_saas.session_backend
        module_part = '.'.join(old_engine.split('.')[:-1])
        new_engine = f"SESSION_ENGINE = '{module_part}'"
        content = re.sub(pattern, new_engine, content)
        print(f"✅ SESSION_ENGINE updated to '{module_part}'")
    else:
        print(f"ℹ️ SESSION_ENGINE is already correct: {old_engine}")
else:
    # If not found, append correct value
    content += "\nSESSION_ENGINE = 'axis_saas.session_backend'\n"
    print("✅ SESSION_ENGINE added (was missing)")

with open(settings_path, 'w') as f:
    f.write(content)

# ---------- 2. Ensure session_backend.py has SessionStore alias ----------
backend_path = 'axis_saas/session_backend.py'
with open(backend_path, 'r') as f:
    backend_content = f.read()

if 'SessionStore = PublicSchemaSessionStore' not in backend_content:
    # Add at the end
    with open(backend_path, 'a') as f:
        f.write('\n\n# Alias for Django\'s session engine\nSessionStore = PublicSchemaSessionStore\n')
    print("✅ Added SessionStore alias to session_backend.py")
else:
    print("ℹ️ SessionStore alias already exists.")

# ---------- 3. Remove any conflicting custom_session.py ----------
# It's not causing the error, but we can rename it to avoid confusion
custom_session = 'axis_saas/custom_session.py'
if os.path.exists(custom_session):
    os.rename(custom_session, custom_session + '.bak')
    print(f"✅ Renamed {custom_session} to .bak to avoid confusion")

print("\n✨ Patcher finished. Now run:")
print("   python3 manage.py runserver")
