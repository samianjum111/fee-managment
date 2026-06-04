#!/usr/bin/env python3
"""
Final patch for 'Generate Current Month Fee' modal.
Run: python3 fix_fee_modal_final.py
"""

import os
import re

TEMPLATE_PATH = "templates/tenant/student_profile.html"

def patch_template():
    if not os.path.exists(TEMPLATE_PATH):
        print(f"❌ {TEMPLATE_PATH} not found")
        return False

    with open(TEMPLATE_PATH, 'r') as f:
        content = f.read()

    # Find the <script> block
    script_start = content.find('<script>')
    script_end = content.find('</script>', script_start)
    if script_start == -1 or script_end == -1:
        print("❌ Could not find <script> tag")
        return False

    # The corrected script (full replacement)
    new_script = '''<script>
function getCookie(name) {
    let cookieValue = null;
    if (document.cookie && document.cookie !== '') {
        const cookies = document.cookie.split(';');
        for (let i = 0; i < cookies.length; i++) {
            const cookie = cookies[i].trim();
            if (cookie.substring(0, name.length + 1) === (name + '=')) {
                cookieValue = decodeURIComponent(cookie.substring(name.length + 1));
                break;
            }
        }
    }
    return cookieValue;
}
const csrfToken = getCookie('csrftoken');
const schema = '{{ tenant.schema_name }}';
const studentId = {{ student.id }};
console.log('[DEBUG] student_profile loaded. schema=' + schema + ', studentId=' + studentId);

async function refreshData() {
    await loadFeeRecords();
    await loadPayments();
}

async function loadFeeRecords() {
    try {
        const resp = await fetch(`/portal/${schema}/api/student/${studentId}/fee-records/`);
        if (!resp.ok) throw new Error('HTTP ' + resp.status);
        const data = await resp.json();
        const tbody = document.getElementById('feeTableBody');
        if (data.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" class="empty-row">No fee records found. Click "Generate Current Month Fee" to create.</td></tr>';
            document.getElementById('totalFee').innerText = '₹0';
            document.getElementById('totalPaid').innerText = '₹0';
            document.getElementById('pendingTotal').innerText = '₹0';
            return;
        }
        let totalFee = 0, totalPaid = 0;
        let html = '';
        for (let r of data) {
            totalFee += r.amount;
            totalPaid += r.paid_amount;
            let receiptsHtml = '';
            if (r.receipts && r.receipts.length) {
                receiptsHtml = r.receipts.map(rc => `<a href="/portal/${schema}/fee/receipt/${rc.id}/" class="receipt-link">${rc.number}</a>`).join(', ');
            } else {
                receiptsHtml = '—';
            }
            html += `<tr>
                        <td>${r.month}/${r.year}</td>
                        <td>₹${r.amount.toFixed(2)}</td>
                        <td>₹${r.paid_amount.toFixed(2)}</td>
                        <td><span class="status-badge status-${r.status.toLowerCase()}">${r.status}</span></td>
                        <td>${receiptsHtml}</td>
                     </tr>`;
        }
        tbody.innerHTML = html;
        const pending = totalFee - totalPaid;
        document.getElementById('totalFee').innerHTML = `₹${totalFee.toFixed(2)}`;
        document.getElementById('totalPaid').innerHTML = `₹${totalPaid.toFixed(2)}`;
        const pendingSpan = document.getElementById('pendingTotal');
        pendingSpan.innerHTML = `₹${pending.toFixed(2)}`;
        if (pending > 0) pendingSpan.classList.add('pending');
        else pendingSpan.classList.remove('pending');
    } catch(e) {
        console.error('Fee load error:', e);
        document.getElementById('feeTableBody').innerHTML = '<tr><td colspan="5" class="empty-row">Error loading fee records: ' + e.message + '</td></tr>';
    }
}

async function loadPayments() {
    try {
        const resp = await fetch(`/portal/${schema}/api/student/${studentId}/payments/`);
        if (!resp.ok) throw new Error('HTTP ' + resp.status);
        const data = await resp.json();
        const tbody = document.getElementById('paymentTableBody');
        if (data.length === 0) {
            tbody.innerHTML = '<tr><td colspan="4" class="empty-row">No payments recorded yet.</td></tr>';
            return;
        }
        let html = '';
        for (let p of data) {
            html += `<tr>
                        <td>${p.date}</td>
                        <td>₹${p.amount.toFixed(2)}</td>
                        <td>${p.mode}</td>
                        <td><a href="${p.url}" class="receipt-link" target="_blank">${p.receipt_number}</a></td>
                     </tr>`;
        }
        tbody.innerHTML = html;
    } catch(e) {
        console.error('Payment load error:', e);
        document.getElementById('paymentTableBody').innerHTML = '<tr><td colspan="4" class="empty-row">Error loading payment history: ' + e.message + '</td></tr>';
    }
}

// Modal elements
const modal = document.getElementById('customFeeModal');
const confirmBtn = document.getElementById('confirmFeeModalBtn');
const cancelBtn = document.getElementById('cancelFeeModalBtn');
const amountInput = document.getElementById('customFeeAmount');
const defaultFeeSpan = document.getElementById('defaultFeeDisplay');
const modalTitle = document.getElementById('modalTitle');

// Helper to get modal-actions div
function getModalActionsDiv() {
    return modal.querySelector('.modal-actions');
}

function openModal() {
    modal.style.display = 'flex';
}

function closeModal() {
    modal.style.display = 'none';
    // Remove any dynamic info div if present
    const infoDiv = document.getElementById('modalInfo');
    if (infoDiv) infoDiv.remove();
    // Ensure the custom amount input is visible again
    const amountDiv = amountInput.closest('div');
    if (amountDiv) amountDiv.style.display = 'block';
    const actionsDiv = getModalActionsDiv();
    if (actionsDiv) actionsDiv.style.display = 'flex';
}

async function getCurrentFeeStatus() {
    const url = `/portal/${schema}/api/student/${studentId}/current-fee-status/`;
    console.log('[DEBUG] Fetching current fee status from', url);
    const resp = await fetch(url);
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    return await resp.json();
}

async function showFeeModal() {
    console.log('[DEBUG] showFeeModal called');
    try {
        const status = await getCurrentFeeStatus();
        console.log('[DEBUG] Current fee status:', status);
        const defaultFee = status.default_fee !== undefined ? status.default_fee : {{ student.custom_fee|default:0 }};
        
        // Reset modal UI
        amountInput.value = '';
        modalTitle.innerText = 'Generate Current Month Fee';
        // Remove any old info div
        const oldInfo = document.getElementById('modalInfo');
        if (oldInfo) oldInfo.remove();
        // Ensure amount input div is visible
        const amountDiv = amountInput.closest('div');
        if (amountDiv) amountDiv.style.display = 'block';
        const actionsDiv = getModalActionsDiv();
        if (actionsDiv) actionsDiv.style.display = 'flex';
        
        if (status.exists) {
            if (status.paid_amount > 0) {
                // Already paid, show read-only info
                modalTitle.innerText = 'Fee Already Processed';
                const infoDiv = document.createElement('div');
                infoDiv.id = 'modalInfo';
                infoDiv.innerHTML = `<p><strong>Amount:</strong> ₹${status.amount.toFixed(2)}</p>
                                     <p><strong>Paid:</strong> ₹${status.paid_amount.toFixed(2)}</p>
                                     <p><strong>Status:</strong> ${status.status}</p>`;
                // Insert before the actions div
                if (actionsDiv) {
                    modal.querySelector('.modal-content').insertBefore(infoDiv, actionsDiv);
                } else {
                    modal.querySelector('.modal-content').appendChild(infoDiv);
                }
                if (amountDiv) amountDiv.style.display = 'none';
                if (actionsDiv) actionsDiv.style.display = 'none';
                openModal();
                return;
            } else {
                // Exists but unpaid – allow update
                modalTitle.innerText = 'Update Current Month Fee';
                defaultFeeSpan.innerText = `Current fee: ₹${status.amount.toFixed(2)} (unpaid)`;
                amountInput.placeholder = `New amount (₹) - leave empty to keep ₹${status.amount.toFixed(2)}`;
                confirmBtn.innerText = 'Update Fee';
                openModal();
                return;
            }
        } else {
            // No fee – show creation modal
            if (defaultFee === 0) {
                defaultFeeSpan.innerText = '₹0 (No fee structure set)';
                amountInput.placeholder = 'Enter custom amount';
            } else {
                defaultFeeSpan.innerText = '₹' + defaultFee.toFixed(2);
                amountInput.placeholder = 'Leave empty for default';
            }
            confirmBtn.innerText = 'Generate';
            openModal();
        }
    } catch(e) {
        console.error('Error in showFeeModal:', e);
        alert('Failed to load current fee status: ' + e.message);
    }
}

async function generateWithCustom(customAmount) {
    const btn = document.getElementById('genFeeBtn');
    btn.disabled = true;
    const originalText = btn.innerText;
    btn.innerText = 'Processing...';
    try {
        const formData = new URLSearchParams();
        formData.append('student_id', studentId);
        if (customAmount !== undefined && customAmount !== null && customAmount !== '') {
            formData.append('custom_amount', customAmount);
        }
        console.log('[DEBUG] POST /api/manual-generate-single/ with data:', formData.toString());
        const resp = await fetch('/api/manual-generate-single/', {
            method: 'POST',
            headers: { 'X-CSRFToken': csrfToken, 'Content-Type': 'application/x-www-form-urlencoded' },
            body: formData.toString()
        });
        const data = await resp.json();
        if (data.error) {
            alert('Error: ' + data.error);
        } else {
            alert(data.message);
            await refreshData();
            // Redirect to fee collection page for this student
            window.location.href = `/portal/${schema}/fee/collection/${studentId}/`;
        }
    } catch(e) {
        console.error('Generation error:', e);
        alert('Error generating fee: ' + e.message);
    } finally {
        btn.disabled = false;
        btn.innerText = originalText;
        closeModal();
    }
}

confirmBtn.onclick = function() {
    let customAmount = amountInput.value.trim();
    if (customAmount === '') {
        generateWithCustom(undefined);
    } else {
        let num = parseFloat(customAmount);
        if (isNaN(num) || num <= 0) {
            alert('Please enter a valid positive amount');
            return;
        }
        generateWithCustom(num);
    }
};
cancelBtn.onclick = closeModal;
window.onclick = function(event) {
    if (event.target === modal) closeModal();
};

// Attach click handler to generate button
const genBtn = document.getElementById('genFeeBtn');
if (genBtn) {
    genBtn.addEventListener('click', showFeeModal);
    console.log('[DEBUG] Generate button event attached');
} else {
    console.error('[ERROR] Button with id "genFeeBtn" not found!');
}

// Load initial data
loadFeeRecords();
loadPayments();
</script>'''

    # Replace the script block
    new_content = content[:script_start] + new_script + content[script_end+9:]

    with open(TEMPLATE_PATH, 'w') as f:
        f.write(new_content)

    print("✅ Fixed student_profile.html – modal now works correctly.")
    return True

if __name__ == "__main__":
    if patch_template():
        print("\n🎉 Patch applied. Refresh the student profile page and try the 'Generate Current Month Fee' button again.")
        print("   The modal should now open and function properly.")
    else:
        print("\n❌ Patch failed.")
