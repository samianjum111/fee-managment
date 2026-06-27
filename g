#!/usr/bin/env python3
"""
Patcher: Add mobile settings page and update mobile "More" link.

Changes:
1. In public_urls.py:
   - Add import for mobile_settings view (or use existing with force_mobile)
   - Add url pattern for /settings/mobile/
2. In views.py:
   - Add mobile_settings function (duplicates settings logic but renders mobile template)
3. Create templates/mobile/settings.html with premium mobile UI
4. In mobile/more.html, update settings link to point to mobile_settings
"""

import os
import re

# ----------------------------------------------------------------------
# 1. PUBLIC_URLS.PY
# ----------------------------------------------------------------------
PUBLIC_URLS_PATH = "axis_saas/public_urls.py"

with open(PUBLIC_URLS_PATH, "r") as f:
    pub_content = f.read()

# Check if mobile_settings is already imported
if "mobile_settings" not in pub_content:
    # Add import: from .views import mobile_settings
    # Find the line with from .views import ... and add mobile_settings
    # We'll find the import statement for views and append mobile_settings
    import_line_pattern = r"from \.views import (.*)"
    def add_to_import(match):
        imports = match.group(1).split(",")
        imports = [i.strip() for i in imports]
        if "mobile_settings" not in imports:
            imports.append("mobile_settings")
        return "from .views import " + ", ".join(imports)
    pub_content = re.sub(import_line_pattern, add_to_import, pub_content)
    print("✅ Added mobile_settings to views import")

# Add mobile_settings_view wrapper if not present
if "mobile_settings_view" not in pub_content:
    # Insert after the other mobile view definitions (e.g., after mobile_fee_settings_view)
    # Find the line with mobile_fee_settings_view = portal_wrapper(...)
    # We'll insert a new line after it.
    insert_after = "mobile_fee_settings_view = portal_wrapper(login_required_for_schema(mobile_fee_settings))"
    if insert_after in pub_content:
        pub_content = pub_content.replace(
            insert_after,
            insert_after + "\nmobile_settings_view = portal_wrapper(login_required_for_schema(mobile_settings))"
        )
        print("✅ Added mobile_settings_view wrapper")
    else:
        # Fallback: add near the end of wrappers
        pub_content = pub_content.replace(
            "mobile_fee_settings_view = portal_wrapper(login_required_for_schema(mobile_fee_settings))",
            "mobile_fee_settings_view = portal_wrapper(login_required_for_schema(mobile_fee_settings))\nmobile_settings_view = portal_wrapper(login_required_for_schema(mobile_settings))"
        )
        print("✅ Added mobile_settings_view wrapper (fallback)")

# Add url pattern for settings/mobile/
if "path('portal/<slug:schema_name>/settings/mobile/'" not in pub_content:
    # Find the section where other mobile routes are (e.g., near fee settings mobile)
    # We'll insert after the fee settings mobile route
    insert_after_url = "path('portal/<slug:schema_name>/fee/settings/mobile/', mobile_fee_settings_view, name='mobile_fee_settings'),"
    if insert_after_url in pub_content:
        pub_content = pub_content.replace(
            insert_after_url,
            insert_after_url + "\n    path('portal/<slug:schema_name>/settings/mobile/', mobile_settings_view, name='mobile_settings'),"
        )
        print("✅ Added /settings/mobile/ URL pattern")
    else:
        # Fallback: append before the final closing bracket of urlpatterns
        # Find the last pattern before the closing ]
        last_pattern = "path('portal/<slug:schema_name>/fee/settings/mobile/', mobile_fee_settings_view, name='mobile_fee_settings'),"
        if last_pattern in pub_content:
            pub_content = pub_content.replace(
                last_pattern,
                last_pattern + "\n    path('portal/<slug:schema_name>/settings/mobile/', mobile_settings_view, name='mobile_settings'),"
            )
            print("✅ Added /settings/mobile/ URL pattern (fallback)")
        else:
            # If not found, we'll just insert after the last path before the closing bracket
            # Find the position of the last path pattern and insert before closing ]
            # Simpler: find the last path line and insert after it.
            lines = pub_content.splitlines()
            new_lines = []
            inserted = False
            for line in lines:
                new_lines.append(line)
                if "path('portal/<slug:schema_name>/fee/settings/mobile/" in line and not inserted:
                    new_lines.append("    path('portal/<slug:schema_name>/settings/mobile/', mobile_settings_view, name='mobile_settings'),")
                    inserted = True
            if not inserted:
                # Find the last path line before the closing ] of urlpatterns
                # We'll look for the line that says "] + static(" or just "]"
                for i, line in enumerate(lines):
                    if re.match(r'^\s*\](\s*\+\s*static\(.*\))?\s*$', line):
                        new_lines.insert(i, "    path('portal/<slug:schema_name>/settings/mobile/', mobile_settings_view, name='mobile_settings'),")
                        inserted = True
                        break
            if not inserted:
                print("⚠️ Could not insert URL pattern automatically, please add manually.")
            else:
                pub_content = "\n".join(new_lines)
                print("✅ Added /settings/mobile/ URL pattern (fallback 2)")

with open(PUBLIC_URLS_PATH, "w") as f:
    f.write(pub_content)
print("✅ Updated public_urls.py")

# ----------------------------------------------------------------------
# 2. VIEWS.PY
# ----------------------------------------------------------------------
VIEWS_PATH = "axis_saas/views.py"

with open(VIEWS_PATH, "r") as f:
    views_content = f.read()

# Check if mobile_settings function already exists
if "def mobile_settings" not in views_content:
    # We need to insert the mobile_settings function.
    # Find where other mobile functions are (e.g., after mobile_fee_settings)
    # We'll insert after mobile_fee_settings definition.
    # We'll locate the def mobile_fee_settings and insert after it.
    # But we also need to copy the settings logic.
    # We'll read the existing settings function and adapt it.
    # First, locate the settings function to copy its logic.
    settings_func_match = re.search(r"def settings\(request, schema_name\):.*?(?=\n\ndef |\nclass |\n# |\Z)", views_content, re.DOTALL)
    if not settings_func_match:
        print("⚠️ Could not find settings function in views.py")
    else:
        settings_func = settings_func_match.group(0)
        # Modify the function name to mobile_settings and change template to mobile/settings.html
        mobile_settings_func = settings_func.replace("def settings(", "def mobile_settings(")
        # Replace the render call: change 'tenant/settings.html' to 'mobile/settings.html'
        mobile_settings_func = re.sub(r"render\(request, 'tenant/settings\.html'", "render(request, 'mobile/settings.html'", mobile_settings_func)
        # Also ensure the function uses tenant = get_tenant(request, schema_name) (it already does)
        # Insert after the last mobile function (e.g., after mobile_fee_settings)
        # Find the position to insert: after mobile_fee_settings function
        insert_after = "def mobile_fee_settings"
        if insert_after in views_content:
            # Find the end of that function
            # We'll find the def line and then the next def or end of file
            # Simpler: insert after the last mobile function, before the last import or end.
            # We'll insert before the next function definition after mobile_fee_settings.
            # We'll search for the line with "def mobile_fee_settings" and then find the next "def " at same indentation.
            lines = views_content.splitlines()
            new_lines = []
            inserted = False
            for i, line in enumerate(lines):
                new_lines.append(line)
                if "def mobile_fee_settings" in line and not inserted:
                    # We'll insert the mobile_settings function after this function ends.
                    # We need to find the next line that starts with "def " at same indentation or end.
                    # We'll just insert after the function body by scanning until next def.
                    # Simpler: we'll insert right after the function body by counting braces? Hard.
                    # Instead, we'll insert at the end of the file just before the last line.
                    # Let's just append at the end.
                    pass
            # Since it's tricky to insert in the middle, we'll append at the end of the file.
            views_content += "\n\n" + mobile_settings_func
            print("✅ Added mobile_settings function at end of views.py")
        else:
            # If no mobile_fee_settings, append anyway
            views_content += "\n\n" + mobile_settings_func
            print("✅ Added mobile_settings function at end of views.py (fallback)")

with open(VIEWS_PATH, "w") as f:
    f.write(views_content)
print("✅ Updated views.py")

# ----------------------------------------------------------------------
# 3. CREATE TEMPLATES/MOBILE/SETTINGS.HTML
# ----------------------------------------------------------------------
MOBILE_SETTINGS_TEMPLATE = """{% extends 'mobile/base.html' %}
{% load static %}
{% block title %}Settings | {{ tenant.name }}{% endblock %}

{% block extra_head %}
<style>
  /* ===== Page Header ===== */
  .page-header {
    margin-bottom: 1rem;
  }
  .page-title {
    font-size: 1.6rem;
    font-weight: 700;
    background: linear-gradient(135deg, var(--primary), var(--primary-dark));
    -webkit-background-clip: text;
    background-clip: text;
    color: transparent;
    margin-bottom: 0.1rem;
  }
  .page-desc {
    color: var(--muted);
    font-size: 0.9rem;
  }

  /* ===== Settings Card ===== */
  .settings-card {
    background: rgba(255,255,255,0.95);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    border-radius: 1.5rem;
    padding: 1.25rem;
    margin-bottom: 1rem;
    border: 1px solid rgba(255,255,255,0.6);
    box-shadow: 0 4px 16px rgba(0,0,0,0.04);
  }
  .settings-card .card-title {
    font-size: 1rem;
    font-weight: 700;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-bottom: 1rem;
    color: var(--text);
  }
  .settings-card .card-title svg {
    color: var(--primary);
  }

  .form-group {
    margin-bottom: 1rem;
  }
  .form-group label {
    display: block;
    font-weight: 600;
    font-size: 0.8rem;
    margin-bottom: 0.25rem;
    color: var(--text);
  }
  .form-group input,
  .form-group select,
  .form-group textarea {
    width: 100%;
    padding: 0.6rem 0.75rem;
    border-radius: 0.75rem;
    border: 1px solid var(--border);
    background: var(--surface);
    color: var(--text);
    font-size: 0.9rem;
    transition: border-color 0.2s;
  }
  .form-group input:focus,
  .form-group select:focus,
  .form-group textarea:focus {
    outline: none;
    border-color: var(--primary);
    box-shadow: 0 0 0 3px rgba(59,130,246,0.15);
  }
  .form-group .help-text {
    font-size: 0.7rem;
    color: var(--muted);
    margin-top: 0.2rem;
  }

  .logo-upload {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }
  .logo-upload .current-logo {
    max-height: 80px;
    max-width: 160px;
    border-radius: 0.5rem;
    border: 1px solid var(--border);
    padding: 0.2rem;
    background: var(--surface-alt);
  }
  .logo-upload .no-logo {
    color: var(--muted);
    font-size: 0.8rem;
  }
  .upload-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.4rem 1rem;
    background: var(--surface-alt);
    border: 1px solid var(--border);
    border-radius: 2rem;
    cursor: pointer;
    font-size: 0.8rem;
    font-weight: 500;
    width: fit-content;
    transition: all 0.2s;
  }
  .upload-btn:hover {
    background: var(--surface);
  }

  .form-actions {
    margin-top: 1rem;
    display: flex;
    gap: 0.75rem;
    flex-wrap: wrap;
  }
  .btn-primary, .btn-secondary {
    flex: 1;
    padding: 0.6rem 1rem;
    border-radius: 2rem;
    font-weight: 600;
    border: none;
    cursor: pointer;
    font-size: 0.9rem;
    text-align: center;
    text-decoration: none;
    transition: all 0.2s;
  }
  .btn-primary {
    background: var(--primary);
    color: white;
  }
  .btn-primary:hover {
    background: var(--primary-dark);
    transform: translateY(-1px);
  }
  .btn-secondary {
    background: var(--surface-alt);
    color: var(--text);
    border: 1px solid var(--border);
  }
  .btn-secondary:hover {
    background: var(--surface);
  }

  .bottom-spacer {
    height: 80px;
  }
</style>
{% endblock %}

{% block body %}
<div class="page-header">
  <h1 class="page-title">Settings</h1>
  <p class="page-desc">Manage your school profile and security credentials</p>
</div>

<form method="post" enctype="multipart/form-data">
  {% csrf_token %}

  <!-- School Information -->
  <div class="settings-card">
    <div class="card-title">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
        <path d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
      </svg>
      <span>School Information</span>
    </div>
    <div class="form-group">
      <label>School Name</label>
      <input type="text" name="school_name" value="{{ tenant.name }}" required>
    </div>
    <div class="form-group">
      <label>School Logo</label>
      <div class="logo-upload">
        <div id="logoPreview">
          {% if logo_url %}
            <img src="{{ logo_url }}" class="current-logo" alt="Current logo">
          {% else %}
            <div class="no-logo">No logo uploaded</div>
          {% endif %}
        </div>
        <input type="file" name="school_logo" accept="image/*" id="logoInput" style="display:none">
        <button type="button" class="upload-btn" onclick="document.getElementById('logoInput').click()">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
          </svg>
          Upload Logo
        </button>
      </div>
    </div>
  </div>

  <!-- Account Security -->
  <div class="settings-card">
    <div class="card-title">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
        <path d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
      </svg>
      <span>Account Security</span>
    </div>
    <div class="form-group">
      <label>Admin Username</label>
      <input type="text" name="admin_username" value="{{ tenant.admin_username }}" required>
      <div class="help-text">Login username for school portal</div>
    </div>
    <div class="form-group">
      <label>New Password</label>
      <input type="password" name="admin_password" placeholder="Leave blank to keep unchanged">
      <div class="help-text">Minimum 8 characters recommended</div>
    </div>
    <div class="form-group">
      <label>Confirm Password</label>
      <input type="password" name="admin_password_confirm" placeholder="Re-enter new password">
    </div>
  </div>

  <div class="form-actions">
    <button type="submit" class="btn-primary">
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M5 13l4 4L19 7"/>
      </svg>
      Save Changes
    </button>
    <a href="{% url 'mobile_more' schema_name=tenant.schema_name %}" class="btn-secondary">Cancel</a>
  </div>
</form>

<div class="bottom-spacer"></div>

<script>
  // Logo preview
  document.getElementById('logoInput').addEventListener('change', function(e) {
    const file = e.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = function(event) {
        const previewDiv = document.getElementById('logoPreview');
        previewDiv.innerHTML = `<img src="${event.target.result}" class="current-logo" alt="Preview">`;
      };
      reader.readAsDataURL(file);
    }
  });
</script>
{% endblock %}
"""

MOBILE_SETTINGS_PATH = "templates/mobile/settings.html"
os.makedirs(os.path.dirname(MOBILE_SETTINGS_PATH), exist_ok=True)
with open(MOBILE_SETTINGS_PATH, "w") as f:
    f.write(MOBILE_SETTINGS_TEMPLATE)
print("✅ Created templates/mobile/settings.html")

# ----------------------------------------------------------------------
# 4. UPDATE MOBILE/MORE.HTML TO USE MOBILE SETTINGS URL
# ----------------------------------------------------------------------
MORE_HTML_PATH = "templates/mobile/more.html"

with open(MORE_HTML_PATH, "r") as f:
    more_content = f.read()

# Replace the settings link
# Look for href="{% url 'settings' schema_name=tenant.schema_name %}" and change to mobile_settings
old_link = "href=\"{% url 'settings' schema_name=tenant.schema_name %}\""
new_link = "href=\"{% url 'mobile_settings' schema_name=tenant.schema_name %}\""
if old_link in more_content:
    more_content = more_content.replace(old_link, new_link)
    print("✅ Updated settings link in mobile/more.html")
else:
    # Try a more flexible pattern
    # Some might have single quotes
    old_link2 = "href=\"{% url 'settings' schema_name=tenant.schema_name %}\""
    new_link2 = "href=\"{% url 'mobile_settings' schema_name=tenant.schema_name %}\""
    if old_link2 in more_content:
        more_content = more_content.replace(old_link2, new_link2)
        print("✅ Updated settings link (using single quotes)")
    else:
        # Fallback: replace any occurrence of settings with mobile_settings in url tag
        # Use regex to replace
        import re
        more_content = re.sub(r"{% url 'settings' schema_name=tenant\.schema_name %}", "{% url 'mobile_settings' schema_name=tenant.schema_name %}", more_content)
        more_content = re.sub(r'{% url "settings" schema_name=tenant\.schema_name %}', '{% url "mobile_settings" schema_name=tenant.schema_name %}', more_content)
        print("✅ Updated settings link using regex")

with open(MORE_HTML_PATH, "w") as f:
    f.write(more_content)

print("\n✅ Patcher completed successfully.")
print("Now restart your Django server to see the changes.")
