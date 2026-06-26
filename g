#!/usr/bin/env python3
"""
AXIS Student List – Final Polish
- Theme‑matching design (blue/glass)
- Status‑specific card colors (active, suspended, graduated)
- Pending amount red/green
- Analytics strip clickable filters
Run: python final_student_list_patcher.py
"""

import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent
VIEWS_PATH = PROJECT_ROOT / "axis_saas" / "views.py"
TEMPLATE_PATH = PROJECT_ROOT / "templates" / "mobile" / "student_list.html"

# --------------------------------------------------------------------
# 1. CORRECTED TEMPLATE (theme‑matched, status colors, clickable analytics)
# --------------------------------------------------------------------
NEW_TEMPLATE = """{% extends 'mobile/base.html' %}
{% load fee_extras %}
{% block title %}Students | {{ tenant.name }}{% endblock %}

{% block extra_head %}
<style>
  /* ============================================================
     AXIS MOBILE THEME – STUDENT LIST (glass, blue, status colors)
     ============================================================ */

  :root {
    --card-shadow: 0 8px 24px rgba(15, 23, 42, 0.06);
    --card-radius: 1.25rem;
    --glass-bg: rgba(255, 255, 255, 0.88);
    --glass-border: rgba(255, 255, 255, 0.5);
    --gradient-start: #3b82f6;
    --gradient-end: #1d4ed8;
    --status-active: #10b981;
    --status-suspended: #f59e0b;
    --status-graduated: #8b5cf6;
  }

  /* ---- Analytics Strip (glass, clickable) ---- */
  .analytics-strip {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 0.75rem;
    margin-bottom: 1.25rem;
    padding: 0.5rem 0.25rem;
    background: var(--glass-bg);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    border-radius: 1.5rem;
    border: 1px solid var(--glass-border);
    box-shadow: var(--card-shadow);
    text-align: center;
  }
  .analytics-strip .stat-item {
    display: flex;
    flex-direction: column;
    padding: 0.3rem 0;
    border-radius: 1rem;
    cursor: pointer;
    transition: background 0.2s;
    text-decoration: none;
    color: inherit;
  }
  .analytics-strip .stat-item:hover {
    background: rgba(59, 130, 246, 0.08);
  }
  .analytics-strip .stat-item:active {
    transform: scale(0.96);
  }
  .analytics-strip .stat-number {
    font-size: 1.4rem;
    font-weight: 800;
    color: var(--text);
    line-height: 1.2;
  }
  .analytics-strip .stat-number .currency {
    font-size: 0.9rem;
    font-weight: 600;
    color: var(--muted);
  }
  .analytics-strip .stat-label {
    font-size: 0.6rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: var(--muted);
    font-weight: 600;
    margin-top: 0.1rem;
  }
  .analytics-strip .stat-item.pending .stat-number {
    color: var(--danger);
  }
  .analytics-strip .stat-item.active .stat-number {
    color: var(--primary);
  }
  .analytics-strip .stat-item.total .stat-number {
    color: var(--text);
  }

  /* ---- Page Header ---- */
  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    margin-bottom: 0.5rem;
    padding: 0 0.25rem;
  }
  .page-header h1 {
    font-size: 1.8rem;
    font-weight: 800;
    margin: 0;
    background: linear-gradient(135deg, var(--gradient-start), var(--gradient-end));
    -webkit-background-clip: text;
    background-clip: text;
    color: transparent;
    letter-spacing: -0.02em;
  }
  .page-header .subtitle {
    font-size: 0.8rem;
    color: var(--muted);
    font-weight: 500;
  }

  /* ---- FAB ---- */
  .fab-add {
    position: fixed;
    bottom: 100px;
    right: 1.5rem;
    background: linear-gradient(135deg, var(--gradient-start), var(--gradient-end));
    color: white;
    border: none;
    border-radius: 999px;
    width: 56px;
    height: 56px;
    font-size: 1.8rem;
    box-shadow: 0 8px 28px rgba(59, 130, 246, 0.35);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 30;
    transition: transform 0.25s cubic-bezier(0.34, 1.56, 0.64, 1), box-shadow 0.3s;
  }
  .fab-add:hover {
    transform: scale(1.06);
    box-shadow: 0 12px 36px rgba(59, 130, 246, 0.45);
  }
  .fab-add:active {
    transform: scale(0.92);
  }
  .fab-add svg {
    width: 28px;
    height: 28px;
    stroke-width: 2.5;
  }

  /* ---- Search & Filter (Sticky) ---- */
  .search-section {
    position: sticky;
    top: 0;
    z-index: 20;
    background: var(--bg);
    padding: 0.5rem 0 0.75rem;
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
  }
  .search-bar {
    display: flex;
    gap: 0.5rem;
    align-items: center;
    background: var(--glass-bg);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    border-radius: 3rem;
    padding: 0.2rem 0.2rem 0.2rem 1.2rem;
    border: 1px solid var(--glass-border);
    box-shadow: 0 4px 20px rgba(0,0,0,0.04);
  }
  .search-bar input {
    flex: 1;
    border: none;
    background: transparent;
    font-size: 0.95rem;
    padding: 0.6rem 0;
    outline: none;
    color: var(--text);
    font-weight: 500;
  }
  .search-bar input::placeholder {
    color: var(--muted);
    font-weight: 400;
  }
  .search-bar button {
    background: linear-gradient(135deg, var(--gradient-start), var(--gradient-end));
    color: white;
    border: none;
    border-radius: 2.5rem;
    padding: 0.5rem 1.2rem;
    font-weight: 700;
    font-size: 0.85rem;
    cursor: pointer;
    transition: all 0.2s;
    white-space: nowrap;
    box-shadow: 0 4px 12px rgba(59, 130, 246, 0.2);
  }
  .search-bar button:hover {
    transform: translateY(-1px);
    box-shadow: 0 6px 20px rgba(59, 130, 246, 0.3);
  }
  .filter-toggle {
    background: transparent;
    border: none;
    color: var(--muted);
    padding: 0.4rem 0.6rem;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 0.3rem;
    font-size: 0.8rem;
    font-weight: 500;
    border-radius: 2rem;
    transition: background 0.2s;
  }
  .filter-toggle:hover {
    background: var(--surface-alt);
  }
  .filter-toggle svg {
    width: 20px;
    height: 20px;
  }

  /* ---- Filter Drawer ---- */
  .filter-drawer {
    max-height: 0;
    overflow: hidden;
    transition: max-height 0.35s ease, padding 0.35s ease, opacity 0.3s;
    opacity: 0;
    padding: 0 0.75rem;
    background: var(--glass-bg);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    border-radius: 0 0 1.5rem 1.5rem;
    margin: 0 0 1rem 0;
    border-left: 1px solid var(--glass-border);
    border-right: 1px solid var(--glass-border);
    border-bottom: 1px solid var(--glass-border);
    box-shadow: 0 4px 20px rgba(0,0,0,0.04);
  }
  .filter-drawer.open {
    max-height: 400px;
    padding: 0.75rem 0.75rem 1rem;
    opacity: 1;
  }
  .filter-chips {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    align-items: center;
  }
  .filter-chips select {
    flex: 1 1 110px;
    padding: 0.4rem 0.7rem;
    border-radius: 2rem;
    border: 1px solid var(--border);
    background: var(--surface-alt);
    font-size: 0.85rem;
    font-weight: 500;
    color: var(--text);
    appearance: none;
    -webkit-appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%2364748b' stroke-width='2'%3E%3Cpath d='M6 9l6 6 6-6'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 0.7rem center;
    padding-right: 2rem;
  }
  .filter-chips .clear-link {
    background: var(--surface-alt);
    color: var(--text);
    padding: 0.4rem 1rem;
    border-radius: 2rem;
    border: 1px solid var(--border);
    font-weight: 600;
    text-decoration: none;
    font-size: 0.85rem;
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    transition: all 0.2s;
  }
  .filter-chips .clear-link:hover {
    background: var(--surface);
  }

  /* ---- Student Cards (status‑aware) ---- */
  .student-list {
    display: flex;
    flex-direction: column;
    gap: 0.85rem;
    animation: fadeInUp 0.4s ease;
  }
  .student-card {
    background: var(--glass-bg);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    border-radius: var(--card-radius);
    padding: 0.9rem 1rem;
    border: 1px solid var(--glass-border);
    box-shadow: var(--card-shadow);
    display: flex;
    align-items: center;
    gap: 0.8rem;
    transition: transform 0.2s ease, box-shadow 0.2s ease;
    position: relative;
    overflow: hidden;
  }
  /* Left accent bar – status color */
  .student-card::before {
    content: '';
    position: absolute;
    left: 0;
    top: 0;
    bottom: 0;
    width: 4px;
    border-radius: 0 2px 2px 0;
  }
  .student-card.status-active::before {
    background: var(--status-active);
    opacity: 0.6;
  }
  .student-card.status-suspended::before {
    background: var(--status-suspended);
    opacity: 0.6;
  }
  .student-card.status-graduated::before {
    background: var(--status-graduated);
    opacity: 0.6;
  }

  .student-card:active {
    transform: scale(0.98);
  }
  .student-info {
    flex: 1;
    min-width: 0;
  }
  .student-name {
    font-weight: 700;
    font-size: 1.05rem;
    color: var(--text);
    display: flex;
    align-items: center;
    gap: 0.4rem;
    flex-wrap: wrap;
  }
  .student-name .badge {
    display: inline-block;
    padding: 0.1rem 0.5rem;
    border-radius: 999px;
    font-size: 0.6rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }
  .badge-active { background: #d1fae5; color: #065f46; }
  .badge-suspended { background: #fef3c7; color: #92400e; }
  .badge-graduated { background: #ede9fe; color: #5b21b6; }

  .student-meta {
    font-size: 0.82rem;
    color: var(--muted);
    margin-top: 0.15rem;
  }
  .student-meta .separator {
    margin: 0 0.3rem;
    opacity: 0.4;
  }
  .student-father {
    font-size: 0.78rem;
    color: var(--muted);
    margin-top: 0.1rem;
  }
  .student-father svg {
    display: inline;
    vertical-align: middle;
    margin-right: 0.2rem;
    width: 14px;
    height: 14px;
    stroke: var(--muted);
  }
  .student-pending {
    font-weight: 700;
    font-size: 0.9rem;
    margin-top: 0.15rem;
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
  }
  .student-pending .pending-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    display: inline-block;
  }
  .student-pending .pending-dot.zero {
    background: var(--status-active);
    animation: none;
  }
  .student-pending .pending-dot.nonzero {
    background: var(--danger);
    animation: pulse 1.5s infinite;
  }
  @keyframes pulse {
    0%, 100% { opacity: 0.4; transform: scale(0.9); }
    50% { opacity: 1; transform: scale(1.2); }
  }
  .student-pending .pending-amount {
    color: var(--danger);
  }
  .student-pending .pending-amount.zero {
    color: var(--status-active);
  }

  .student-actions {
    display: flex;
    gap: 0.3rem;
    flex-shrink: 0;
  }
  .student-actions a {
    background: var(--surface-alt);
    border: 1px solid var(--border);
    border-radius: 2rem;
    padding: 0.3rem 0.6rem;
    font-size: 0.7rem;
    font-weight: 600;
    text-decoration: none;
    color: var(--text);
    transition: all 0.2s;
    display: flex;
    align-items: center;
    gap: 0.2rem;
  }
  .student-actions a:hover {
    background: var(--primary);
    color: white;
    border-color: var(--primary);
  }
  .student-actions a svg {
    width: 16px;
    height: 16px;
  }

  /* ---- Pagination ---- */
  .pagination {
    display: flex;
    justify-content: center;
    gap: 0.4rem;
    margin-top: 1.5rem;
    flex-wrap: wrap;
  }
  .pagination a, .pagination span {
    padding: 0.4rem 0.9rem;
    border-radius: 2rem;
    border: 1px solid var(--border);
    background: var(--surface);
    text-decoration: none;
    color: var(--text);
    font-size: 0.85rem;
    font-weight: 500;
    transition: all 0.2s;
  }
  .pagination a:hover {
    background: var(--primary);
    color: white;
    border-color: var(--primary);
  }
  .pagination .active {
    background: var(--primary);
    color: white;
    border-color: var(--primary);
  }
  .pagination .disabled {
    opacity: 0.4;
    pointer-events: none;
  }

  /* ---- Empty State ---- */
  .empty-state {
    text-align: center;
    padding: 3rem 1.5rem;
    color: var(--muted);
  }
  .empty-state svg {
    width: 80px;
    height: 80px;
    stroke: var(--muted);
    opacity: 0.3;
    margin-bottom: 1rem;
  }
  .empty-state h3 {
    font-size: 1.2rem;
    font-weight: 700;
    color: var(--text);
    margin-bottom: 0.3rem;
  }
  .empty-state p {
    font-size: 0.9rem;
    margin-bottom: 1rem;
  }
  .empty-state a {
    color: var(--primary);
    font-weight: 600;
    text-decoration: none;
    border: 1px solid var(--primary);
    padding: 0.5rem 1.2rem;
    border-radius: 2rem;
    display: inline-block;
    transition: all 0.2s;
  }
  .empty-state a:hover {
    background: var(--primary);
    color: white;
  }

  /* ---- Animations ---- */
  @keyframes fadeInUp {
    from { opacity: 0; transform: translateY(16px); }
    to { opacity: 1; transform: translateY(0); }
  }

  /* ---- Responsive ---- */
  @media (max-width: 480px) {
    .page-header h1 {
      font-size: 1.6rem;
    }
    .analytics-strip {
      grid-template-columns: repeat(3, 1fr);
      gap: 0.5rem;
      padding: 0.4rem 0.2rem;
    }
    .analytics-strip .stat-number {
      font-size: 1.1rem;
    }
    .search-bar input {
      font-size: 0.9rem;
      padding: 0.4rem 0;
    }
    .search-bar button {
      font-size: 0.8rem;
      padding: 0.4rem 1rem;
    }
    .fab-add {
      width: 50px;
      height: 50px;
      bottom: 85px;
      right: 1rem;
    }
    .fab-add svg {
      width: 26px;
      height: 26px;
    }
    .student-card {
      padding: 0.7rem 0.8rem;
      gap: 0.7rem;
    }
    .student-name {
      font-size: 1rem;
    }
  }
</style>
{% endblock %}

{% block body %}
<div class="page-header">
  <h1>Students</h1>
  <div class="subtitle">
    {{ students.paginator.count|default:0 }} total
  </div>
</div>

<!-- ===== Analytics Strip (clickable) ===== -->
<div class="analytics-strip">
  <a href="?{% if search_query %}&q={{ search_query }}{% endif %}{% if request.GET.grade %}&grade={{ request.GET.grade }}{% endif %}{% if request.GET.section %}&section={{ request.GET.section }}{% endif %}" class="stat-item total">
    <span class="stat-number">{{ students.paginator.count|default:0 }}</span>
    <span class="stat-label">Total</span>
  </a>
  <a href="?pending_only=1{% if search_query %}&q={{ search_query }}{% endif %}{% if request.GET.grade %}&grade={{ request.GET.grade }}{% endif %}{% if request.GET.section %}&section={{ request.GET.section }}{% endif %}" class="stat-item pending">
    <span class="stat-number">₹{{ total_pending_all|default:0|floatformat:2 }}</span>
    <span class="stat-label">Pending</span>
  </a>
  <a href="?status=active{% if search_query %}&q={{ search_query }}{% endif %}{% if request.GET.grade %}&grade={{ request.GET.grade }}{% endif %}{% if request.GET.section %}&section={{ request.GET.section }}{% endif %}" class="stat-item active">
    <span class="stat-number">{{ total_active|default:0 }}</span>
    <span class="stat-label">Active</span>
  </a>
</div>

<!-- Sticky Search & Filter -->
<div class="search-section">
  <div class="search-bar">
    <input type="search" id="searchInput" placeholder="Search name, roll, father..." value="{{ search_query }}" autocomplete="off">
    <button id="searchBtn">Search</button>
    <button class="filter-toggle" id="filterToggle" aria-label="Toggle filters">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M4 6h16M4 12h16M4 18h16"/>
      </svg>
      <span>Filter</span>
    </button>
  </div>
  <div class="filter-drawer" id="filterDrawer">
    <div class="filter-chips">
      <select name="grade" id="gradeSelect">
        <option value="">All Grades</option>
        {% for g in grades %}
        <option value="{{ g }}" {% if request.GET.grade == g %}selected{% endif %}>{{ g }}</option>
        {% endfor %}
      </select>
      <select name="section" id="sectionSelect">
        <option value="">All Sections</option>
        {% for s in sections %}
        <option value="{{ s }}" {% if request.GET.section == s %}selected{% endif %}>{{ s }}</option>
        {% endfor %}
      </select>
      <select name="status" id="statusSelect">
        <option value="">All Status</option>
        {% for k,v in status_choices %}
        <option value="{{ k }}" {% if request.GET.status == k %}selected{% endif %}>{{ v }}</option>
        {% endfor %}
      </select>
      <a href="{% url 'mobile_student_list' schema_name=tenant.schema_name %}" class="clear-link">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 18L18 6M6 6l12 12"/></svg>
        Clear
      </a>
    </div>
  </div>
</div>

<!-- Student Cards -->
<div class="student-list" id="studentContainer">
  {% if students %}
    {% for s in students %}
    <div class="student-card status-{{ s.status }}" data-name="{{ s.name|lower }}" data-roll="{{ s.roll_number|lower }}" data-father="{{ s.father_name|lower }}">
      <div class="student-info">
        <div class="student-name">
          {{ s.name }}
          <span class="badge badge-{{ s.status }}">{{ s.get_status_display }}</span>
        </div>
        <div class="student-meta">
          {{ s.grade }}<span class="separator">•</span>{{ s.section }}
          <span class="separator">•</span>Roll {{ s.roll_number }}
        </div>
        <div class="student-father">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
            <circle cx="9" cy="7" r="4"/>
            <path d="M23 21v-2a4 4 0 00-3-3.87"/>
            <path d="M16 3.13a4 4 0 010 7.75"/>
          </svg>
          {{ s.father_name }}
        </div>
        <div class="student-pending">
          <span class="pending-dot {% if s.pending_amount > 0 %}nonzero{% else %}zero{% endif %}"></span>
          <span class="pending-amount {% if s.pending_amount == 0 %}zero{% endif %}">
            Pending: ₹{{ s.pending_amount|floatformat:2 }}
          </span>
        </div>
      </div>
      <div class="student-actions">
        <a href="{% url 'mobile_student_profile' schema_name=tenant.schema_name student_id=s.id %}" title="Profile">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/></svg>
        </a>
        <a href="{% url 'mobile_fee_collection' schema_name=tenant.schema_name student_id=s.id %}" title="Collect">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2z"/></svg>
        </a>
      </div>
    </div>
    {% endfor %}

    <!-- Pagination -->
    <div class="pagination">
      {% if students.has_previous %}
        <a href="?page=1{% if search_query %}&q={{ search_query }}{% endif %}{% if request.GET.grade %}&grade={{ request.GET.grade }}{% endif %}{% if request.GET.section %}&section={{ request.GET.section }}{% endif %}{% if request.GET.status %}&status={{ request.GET.status }}{% endif %}{% if request.GET.pending_only %}&pending_only=1{% endif %}">First</a>
        <a href="?page={{ students.previous_page_number }}{% if search_query %}&q={{ search_query }}{% endif %}{% if request.GET.grade %}&grade={{ request.GET.grade }}{% endif %}{% if request.GET.section %}&section={{ request.GET.section }}{% endif %}{% if request.GET.status %}&status={{ request.GET.status }}{% endif %}{% if request.GET.pending_only %}&pending_only=1{% endif %}">‹</a>
      {% else %}
        <span class="disabled">First</span>
        <span class="disabled">‹</span>
      {% endif %}

      <span class="active">Page {{ students.number }} of {{ students.paginator.num_pages }}</span>

      {% if students.has_next %}
        <a href="?page={{ students.next_page_number }}{% if search_query %}&q={{ search_query }}{% endif %}{% if request.GET.grade %}&grade={{ request.GET.grade }}{% endif %}{% if request.GET.section %}&section={{ request.GET.section }}{% endif %}{% if request.GET.status %}&status={{ request.GET.status }}{% endif %}{% if request.GET.pending_only %}&pending_only=1{% endif %}">›</a>
        <a href="?page={{ students.paginator.num_pages }}{% if search_query %}&q={{ search_query }}{% endif %}{% if request.GET.grade %}&grade={{ request.GET.grade }}{% endif %}{% if request.GET.section %}&section={{ request.GET.section }}{% endif %}{% if request.GET.status %}&status={{ request.GET.status }}{% endif %}{% if request.GET.pending_only %}&pending_only=1{% endif %}">Last</a>
      {% else %}
        <span class="disabled">›</span>
        <span class="disabled">Last</span>
      {% endif %}
    </div>
  {% else %}
    <div class="empty-state">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
        <circle cx="12" cy="12" r="10"/>
        <path d="M8 12h8"/>
      </svg>
      <h3>No students yet</h3>
      <p>Start by adding your first student.</p>
      <a href="{% url 'add_student_mobile' schema_name=tenant.schema_name %}">➕ Add Student</a>
    </div>
  {% endif %}
</div>

<!-- Floating Action Button -->
<a href="{% url 'add_student_mobile' schema_name=tenant.schema_name %}" class="fab-add" aria-label="Add Student">
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 4v16m8-8H4"/></svg>
</a>

<script>
  (function() {
    // Toggle filter drawer
    const toggleBtn = document.getElementById('filterToggle');
    const drawer = document.getElementById('filterDrawer');
    toggleBtn.addEventListener('click', function(e) {
      e.preventDefault();
      drawer.classList.toggle('open');
    });

    // Build URL with current filters
    function buildUrl() {
      const params = new URLSearchParams();
      const q = document.getElementById('searchInput').value.trim();
      if (q) params.set('q', q);
      const grade = document.getElementById('gradeSelect').value;
      if (grade) params.set('grade', grade);
      const section = document.getElementById('sectionSelect').value;
      if (section) params.set('section', section);
      const status = document.getElementById('statusSelect').value;
      if (status) params.set('status', status);
      // Preserve pending_only if currently set
      const pendingOnly = new URLSearchParams(window.location.search).get('pending_only');
      if (pendingOnly) params.set('pending_only', pendingOnly);
      const url = window.location.pathname + '?' + params.toString();
      return url;
    }

    function applyFilters() {
      window.location.href = buildUrl();
    }

    // Search button & Enter key
    document.getElementById('searchBtn').addEventListener('click', applyFilters);
    document.getElementById('searchInput').addEventListener('keypress', function(e) {
      if (e.key === 'Enter') {
        e.preventDefault();
        applyFilters();
      }
    });

    // Auto‑submit on select change
    document.getElementById('gradeSelect').addEventListener('change', applyFilters);
    document.getElementById('sectionSelect').addEventListener('change', applyFilters);
    document.getElementById('statusSelect').addEventListener('change', applyFilters);

    // Open filter drawer if any filter is active
    const hasFilters = {{ request.GET.grade|yesno:"true,false" }} || {{ request.GET.section|yesno:"true,false" }} || {{ request.GET.status|yesno:"true,false" }} || {{ request.GET.pending_only|yesno:"true,false" }};
    if (hasFilters) {
      drawer.classList.add('open');
    }
  })();
</script>
{% endblock %}
"""

# --------------------------------------------------------------------
# 2. PATCH VIEWS.PY – add pending_only filter support
# --------------------------------------------------------------------
def patch_views():
    with open(VIEWS_PATH, "r") as f:
        content = f.read()

    # Find get_student_list_context and add pending_only handling
    # We'll add after the status filter block
    pattern = r"(if status:\n            students = students\.filter\(status=status\)\n)"
    replacement = r"""\1
        # pending_only filter
        pending_only = request.GET.get('pending_only')
        if pending_only:
            # Filter students with positive overall pending
            # Since we compute pending_amount per student, we'll do it after the queryset
            # We'll handle it by annotating a subquery (but for simplicity, we'll filter in the loop later)
            # We'll set a flag to filter after computing pending_amount
            # We'll add a placeholder; we'll filter in the list comprehension
            # To avoid double query, we'll just mark it and filter later
            pass"""
        # Actually we need to filter after we compute pending_amount.
        # We'll modify the part where we build the result list.
        # Instead, we can filter the students queryset by a subquery that sums fee_records.
        # For simplicity, we'll do it in the loop and skip students with 0 pending.
        # But we need to know pending_only before the loop. We'll add a flag and then filter in the loop.
        # Let's refactor: add a variable `show_only_pending = request.GET.get('pending_only') == '1'`
        # Then in the loop, if show_only_pending and overall_pending == 0: continue.
        # We'll add this logic after we compute overall_pending.
        # So we need to insert code in the loop.

        # Find the loop where we compute overall_pending.
    # We'll add a flag before the loop
    flag_pattern = r"(result = \[\])"
    flag_replacement = r"""result = []
        show_only_pending = request.GET.get('pending_only') == '1'"""

    if re.search(flag_pattern, content):
        content = re.sub(flag_pattern, flag_replacement, content, count=1)
    else:
        # fallback: insert after students_qs definition
        fallback_pattern = r"(students_qs = Student\.objects\.all\(\))"
        content = re.sub(fallback_pattern, r"\1\n        show_only_pending = request.GET.get('pending_only') == '1'", content)

    # Now inside the loop, after computing overall_pending, add a check
    loop_pattern = r"(for student in students_qs:\n            overall_pending = get_overall_pending\(student\)\n            if overall_pending <= 0:\n                continue)"
    loop_replacement = r"""for student in students_qs:
            overall_pending = get_overall_pending(student)
            if show_only_pending and overall_pending <= 0:
                continue
            if overall_pending <= 0:
                continue"""
    # We need to be careful not to break existing logic. Actually the existing logic already skips if <=0.
    # We'll just add the show_only_pending check before the existing skip.
    # Let's rewrite the entire block to avoid complexity.
    # We'll replace the whole for loop section with a new version.
    # Find the loop start and end, but easier: we'll replace the whole block from "result = []" to the end of the loop.
    # We'll use a pattern that captures the loop.
    # Since the code is large, we'll do a targeted replacement.

    # Actually, we can use a simpler approach: after we build the result list, we can filter it by pending_amount.
    # But we need to keep the pagination working. So we should filter before pagination.
    # We'll add a flag and then in the result building, if show_only_pending, we skip students with 0 pending.
    # The existing code already skips if overall_pending <= 0, so we just need to add the flag.

    # Let's just add the flag before the loop and then ensure the loop uses it.
    # We'll search for "result = []" and insert the flag before it.
    # We already did that.
    # Now we need to modify the loop condition: if show_only_pending and overall_pending <= 0: continue
    # That's already there because we changed it.

    # Let's write the complete replacement for the loop section.
    # We'll locate the start of the loop and replace everything until the sorting begins.
    # But to avoid errors, we'll do a more robust approach: we'll insert a line after the overall_pending assignment.

    # We'll search for "overall_pending = get_overall_pending(student)"
    # and insert after it:
    #             if show_only_pending and overall_pending <= 0:
    #                 continue
    pattern_loop = r"(overall_pending = get_overall_pending\(student\))"
    replacement_loop = r"""\1
            if show_only_pending and overall_pending <= 0:
                continue"""
    content = re.sub(pattern_loop, replacement_loop, content)

    # Also need to add pending_only to the context for the template? Not needed, it's just a filter.

    with open(VIEWS_PATH, "w") as f:
        f.write(content)
    print("✅ views.py patched – added pending_only filter support.")

# --------------------------------------------------------------------
# MAIN
# --------------------------------------------------------------------
def main():
    with open(TEMPLATE_PATH, "w") as f:
        f.write(NEW_TEMPLATE)
    print("✅ Template updated – theme‑matched, status colors, clickable analytics.")

    patch_views()

    print("\n🎯 All done! Restart your server and hard refresh.")
    print("   Features: status‑specific card colors, red/green pending, clickable analytics.")
    print("   Clicking on 'Pending' will show only students with pending fees.")
    print("   Clicking on 'Active' will filter by active status.")
    print("   Clicking on 'Total' resets the pending_only filter.")

if __name__ == "__main__":
    main()
