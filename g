#!/usr/bin/env python3
"""
Patcher: Improve mobile dashboard per feedback.
- Remove "Mobile" badge from hero card.
- Add receipt view button (eye) to recent payments.
- Show father name, grade, section for defaulters.
"""

DASHBOARD_HTML = "templates/mobile/dashboard.html"

with open(DASHBOARD_HTML, "r") as f:
    content = f.read()

# 1. Remove the "Mobile" span from hero card
content = content.replace(
    '<span style="background:rgba(255,255,255,0.15);padding:0.2rem 0.7rem;border-radius:999px;font-size:0.7rem;font-weight:600;backdrop-filter:blur(4px);">Mobile</span>',
    ''
)

# 2. Update recent payment rows to include a receipt icon
# Find the activity-row block and add a view link
# We'll replace the entire activity-row generation block
old_recent_block = '''      <div class="activity-row">
        <div class="info">
          <div class="name">{{ p.student.name }}</div>
          <div class="meta">{{ p.receipt_number }} • {{ p.payment_date|date:"d MMM" }}</div>
        </div>
        <div class="amount">₹{{ p.amount|floatformat:2 }}</div>
      </div>'''

new_recent_block = '''      <div class="activity-row">
        <div class="info">
          <div class="name">{{ p.student.name }}</div>
          <div class="meta">{{ p.receipt_number }} • {{ p.payment_date|date:"d MMM" }}</div>
        </div>
        <div style="display:flex;align-items:center;gap:0.4rem;">
          <div class="amount">₹{{ p.amount|floatformat:2 }}</div>
          <a href="{% url 'mobile_fee_receipt' schema_name=tenant.schema_name receipt_id=p.id %}" class="action-link" title="View receipt">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/></svg>
          </a>
        </div>
      </div>'''

content = content.replace(old_recent_block, new_recent_block)

# 3. Update defaulter rows to include father name and full class/section
old_defaulter_block = '''      <div class="defaulter-row">
        <div class="defaulter-info">
          <div class="name">{{ d.student.name }}</div>
          <div class="meta">{{ d.student.grade }} • {{ d.student.section }}</div>
        </div>
        <div class="defaulter-amount">₹{{ d.pending|floatformat:2 }}</div>
        <a href="{% url 'mobile_student_profile' schema_name=tenant.schema_name student_id=d.student.id %}" class="action-link" title="View profile">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/></svg>
        </a>
      </div>'''

new_defaulter_block = '''      <div class="defaulter-row">
        <div class="defaulter-info">
          <div class="name">{{ d.student.name }}</div>
          <div class="meta">{{ d.student.father_name }} • {{ d.student.grade }} - {{ d.student.section }}</div>
        </div>
        <div style="display:flex;align-items:center;gap:0.4rem;">
          <div class="defaulter-amount">₹{{ d.pending|floatformat:2 }}</div>
          <a href="{% url 'mobile_student_profile' schema_name=tenant.schema_name student_id=d.student.id %}" class="action-link" title="View profile">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/></svg>
          </a>
        </div>
      </div>'''

content = content.replace(old_defaulter_block, new_defaulter_block)

with open(DASHBOARD_HTML, "w") as f:
    f.write(content)

print("✅ Mobile dashboard updated:")
print("   - Removed 'Mobile' badge.")
print("   - Added receipt view icon to each recent payment.")
print("   - Defaulter rows now show father name, grade, and section.")
print("Restart server to see changes.")
