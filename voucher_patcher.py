#!/usr/bin/env python3
"""
AXIS SCHOOL SYSTEM - PREMIUM VOUCHER FEATURE PATCHER
Adds a complete Fee Voucher generation, editing, and viewing system to Student Profiles.
"""
import os
import re

def patch_models():
    path = "axis_saas/models.py"
    with open(path, "r") as f:
        content = f.read()
    
    modified = False
    # Add to Student
    if "default_extra_charges" not in content:
        content = content.replace(
            "enrolled_on = models.DateTimeField(auto_now_add=True)",
            "enrolled_on = models.DateTimeField(auto_now_add=True)\n    default_extra_charges = models.JSONField(default=list, blank=True, null=True)"
        )
        modified = True
    
    # Add to FeeRecord
    if "extra_charges = models.JSONField" not in content:
        content = content.replace(
            "remarks = models.TextField(blank=True, null=True)",
            "remarks = models.TextField(blank=True, null=True)\n    extra_charges = models.JSONField(default=list, blank=True, null=True)",
            1 
        )
        modified = True
        
    if modified:
        with open(path, "w") as f:
            f.write(content)
        print("✅ Patched models.py with Voucher fields")
    else:
        print("ℹ️ models.py already patched")

def create_migration():
    path = "axis_saas/migrations/0010_add_voucher_fields.py"
    if not os.path.exists(path):
        with open(path, "w") as f:
            f.write("""from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [
        ('axis_saas', '0009_add_school_feature_flags'),
    ]
    operations = [
        migrations.AddField(
            model_name='student',
            name='default_extra_charges',
            field=models.JSONField(blank=True, default=list, null=True),
        ),
        migrations.AddField(
            model_name='feerecord',
            name='extra_charges',
            field=models.JSONField(blank=True, default=list, null=True),
        ),
    ]
""")
        print("✅ Created migration 0010_add_voucher_fields.py")
    else:
        print("ℹ️ Migration 0010 already exists")

def patch_views():
    path = "axis_saas/views.py"
    with open(path, "r") as f:
        content = f.read()
    
    apis = """
# ==================== VOUCHER APIs ====================
@csrf_exempt
@require_http_methods(["GET"])
def student_voucher_status_api(request, schema_name, student_id):
    if not request.session.get("school_admin_authenticated"):
        return JsonResponse({"error": "Unauthorized"}, status=401)
    with schema_context(schema_name):
        student = get_object_or_404(Student, id=student_id)
        today = timezone.localdate()
        month, year = today.month, today.year
        
        total_pending = 0
        for fr in student.fee_records.all():
            if not (fr.month == month and fr.year == year):
                total_pending += float(fr.remaining)
        
        try:
            record = FeeRecord.objects.get(student=student, month=month, year=year)
            can_edit = (float(record.paid_amount) == 0)
            return JsonResponse({
                'exists': True,
                'can_edit': can_edit,
                'amount': float(record.amount),
                'charges': record.extra_charges or [],
                'total_pending': float(total_pending + float(record.remaining)),
                'student_name': student.name,
                'student_roll': student.roll_number,
                'grade': student.grade,
                'section': student.section,
                'month': month,
                'year': year,
                'due_date': record.due_date.isoformat(),
                'record_id': record.id
            })
        except FeeRecord.DoesNotExist:
            default_fee = float(student.custom_fee) if student.custom_fee > 0 else 0
            if default_fee == 0:
                fs = FeeStructure.objects.filter(grade=student.grade).first()
                if fs: default_fee = float(fs.monthly_fee)
            
            return JsonResponse({
                'exists': False,
                'default_fee': default_fee,
                'default_charges': student.default_extra_charges or [],
                'total_pending': float(total_pending),
                'student_name': student.name,
                'student_roll': student.roll_number,
                'grade': student.grade,
                'section': student.section,
                'month': month,
                'year': year,
            })

@csrf_exempt
@require_http_methods(["POST"])
def student_generate_voucher_api(request, schema_name, student_id):
    if not request.session.get("school_admin_authenticated"):
        return JsonResponse({"error": "Unauthorized"}, status=401)
    try:
        data = json.loads(request.body)
    except:
        return JsonResponse({"error": "Invalid JSON"}, status=400)
        
    custom_amount = data.get('custom_amount')
    charges = data.get('charges', [])
    save_default = data.get('save_default_charges', False)
    
    with schema_context(schema_name):
        student = get_object_or_404(Student, id=student_id)
        today = timezone.localdate()
        month, year = today.month, today.year
        
        if save_default:
            student.default_extra_charges = charges
            student.save(update_fields=['default_extra_charges'])
            
        if custom_amount not in [None, '']:
            amount = Decimal(str(custom_amount))
        else:
            amount = student.custom_fee if student.custom_fee > 0 else 0
            if amount == 0:
                fs = FeeStructure.objects.filter(grade=student.grade).first()
                if fs: amount = fs.monthly_fee
                
        settings, _ = SchoolFeeSettings.objects.get_or_create(pk=1)
        due_date = today + timedelta(days=settings.due_date_offset)
        
        record, created = FeeRecord.objects.update_or_create(
            student=student, month=month, year=year,
            defaults={'amount': amount, 'due_date': due_date, 'status': 'pending', 'extra_charges': charges}
        )
        
        total_pending = sum(float(fr.remaining) for fr in student.fee_records.all() if not (fr.month == month and fr.year == year))
        total_pending += float(record.remaining)
        
        return JsonResponse({
            'success': True,
            'voucher': {
                'receipt_number': f"V-{record.id}",
                'student_name': student.name,
                'student_roll': student.roll_number,
                'grade': student.grade,
                'section': student.section,
                'month': month,
                'year': year,
                'fee_amount': float(record.amount),
                'charges': charges,
                'total_pending': float(total_pending),
                'due_date': record.due_date.isoformat(),
                'generated_on': today.isoformat(),
                'can_edit': True
            }
        })

@csrf_exempt
@require_http_methods(["POST"])
def student_update_voucher_api(request, schema_name, student_id):
    if not request.session.get("school_admin_authenticated"):
        return JsonResponse({"error": "Unauthorized"}, status=401)
    try:
        data = json.loads(request.body)
    except:
        return JsonResponse({"error": "Invalid JSON"}, status=400)
        
    custom_amount = data.get('custom_amount')
    charges = data.get('charges', [])
    save_default = data.get('save_default_charges', False)
    
    with schema_context(schema_name):
        student = get_object_or_404(Student, id=student_id)
        today = timezone.localdate()
        month, year = today.month, today.year
        
        if save_default:
            student.default_extra_charges = charges
            student.save(update_fields=['default_extra_charges'])
            
        record = get_object_or_404(FeeRecord, student=student, month=month, year=year)
        if float(record.paid_amount) > 0:
            return JsonResponse({'error': 'Cannot edit a paid voucher'}, status=400)
            
        if custom_amount not in [None, '']:
            record.amount = Decimal(str(custom_amount))
        record.extra_charges = charges
        record.save()
        
        total_pending = sum(float(fr.remaining) for fr in student.fee_records.all() if not (fr.month == month and fr.year == year))
        total_pending += float(record.remaining)
        
        return JsonResponse({
            'success': True,
            'voucher': {
                'receipt_number': f"V-{record.id}",
                'student_name': student.name,
                'student_roll': student.roll_number,
                'grade': student.grade,
                'section': student.section,
                'month': month,
                'year': year,
                'fee_amount': float(record.amount),
                'charges': charges,
                'total_pending': float(total_pending),
                'due_date': record.due_date.isoformat(),
                'generated_on': today.isoformat(),
                'can_edit': True
            }
        })
"""
    if "student_voucher_status_api" not in content:
        content += apis
        with open(path, "w") as f:
            f.write(content)
        print("✅ Patched views.py with Voucher APIs")
    else:
        print("ℹ️ Voucher APIs already exist in views.py")

def patch_urls():
    path = "axis_saas/public_urls.py"
    with open(path, "r") as f:
        content = f.read()
    
    modified = False
    if "student_voucher_status_api" not in content:
        content = content.replace(
            "student_current_fee_status_api,",
            "student_current_fee_status_api, student_voucher_status_api, student_generate_voucher_api, student_update_voucher_api,"
        )
        modified = True
        
    if "voucher-status" not in content:
        routes = """
    # Voucher APIs
    path('portal/<slug:schema_name>/api/student/<int:student_id>/voucher-status/', portal_wrapper(login_required_for_schema(student_voucher_status_api)), name='student_voucher_status'),
    path('portal/<slug:schema_name>/api/student/<int:student_id>/generate-voucher/', portal_wrapper(login_required_for_schema(student_generate_voucher_api)), name='student_generate_voucher'),
    path('portal/<slug:schema_name>/api/student/<int:student_id>/update-voucher/', portal_wrapper(login_required_for_schema(student_update_voucher_api)), name='student_update_voucher'),
"""
        content = content.replace("urlpatterns = [", "urlpatterns = [" + routes)
        modified = True
        
    if modified:
        with open(path, "w") as f:
            f.write(content)
        print("✅ Patched public_urls.py with Voucher routes")
    else:
        print("ℹ️ Voucher routes already exist")

def patch_templates():
    # --- DESKTOP TEMPLATE ---
    desk_path = "templates/tenant/student_profile.html"
    if os.path.exists(desk_path):
        with open(desk_path, "r") as f:
            content = f.read()
            
        if "genVoucherBtn" not in content:
            # 1. Add Button
            old_actions = '<a href="{% url \'student_list\' schema_name=tenant.schema_name %}" class="btn-secondary">'
            new_actions = '''<button id="genVoucherBtn" class="btn-primary" style="background: #10b981;">
    <svg class="inline-icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M9 12h6m-6 4h6m-7 4h10a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/></svg>
    Fee Voucher
</button>
<a href="{% url 'student_list' schema_name=tenant.schema_name %}" class="btn-secondary">'''
            content = content.replace(old_actions, new_actions)
            
            # 2. Add Modals & JS before {% endblock %}
            voucher_ui = get_voucher_ui_code()
            content = content.replace("{% endblock %}", voucher_ui + "\n{% endblock %}")
            
            with open(desk_path, "w") as f:
                f.write(content)
            print("✅ Patched Desktop Student Profile Template")
        else:
            print("ℹ️ Desktop template already patched")

    # --- MOBILE TEMPLATE ---
    mob_path = "templates/mobile/student_profile.html"
    if os.path.exists(mob_path):
        with open(mob_path, "r") as f:
            content = f.read()
            
        if "genVoucherBtn" not in content:
            # 1. Add Button
            old_actions_mob = '<a href="{% url \'mobile_fee_collection\' schema_name=tenant.schema_name student_id=student.id %}" class="btn-primary">'
            new_actions_mob = '''<button id="genVoucherBtn" class="btn-primary" style="background: #10b981;">
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 12h6m-6 4h6m-7 4h10a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/></svg>
    Voucher
</button>
<a href="{% url 'mobile_fee_collection' schema_name=tenant.schema_name student_id=student.id %}" class="btn-primary">'''
            content = content.replace(old_actions_mob, new_actions_mob)
            
            # 2. Add Modals & JS before {% endblock %}
            voucher_ui = get_voucher_ui_code()
            content = content.replace("{% endblock %}", voucher_ui + "\n{% endblock %}")
            
            with open(mob_path, "w") as f:
                f.write(content)
            print("✅ Patched Mobile Student Profile Template")
        else:
            print("ℹ️ Mobile template already patched")

def get_voucher_ui_code():
    return """
<!-- ==================== VOUCHER UI ==================== -->
<style>
.voucher-receipt { padding: 1.5rem; background: var(--surface-alt); border-radius: 0.5rem; font-size: 0.9rem; line-height: 1.5; }
.voucher-receipt .receipt-header { display: flex; justify-content: space-between; border-bottom: 2px solid var(--primary); padding-bottom: 0.5rem; margin-bottom: 1rem; }
.voucher-receipt .school-name { font-size: 1.2rem; font-weight: 700; }
.voucher-receipt .receipt-no { font-family: monospace; color: var(--muted); }
.voucher-receipt .student-info { display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; background: var(--surface); padding: 0.5rem; border-radius: 0.3rem; margin-bottom: 1rem; }
.voucher-receipt .fee-details table { width: 100%; border-collapse: collapse; margin: 0.5rem 0; }
.voucher-receipt .fee-details th, .voucher-receipt .fee-details td { padding: 0.5rem; border-bottom: 1px solid var(--border); text-align: left; }
.voucher-receipt .fee-details th { background: var(--surface-alt); font-weight: 600; }
.voucher-receipt .total-row { font-weight: 700; border-top: 2px solid var(--border); }
.voucher-receipt .pending-note { margin-top: 1rem; padding: 0.5rem; background: #fef3c7; color: #92400e; border-radius: 0.3rem; font-size: 0.85rem; }
.charge-item { display: flex; gap: 0.5rem; align-items: center; margin-bottom: 0.5rem; }
.charge-item input { flex: 1; padding: 0.3rem; border-radius: 0.3rem; border: 1px solid var(--border); }
.charge-item .remove-charge { background: none; border: none; color: var(--danger); cursor: pointer; font-size: 1.2rem; }
</style>

<div id="voucherModal" class="modal" style="display:none; z-index: 2000;">
    <div class="modal-content" style="max-width: 600px;">
        <div style="display:flex; justify-content:space-between; align-items:center; border-bottom:1px solid var(--border); padding-bottom:0.5rem; margin-bottom:1rem;">
            <h3 id="voucherModalTitle">Generate Fee Voucher</h3>
            <button onclick="closeVoucherModal()" style="background:none; border:none; font-size:1.5rem; cursor:pointer;">&times;</button>
        </div>
        <div id="voucherModalBody">Loading...</div>
    </div>
</div>

<div id="voucherDisplayModal" class="modal" style="display:none; z-index: 2000;">
    <div class="modal-content" style="max-width: 600px; padding: 0;">
        <div style="display:flex; justify-content:space-between; align-items:center; padding: 1rem; border-bottom:1px solid var(--border);">
            <h3>Fee Voucher</h3>
            <div style="display:flex; gap:0.5rem; align-items:center;">
                <div style="position:relative;">
                    <button id="voucherDotsBtn" style="background:none; border:none; font-size:1.5rem; cursor:pointer; padding: 0 0.5rem;">⋮</button>
                    <div id="voucherDotsMenu" style="display:none; position:absolute; right:0; top:100%; background:var(--surface); border:1px solid var(--border); border-radius:0.5rem; box-shadow:var(--shadow); min-width:120px; z-index:10;">
                        <button id="editVoucherBtn" style="width:100%; text-align:left; padding:0.5rem 1rem; background:none; border:none; cursor:pointer;">Edit</button>
                        <button id="printVoucherBtn" style="width:100%; text-align:left; padding:0.5rem 1rem; background:none; border:none; cursor:pointer;">Print</button>
                        <button id="downloadVoucherBtn" style="width:100%; text-align:left; padding:0.5rem 1rem; background:none; border:none; cursor:pointer;">Save</button>
                    </div>
                </div>
                <button onclick="closeVoucherDisplay()" style="background:none; border:none; font-size:1.5rem; cursor:pointer;">&times;</button>
            </div>
        </div>
        <div id="voucherDisplayBody" style="padding: 1rem;"></div>
    </div>
</div>

<div id="voucherConfirmModal" class="modal" style="display:none; z-index: 3000;">
    <div class="modal-content" style="max-width: 400px; text-align:center;">
        <h3 style="margin-bottom:1rem;">Confirm Action</h3>
        <p id="voucherConfirmMsg">Are you sure?</p>
        <div style="display:flex; gap:1rem; justify-content:center; margin-top:1.5rem;">
            <button id="voucherConfirmCancel" class="btn-secondary">Cancel</button>
            <button id="voucherConfirmOk" class="btn-primary" style="background:#10b981;">Confirm</button>
        </div>
    </div>
</div>

<script>
// --- Voucher Logic ---
const voucherModal = document.getElementById('voucherModal');
const voucherDisplayModal = document.getElementById('voucherDisplayModal');
const voucherConfirmModal = document.getElementById('voucherConfirmModal');
let currentStudentId = {{ student.id }};
let currentSchema = '{{ tenant.schema_name }}';

document.getElementById('genVoucherBtn').addEventListener('click', () => openVoucherModal());

function openVoucherModal() {
    voucherModal.style.display = 'flex';
    document.getElementById('voucherModalBody').innerHTML = 'Loading...';
    loadVoucherStatus();
}
function closeVoucherModal() { voucherModal.style.display = 'none'; }
function closeVoucherDisplay() { voucherDisplayModal.style.display = 'none'; }

async function loadVoucherStatus() {
    try {
        const resp = await fetch(`/portal/${currentSchema}/api/student/${currentStudentId}/voucher-status/`);
        const data = await resp.json();
        if (data.exists) {
            if (!data.can_edit) {
                showVoucherDisplay(data);
                closeVoucherModal();
            } else {
                showVoucherForm(data, true);
            }
        } else {
            showVoucherForm(data, false);
        }
    } catch (e) { alert('Error loading status: ' + e.message); closeVoucherModal(); }
}

function showVoucherForm(data, isEdit) {
    document.getElementById('voucherModalTitle').innerText = isEdit ? 'Edit Fee Voucher' : 'Generate Fee Voucher';
    let html = `<div class="voucher-form">`;
    html += `<p><strong>Student:</strong> ${data.student_name} (${data.student_roll})</p>`;
    html += `<p><strong>Grade:</strong> ${data.grade} - ${data.section}</p>`;
    
    let defaultFee = isEdit ? data.amount : data.default_fee;
    html += `<div class="form-field"><label>Fee Amount (₹)</label><input type="number" step="0.01" id="voucherFeeAmount" value="${defaultFee}" placeholder="Default: ${data.default_fee || 0}"></div>`;
    
    html += `<div class="form-field"><label>Additional Charges</label><div id="chargesContainer">`;
    let charges = isEdit ? data.charges : data.default_charges;
    if (!charges || charges.length === 0) charges = [{title: '', amount: ''}];
    charges.forEach((ch, idx) => {
        html += `<div class="charge-item" data-index="${idx}">
            <input type="text" class="charge-title" value="${ch.title || ''}" placeholder="Title">
            <input type="number" step="0.01" class="charge-amount" value="${ch.amount || ''}" placeholder="Amount">
            <button type="button" class="remove-charge" onclick="removeCharge(this)">&times;</button>
        </div>`;
    });
    html += `<button type="button" class="btn-secondary" onclick="addCharge()" style="margin-top:0.5rem;">+ Add Charge</button>`;
    html += `</div></div>`;
    
    html += `<div class="form-field"><label><input type="checkbox" id="saveDefaultCharges"> Save these charges for future generation</label></div>`;
    html += `<div class="form-field"><strong>Total Previous Pending:</strong> ₹${data.total_pending.toFixed(2)}</div>`;
    
    html += `<div style="display:flex; gap:1rem; justify-content:flex-end; margin-top:1rem;">
        <button type="button" class="btn-secondary" onclick="closeVoucherModal()">Cancel</button>
        <button type="button" class="btn-primary" style="background:#10b981;" id="voucherSubmitBtn">${isEdit ? 'Update' : 'Generate'}</button>
    </div>`;
    html += `</div>`;
    
    document.getElementById('voucherModalBody').innerHTML = html;
    document.getElementById('voucherSubmitBtn').addEventListener('click', () => submitVoucher(isEdit));
}

function addCharge() {
    const container = document.getElementById('chargesContainer');
    const div = document.createElement('div');
    div.className = 'charge-item';
    div.innerHTML = `<input type="text" class="charge-title" placeholder="Title"><input type="number" step="0.01" class="charge-amount" placeholder="Amount"><button type="button" class="remove-charge" onclick="removeCharge(this)">&times;</button>`;
    container.insertBefore(div, container.querySelector('button'));
}
function removeCharge(btn) { btn.closest('.charge-item').remove(); }

function getChargesFromForm() {
    const items = document.querySelectorAll('.charge-item');
    const charges = [];
    items.forEach(item => {
        const title = item.querySelector('.charge-title').value.trim();
        const amount = item.querySelector('.charge-amount').value.trim();
        if (title || amount) charges.push({ title: title || 'Unnamed', amount: parseFloat(amount) || 0 });
    });
    return charges;
}

function submitVoucher(isEdit) {
    const amount = document.getElementById('voucherFeeAmount').value;
    const charges = getChargesFromForm();
    const saveDefault = document.getElementById('saveDefaultCharges').checked;
    
    document.getElementById('voucherConfirmMsg').innerText = `Are you sure you want to ${isEdit ? 'update' : 'generate'} this fee voucher?`;
    voucherConfirmModal.style.display = 'flex';
    
    document.getElementById('voucherConfirmCancel').onclick = () => { voucherConfirmModal.style.display = 'none'; };
    document.getElementById('voucherConfirmOk').onclick = async () => {
        voucherConfirmModal.style.display = 'none';
        const payload = { custom_amount: amount ? parseFloat(amount) : null, charges: charges, save_default_charges: saveDefault };
        const url = isEdit 
            ? `/portal/${currentSchema}/api/student/${currentStudentId}/update-voucher/`
            : `/portal/${currentSchema}/api/student/${currentStudentId}/generate-voucher/`;
            
        try {
            const resp = await fetch(url, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'X-CSRFToken': getCookie('csrftoken') },
                body: JSON.stringify(payload)
            });
            const data = await resp.json();
            if (data.error) alert('Error: ' + data.error);
            else if (data.success) {
                closeVoucherModal();
                showVoucherDisplay(data.voucher);
                if (typeof loadFeeRecords === 'function') loadFeeRecords();
            }
        } catch (e) { alert('Error: ' + e.message); }
    };
}

function showVoucherDisplay(v) {
    let html = `<div class="voucher-receipt" id="voucherReceipt">`;
    html += `<div class="receipt-header"><div class="school-name">{{ tenant.name }}</div><div class="receipt-no">Voucher #${v.receipt_number}</div></div>`;
    html += `<div class="student-info">
        <div><strong>Student:</strong> ${v.student_name}</div>
        <div><strong>Roll:</strong> ${v.student_roll}</div>
        <div><strong>Grade:</strong> ${v.grade} - ${v.section}</div>
        <div><strong>Month:</strong> ${v.month}/${v.year}</div>
    </div>`;
    html += `<div class="fee-details"><table>
        <thead><tr><th>Description</th><th>Amount (₹)</th></tr></thead>
        <tbody>
            <tr><td>Monthly Fee</td><td>${v.fee_amount.toFixed(2)}</td></tr>`;
    if (v.charges && v.charges.length) {
        v.charges.forEach(ch => { html += `<tr><td>${ch.title}</td><td>${ch.amount.toFixed(2)}</td></tr>`; });
    }
    const total = v.fee_amount + v.charges.reduce((sum, ch) => sum + ch.amount, 0);
    html += `<tr class="total-row"><td><strong>Total</strong></td><td><strong>${total.toFixed(2)}</strong></td></tr>
        </tbody></table></div>`;
    if (v.total_pending > 0) {
        html += `<div class="pending-note">⚠️ Total pending (including previous months): ₹${v.total_pending.toFixed(2)}</div>`;
    }
    html += `<div style="margin-top:1rem; font-size:0.8rem; color:var(--muted);">Generated on: ${v.generated_on} | Due: ${v.due_date}</div>`;
    html += `</div>`;
    
    document.getElementById('voucherDisplayBody').innerHTML = html;
    document.getElementById('editVoucherBtn').style.display = v.can_edit ? 'block' : 'none';
    voucherDisplayModal.style.display = 'flex';
    
    document.getElementById('editVoucherBtn').onclick = () => {
        closeVoucherDisplay();
        openVoucherModal();
    };
}

document.getElementById('voucherDotsBtn').addEventListener('click', (e) => {
    e.stopPropagation();
    const menu = document.getElementById('voucherDotsMenu');
    menu.style.display = menu.style.display === 'block' ? 'none' : 'block';
});
document.addEventListener('click', () => { document.getElementById('voucherDotsMenu').style.display = 'none'; });

document.getElementById('printVoucherBtn').addEventListener('click', () => {
    const content = document.getElementById('voucherReceipt');
    const win = window.open('', '', 'width=800,height=600');
    win.document.write('<html><head><title>Voucher</title><style>body{font-family:sans-serif;padding:2rem;} table{width:100%;border-collapse:collapse;} th,td{padding:0.5rem;border:1px solid #ddd;}</style></head><body>');
    win.document.write(content.innerHTML);
    win.document.write('</body></html>');
    win.document.close();
    win.print();
});

document.getElementById('downloadVoucherBtn').addEventListener('click', () => {
    const element = document.getElementById('voucherReceipt');
    if (typeof html2canvas === 'undefined') {
        const script = document.createElement('script');
        script.src = 'https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js';
        script.onload = () => downloadVoucherImage(element);
        document.head.appendChild(script);
    } else {
        downloadVoucherImage(element);
    }
});

function downloadVoucherImage(element) {
    html2canvas(element, { scale: 2, backgroundColor: '#ffffff' }).then(canvas => {
        const link = document.createElement('a');
        link.download = 'voucher.png';
        link.href = canvas.toDataURL();
        link.click();
    });
}
</script>
"""

if __name__ == "__main__":
    print("🚀 Starting AXIS Voucher Feature Patcher...")
    patch_models()
    create_migration()
    patch_views()
    patch_urls()
    patch_templates()
    print("\n✅ ALL PATCHES APPLIED SUCCESSFULLY!")
    print("👉 Next steps:")
    print("   1. python manage.py migrate")
    print("   2. python manage.py runserver")
