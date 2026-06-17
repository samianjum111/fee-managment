#!/usr/bin/env python3
import re
import os

VIEWS_PATH = "axis_saas/views.py"

with open(VIEWS_PATH, "r") as f:
    content = f.read()

# Replace the fee_receipt function with improved version
pattern = r'(def fee_receipt\(request, schema_name, receipt_id\):.*?)(?=\n\s*def |\Z)'
match = re.search(pattern, content, re.DOTALL)
if not match:
    print("❌ fee_receipt function not found")
    exit(1)

old_func = match.group(1)

new_func = """def fee_receipt(request, schema_name, receipt_id):
    tenant = get_tenant(request, schema_name)
    with schema_context(schema_name):
        payment = get_object_or_404(PaymentTransaction.objects.select_related('student'), id=receipt_id)
        fee_records = list(payment.fee_records.all())
        item_details = _extract_item_sales_from_remarks(payment.remarks or '')
        
        # ---- IMPROVED: total pending fee before payment = sum of amounts of linked fee records ----
        total_pending_before = sum(fr.amount for fr in fee_records)
        total_items_cost = sum(item['line_total'] for item in item_details) if item_details else Decimal('0')
        total_paid = payment.amount
        # Remaining after this payment = total_pending_before + total_items_cost - total_paid
        remaining = (total_pending_before + total_items_cost) - total_paid
        if remaining < 0:
            remaining = Decimal('0')
        
        context = {
            'tenant': tenant,
            'payment': payment,
            'fee_records': fee_records,
            'item_details': item_details,
            'has_fee': bool(fee_records),
            'has_items': bool(item_details),
            'logo_url': tenant.school_logo.url if tenant.school_logo else None,
            # summary
            'total_fee_paid': total_pending_before,  # this is the fee amount covered by this payment
            'total_items_cost': total_items_cost,
            'total_paid': total_paid,
            'total_pending_before': total_pending_before,
            'remaining': remaining,
            'payment_mode_display': payment.get_payment_mode_display(),
            'payment_type_display': payment.payment_type,
        }
    return render(request, 'tenant/receipt.html', context)"""

content = content.replace(old_func, new_func)

with open(VIEWS_PATH, "w") as f:
    f.write(content)

print("✅ fee_receipt patched – total_pending_before now computed from linked fee records.")
print("Restart server: python manage.py runserver")
