#!/usr/bin/env python3
"""
AXIS School System – Final Sell Separately Patcher
This script adds the missing URL pattern for sell_separately and ensures everything works.
Run: python3 fix_sell_separately_final.py
"""

import os
import re

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PUBLIC_URLS = os.path.join(BASE_DIR, "axis_saas", "public_urls.py")
VIEWS_FILE = os.path.join(BASE_DIR, "axis_saas", "views.py")
STOCK_TEMPLATE = os.path.join(BASE_DIR, "templates", "tenant", "stock_management.html")
SELL_TEMPLATE = os.path.join(BASE_DIR, "templates", "tenant", "sell_separately.html")


def add_url_pattern():
    """Add the sell_separately route to public_urls.py."""
    with open(PUBLIC_URLS, "r") as f:
        content = f.read()

    # Check if already present
    if "name='sell_separately'" in content:
        print("✅ URL pattern already exists.")
        return True

    # Find the end of urlpatterns list (last ']')
    # We'll insert the new route before the final ']'
    # First, locate the line that contains 'urlpatterns = ['
    start_idx = content.find("urlpatterns = [")
    if start_idx == -1:
        print("❌ Could not find urlpatterns list.")
        return False

    # Find the matching closing bracket. We'll count brackets from start_idx.
    bracket_count = 0
    end_idx = start_idx
    for i, ch in enumerate(content[start_idx:], start=start_idx):
        if ch == '[':
            bracket_count += 1
        elif ch == ']':
            bracket_count -= 1
            if bracket_count == 0:
                end_idx = i
                break
    else:
        print("❌ Could not find closing ']' for urlpatterns.")
        return False

    # Insert the new route before the closing ']'
    new_route = (
        "\n    # ===== SELL SEPARATELY (standalone student search) =====\n"
        "    path('portal/<slug:schema_name>/sell/', portal_wrapper(login_required_for_schema(sell_separately)), name='sell_separately'),\n"
    )
    content = content[:end_idx] + new_route + content[end_idx:]

    # Also ensure the import for sell_separately exists in the from .views import ... line
    import_line_pattern = r"from \.views import (.*)"
    match = re.search(import_line_pattern, content)
    if match:
        current_imports = match.group(1)
        if "sell_separately" not in current_imports:
            # Add it to the end of the imports
            new_imports = current_imports.rstrip() + ", sell_separately"
            content = content.replace(current_imports, new_imports)
            print("✅ Added sell_separately to import line.")
    else:
        # If not found, add a new import line after other imports (safer)
        # Find a good place (after other from .views import)
        if "from .views import" in content:
            content = content.replace(
                "from .views import",
                "from .views import sell_separately, "
            )
            print("✅ Added sell_separately to import line (fallback).")
        else:
            print("⚠️ Could not update imports; view may still work if already imported elsewhere.")

    with open(PUBLIC_URLS, "w") as f:
        f.write(content)
    print("✅ URL pattern added successfully.")
    return True


def ensure_view_exists():
    """Check if sell_separately view is in views.py; if not, add it."""
    with open(VIEWS_FILE, "r") as f:
        content = f.read()

    if "def sell_separately" in content:
        print("✅ View already exists.")
        return True

    # Append the view at the end of the file
    view_code = """

# ==================== SELL SEPARATELY (standalone student search) ====================
@require_tenant_type(['school'])
def sell_separately(request, schema_name):
    \"\"\"Page to search for a student and then redirect to fee collection for that student.\"\"\"
    tenant = get_tenant(request, schema_name)
    search_query = request.GET.get('search', '').strip()
    grade_filter = request.GET.get('grade', '')
    section_filter = request.GET.get('section', '')
    search_results = []

    with schema_context(schema_name):
        if search_query:
            students = Student.objects.filter(
                Q(name__icontains=search_query) |
                Q(roll_number__icontains=search_query) |
                Q(father_name__icontains=search_query) |
                Q(father_cnic__icontains=search_query) |
                Q(parent_mobile__icontains=search_query)
            )
            if grade_filter:
                students = students.filter(grade=grade_filter)
            if section_filter:
                students = students.filter(section=section_filter)
            search_results = list(students.order_by('name')[:20])

        grades = Student.objects.values_list('grade', flat=True).distinct().order_by('grade')
        sections = Student.objects.values_list('section', flat=True).distinct().order_by('section')

    context = {
        'tenant': tenant,
        'search_query': search_query,
        'grade_filter': grade_filter,
        'section_filter': section_filter,
        'search_results': search_results,
        'grades': grades,
        'sections': sections,
        'logo_url': tenant.school_logo.url if tenant.school_logo else None,
    }
    return render(request, 'tenant/sell_separately.html', context)
"""
    with open(VIEWS_FILE, "a") as f:
        f.write(view_code)
    print("✅ Added sell_separately view to views.py.")
    return True


def ensure_template_exists():
    """Create sell_separately.html if missing."""
    if os.path.exists(SELL_TEMPLATE):
        print("✅ sell_separately.html already exists.")
        return True

    template_content = """{% extends 'tenant/base.html' %}
{% block title %}Sell Separately | {{ tenant.name }}{% endblock %}

{% block body %}
<div class="page-header">
    <div>
        <h1 class="page-title">Sell Separately</h1>
        <p class="page-desc">Search for a student to sell items (fee optional)</p>
    </div>
    <div class="header-actions">
        <a href="{% url 'stock_management' schema_name=tenant.schema_name %}" class="btn-secondary">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6"/></svg>
            Back to Stock
        </a>
    </div>
</div>

<div class="search-card">
    <form method="get" class="search-form">
        <div class="form-group full-width">
            <label>Search Student</label>
            <input type="text" name="search" value="{{ search_query }}" placeholder="Name, Roll No, Father Name, CNIC, Phone" class="search-input">
        </div>
        <div class="form-group">
            <label>Grade</label>
            <select name="grade" class="filter-select">
                <option value="">All</option>
                {% for g in grades %}
                <option value="{{ g }}" {% if grade_filter == g %}selected{% endif %}>{{ g }}</option>
                {% endfor %}
            </select>
        </div>
        <div class="form-group">
            <label>Section</label>
            <select name="section" class="filter-select">
                <option value="">All</option>
                {% for s in sections %}
                <option value="{{ s }}" {% if section_filter == s %}selected{% endif %}>{{ s }}</option>
                {% endfor %}
            </select>
        </div>
        <div class="form-actions">
            <button type="submit" class="btn-primary">Search</button>
            {% if search_query or grade_filter or section_filter %}
            <a href="{% url 'sell_separately' schema_name=tenant.schema_name %}" class="btn-secondary">Clear</a>
            {% endif %}
        </div>
    </form>
</div>

{% if search_results %}
<div class="results-card">
    <h3>{{ search_results|length }} student(s) found</h3>
    <div class="student-grid">
        {% for s in search_results %}
        <div class="student-card">
            <div class="student-info">
                <div class="student-name">{{ s.name }}</div>
                <div class="student-meta">Roll: {{ s.roll_number }} | {{ s.grade }} - {{ s.section }}</div>
                <div class="student-meta">Father: {{ s.father_name }} | CNIC: {{ s.father_cnic }}</div>
                <div class="student-meta">Phone: {{ s.parent_mobile }}</div>
            </div>
            <div class="student-action">
                <a href="{% url 'fee_collection' schema_name=tenant.schema_name student_id=s.id %}" class="btn-primary">
                    Select & Collect Payment
                </a>
            </div>
        </div>
        {% endfor %}
    </div>
</div>
{% elif search_query %}
<div class="empty-row">No students match your search.</div>
{% else %}
<div class="info-card">
    <div class="info-icon">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="10"/>
            <path d="M12 16v-4M12 8h.01"/>
        </svg>
    </div>
    <div class="info-text">
        Search for a student using name, roll number, father's name, CNIC or phone number.
        After selecting, you will be taken to the fee collection page where you can add items,
        include pending fees, and process payment.
    </div>
</div>
{% endif %}

<style>
.page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.5rem;
    flex-wrap: wrap;
    gap: 1rem;
}
.page-title {
    font-size: 1.8rem;
    font-weight: 700;
    background: linear-gradient(135deg, var(--primary), var(--primary-dark));
    -webkit-background-clip: text;
    background-clip: text;
    color: transparent;
}
.page-desc {
    color: var(--muted);
}
.search-card, .results-card, .info-card {
    background: var(--surface);
    border-radius: var(--radius);
    border: 1px solid var(--border);
    padding: 1.5rem;
    margin-bottom: 1.5rem;
}
.search-form {
    display: flex;
    flex-wrap: wrap;
    gap: 1rem;
    align-items: flex-end;
}
.form-group {
    flex: 1;
    min-width: 150px;
}
.form-group.full-width {
    flex: 100%;
}
.form-group label {
    display: block;
    font-size: 0.7rem;
    text-transform: uppercase;
    color: var(--muted);
    margin-bottom: 0.25rem;
}
.search-input, .filter-select {
    width: 100%;
    padding: 0.6rem 0.75rem;
    border-radius: 0.5rem;
    border: 1px solid var(--border);
    background: var(--surface-alt);
}
.form-actions {
    display: flex;
    gap: 0.5rem;
    align-items: center;
}
.btn-primary, .btn-secondary {
    padding: 0.5rem 1rem;
    border-radius: 2rem;
    font-weight: 600;
    text-decoration: none;
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
}
.btn-primary {
    background: var(--primary);
    color: white;
    border: none;
}
.btn-secondary {
    background: var(--surface-alt);
    color: var(--text);
    border: 1px solid var(--border);
}
.student-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
    gap: 1rem;
    margin-top: 1rem;
}
.student-card {
    background: var(--surface-alt);
    border-radius: 0.75rem;
    border: 1px solid var(--border);
    padding: 1rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 1rem;
}
.student-info {
    flex: 1;
}
.student-name {
    font-weight: 700;
    font-size: 1.1rem;
}
.student-meta {
    font-size: 0.8rem;
    color: var(--muted);
}
.empty-row {
    text-align: center;
    padding: 2rem;
    color: var(--muted);
}
.info-card {
    display: flex;
    gap: 1rem;
    align-items: center;
}
.info-icon svg {
    color: var(--primary);
}
</style>
{% endblock %}
"""
    os.makedirs(os.path.dirname(SELL_TEMPLATE), exist_ok=True)
    with open(SELL_TEMPLATE, "w") as f:
        f.write(template_content)
    print("✅ Created sell_separately.html template.")
    return True


def add_button_to_stock():
    """Ensure the 'Sell Separately' button is present in stock_management.html."""
    with open(STOCK_TEMPLATE, "r") as f:
        content = f.read()

    if "sell_separately" in content:
        print("✅ Button already exists in stock_management.html.")
        return True

    # Find the Manage Categories button and add the new button next to it
    pattern = r'(<button class="btn-primary manage-cat-btn" onclick="openCategoriesModal\(\)">\s*<svg.*?</svg>\s*Manage Categories\s*</button>)'
    if re.search(pattern, content, re.DOTALL):
        new_button = r'''\1
                <a href="{% url 'sell_separately' schema_name=tenant.schema_name %}" class="btn-primary manage-cat-btn" style="margin-left: 10px; background: #10b981;">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2z"/></svg>
                    Sell Separately
                </a>'''
        content = re.sub(pattern, new_button, content, flags=re.DOTALL)
    else:
        # Fallback: insert after the page-header div
        pattern_header = r'(<div class="page-header">.*?</div>)'
        if re.search(pattern_header, content, re.DOTALL):
            content = re.sub(pattern_header, r'\1\n                <a href="{% url \'sell_separately\' schema_name=tenant.schema_name %}" class="btn-primary" style="background: #10b981;">Sell Separately</a>', content, flags=re.DOTALL)
            print("✅ Button added using fallback method.")
        else:
            print("⚠️ Could not find location to add button. Please add manually.")
            return False

    with open(STOCK_TEMPLATE, "w") as f:
        f.write(content)
    print("✅ Button added to stock_management.html.")
    return True


def main():
    print("🔧 AXIS School System – Final 'Sell Separately' Patcher")
    print("=" * 60)
    success = True
    steps = [
        ("Adding URL pattern", add_url_pattern),
        ("Ensuring view exists", ensure_view_exists),
        ("Ensuring template exists", ensure_template_exists),
        ("Adding button to stock page", add_button_to_stock),
    ]
    for desc, func in steps:
        print(f"\n▶️ {desc}...")
        if not func():
            print(f"❌ Failed: {desc}")
            success = False
        else:
            print(f"✅ {desc} completed")
    if success:
        print("\n✨ All changes applied successfully!")
        print("👉 Restart your Django server: python manage.py runserver")
        print("👉 Then visit http://localhost:8000/portal/<your_schema>/sell/")
        print("👉 Or click 'Sell Separately' button on the Stock Management page.")
    else:
        print("\n⚠️ Some steps failed. Please check the errors and try again.")


if __name__ == "__main__":
    main()
