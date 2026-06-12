#!/usr/bin/env python3
"""Single patcher for school fee + stock upgrades."""

from pathlib import Path
import json

BASE = Path('/workspaces/fee-managment')
VIEWS = BASE / 'axis_saas' / 'views.py'
FEE_TEMPLATE = BASE / 'templates' / 'tenant' / 'fee_collection.html'
STUDENT_TEMPLATE = BASE / 'templates' / 'tenant' / 'student_profile.html'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f'{label} not found')
    return text.replace(old, new, 1)


def patch_views(path: Path) -> None:
    text = path.read_text(encoding='utf-8')

    import_old = "from .models import SchoolClient, Student, FeeStructure, FeeRecord, PaymentTransaction, SchoolFeeSettings\n"
    import_new = "from .models import SchoolClient, Student, FeeStructure, FeeRecord, PaymentTransaction, SchoolFeeSettings, Product, ProductCategory\n"
    if 'Product, ProductCategory' not in text:
        text = replace_once(text, import_old, import_new, 'model import block')

    old_post = """        # Handle POST payment (works for both list and student views)
        if request.method == 'POST':
            student_id_post = request.POST.get('student_id')
            amount = request.POST.get('amount')
            payment_mode = request.POST.get('payment_mode')
            remarks = request.POST.get('remarks', '')
            product_items_raw = request.POST.get('product_items_json', '[]')
            try:
                product_items = json.loads(product_items_raw or '[]')
            except Exception:
                product_items = []
            if student_id_post and amount:
                try:
                    student = Student.objects.get(id=student_id_post)
                    amount = Decimal(amount)
                    pending_records = student.fee_records.filter(status__in=['pending', 'partial', 'overdue']).order_by('due_date')
                    total_pending = sum(r.remaining for r in pending_records)
                    if amount > total_pending:
                        messages.error(request, f\"Amount exceeds total pending (₹{total_pending})\")
                        return redirect('fee_collection', schema_name=schema_name, student_id=student.id)
                    remaining = amount
                    paid_records = []
                    for record in pending_records:
                        if remaining <= 0:
                            break
                        due = record.remaining
                        if remaining >= due:
                            record.paid_amount = record.amount
                            remaining -= due
                        else:
                            record.paid_amount += remaining
                            remaining = 0
                        record.save()
                        paid_records.append(record)
                    payment = PaymentTransaction.objects.create(
                        student=student,
                        amount=amount,
                        payment_mode=payment_mode,
                        payment_type='full' if remaining == 0 else 'partial',
                        remarks=remarks,
                        created_by=request.session.get('school_admin_username', 'admin')
                    )
                    payment.fee_records.set(paid_records)
                    messages.success(request, f\"Payment of ₹{amount} received. Receipt: {payment.receipt_number}\")
                    return redirect('fee_receipt', schema_name=schema_name, receipt_id=payment.id)
                except Student.DoesNotExist:
                    messages.error(request, \"Student not found\")
                except Exception as e:
                    messages.error(request, f\"Error processing payment: {str(e)}\")
            else:
                messages.error(request, \"Invalid payment data\")
            return redirect('fee_collection', schema_name=schema_name)
"""

    new_post = """        # Handle POST payment (works for both list and student views)
        if request.method == 'POST':
            student_id_post = request.POST.get('student_id')
            amount = request.POST.get('amount')
            payment_mode = request.POST.get('payment_mode')
            remarks = request.POST.get('remarks', '')
            product_items_raw = request.POST.get('product_items_json', '[]')
            try:
                product_items = json.loads(product_items_raw or '[]')
            except Exception:
                product_items = []
            if student_id_post and amount:
                try:
                    student = Student.objects.get(id=student_id_post)
                    amount = Decimal(amount)

                    product_total = Decimal('0.00')
                    item_breakdown = []
                    for item in product_items:
                        try:
                            product_id = int(item.get('product_id'))
                            qty = int(item.get('quantity', 0))
                        except (TypeError, ValueError):
                            continue
                        if qty <= 0:
                            continue

                        product = Product.objects.filter(id=product_id).first()
                        if not product:
                            raise ValueError(f\"Product {product_id} not found\")
                        if product.quantity < qty:
                            raise ValueError(f\"Only {product.quantity} units available for {product.name}\")

                        line_total = product.selling_price * qty
                        product_total += line_total
                        item_breakdown.append((product, qty, line_total))

                    pending_records = student.fee_records.filter(status__in=['pending', 'partial', 'overdue']).order_by('due_date')
                    total_pending = sum(r.remaining for r in pending_records)
                    fee_allocation = amount - product_total
                    if fee_allocation < 0:
                        messages.error(request, 'The entered amount is less than the selected item total.')
                        return redirect('fee_collection', schema_name=schema_name, student_id=student.id)
                    if fee_allocation > total_pending:
                        fee_allocation = total_pending

                    remaining = fee_allocation
                    paid_records = []
                    for record in pending_records:
                        if remaining <= 0:
                            break
                        due = record.remaining
                        if remaining >= due:
                            record.paid_amount = record.amount
                            remaining -= due
                        else:
                            record.paid_amount += remaining
                            remaining = 0
                        record.save()
                        paid_records.append(record)

                    item_note = ''
                    if item_breakdown:
                        item_note = 'Items sold: ' + '; '.join([
                            f\"{product.name} x{qty} @ ₹{product.selling_price} = ₹{line_total}\"
                            for product, qty, line_total in item_breakdown
                        ])
                        if remarks:
                            item_note = f\"{remarks}\n{item_note}\"

                    payment = PaymentTransaction.objects.create(
                        student=student,
                        amount=amount,
                        payment_mode=payment_mode,
                        payment_type='full' if fee_allocation >= total_pending else 'partial',
                        remarks=item_note or remarks or 'Fee collection',
                        created_by=request.session.get('school_admin_username', 'admin')
                    )
                    payment.fee_records.set(paid_records)

                    for product, qty, _ in item_breakdown:
                        product.quantity -= qty
                        product.save(update_fields=['quantity'])

                    messages.success(request, f\"Payment of ₹{amount} received. Receipt: {payment.receipt_number}\")
                    if item_breakdown:
                        messages.info(request, f\"Stock updated for {len(item_breakdown)} selected item(s).\")
                    return redirect('fee_receipt', schema_name=schema_name, receipt_id=payment.id)
                except Student.DoesNotExist:
                    messages.error(request, 'Student not found')
                except Exception as e:
                    messages.error(request, f'Error processing payment: {str(e)}')
            else:
                messages.error(request, 'Invalid payment data')
            return redirect('fee_collection', schema_name=schema_name)
"""

    if 'product_items_raw = request.POST.get' not in text:
        text = replace_once(text, old_post, new_post, 'fee_collection POST block')

    context_old = """        total_payments_count = PaymentTransaction.objects.count()
        recent_payments = list(PaymentTransaction.objects.select_related('student').order_by('-payment_date')[:5])
        grades = list(Student.objects.values_list('grade', flat=True).distinct().order_by('grade'))
        sections = list(Student.objects.values_list('section', flat=True).distinct().order_by('section'))
"""
    context_new = """        total_payments_count = PaymentTransaction.objects.count()
        recent_payments = list(PaymentTransaction.objects.select_related('student').order_by('-payment_date')[:5])
        grades = list(Student.objects.values_list('grade', flat=True).distinct().order_by('grade'))
        sections = list(Student.objects.values_list('section', flat=True).distinct().order_by('section'))
        products = list(Product.objects.select_related('category').filter(quantity__gt=0).order_by('category__name', 'name'))
        categories = list(ProductCategory.objects.all().order_by('name'))
"""
    if 'products = list(Product.objects.select_related' not in text:
        text = replace_once(text, context_old, context_new, 'fee_collection context block')

    context_dict_old = """            'grades': grades,
            'sections': sections,
            'search_filter': search_filter,
"""
    context_dict_new = """            'grades': grades,
            'sections': sections,
            'products': products,
            'categories': categories,
            'search_filter': search_filter,
"""
    if "'products': products" not in text:
        text = replace_once(text, context_dict_old, context_dict_new, 'context dictionary update')

    path.write_text(text, encoding='utf-8')


def patch_student_api(path: Path) -> None:
    text = path.read_text(encoding='utf-8')
    old = """                'mode': p.get_payment_mode_display(),
                'url': f'/portal/{schema_name}/fee/receipt/{p.id}/'
"""
    new = """                'mode': p.get_payment_mode_display(),
                'remarks': p.remarks or '',
                'url': f'/portal/{schema_name}/fee/receipt/{p.id}/'
"""
    if "'remarks': p.remarks or ''" not in text:
        text = replace_once(text, old, new, 'student_payments_api payload')
    path.write_text(text, encoding='utf-8')


def patch_templates(fee_template: Path, student_template: Path) -> None:
    fee_text = fee_template.read_text(encoding='utf-8')
    if 'School Items & Add-on Products' not in fee_text:
        marker = "<!-- Students with Pending Fees (Filtered & Paginated) -->\n<div class=\"students-list-card\">"
        insert = """<div class=\"students-list-card\" style=\"margin-top: 1rem;\">\n  <div class=\"card-header\">\n    <svg width=\"20\" height=\"20\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\"><path d=\"M20 7h-4.18A3 3 0 0016 5.18V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v1.18A3 3 0 008.18 7H4a2 2 0 00-2 2v10a2 2 0 002 2h16a2 2 0 002-2V9a2 2 0 00-2-2z\"/><path d=\"M12 12v4m-2-2h4\"/></svg>\n    <h3>School Items & Add-on Products</h3>\n  </div>\n  <p class=\"page-desc\">Select available stock items while collecting fees. Stock quantities reduce automatically on checkout.</p>\n  <div class=\"item-grid\">\n    {% for product in products %}\n      <article class=\"item-card\" data-product-id=\"{{ product.id }}\" data-name=\"{{ product.name }}\" data-price=\"{{ product.selling_price }}\" data-qty=\"{{ product.quantity }}\">\n        <div class=\"item-chip\">{{ product.category.name }}</div>\n        <h4>{{ product.name }}</h4>\n        <p class=\"item-meta\">Price: ₹{{ product.selling_price|floatformat:2 }} • Stock: {{ product.quantity }}</p>\n        <p class=\"item-meta\">{{ product.notes|default:'No notes provided.' }}</p>\n        <button type=\"button\" class=\"btn-mini add-item-btn\">Add to cart</button>\n      </article>\n    {% empty %}\n      <div class=\"empty-row\">No stock items yet. Add products in Stock Management first.</div>\n    {% endfor %}\n  </div>\n  <div class=\"cart-box\">\n    <div class=\"card-header\" style=\"padding: 0 0 0.35rem 0; border: none; background: transparent;\"><h3 style=\"font-size: 1rem; margin: 0;\">Selected Items</h3><span id=\"cartCount\" class=\"pill-badge\">0 items</span></div>\n    <div id=\"cartItems\" class=\"cart-items\">No items selected yet.</div>\n    <div class=\"cart-total\">Item Total: ₹<span id=\"cartTotal\">0.00</span></div>\n  </div>\n</div>\n\n"""
        fee_text = fee_text.replace(marker, insert + marker, 1)

    if 'product_items_json' not in fee_text:
        fee_text = replace_once(
            fee_text,
            '        <input type="hidden" name="student_id" value="{{ selected_student.id }}">\n',
            '        <input type="hidden" name="student_id" value="{{ selected_student.id }}">\n        <input type="hidden" name="product_items_json" id="productItemsJson" value="[]">\n',
            'fee form hidden input',
        )

    if 'Selected Items' not in fee_text:
        fee_text = replace_once(
            fee_text,
            '            <div class="form-field">\n                <label>Remaining After Payment</label>\n                <input type="text" id="remainingAfter" readonly placeholder="Will be calculated">\n            </div>\n',
            '            <div class="form-field">\n                <label>Remaining After Payment</label>\n                <input type="text" id="remainingAfter" readonly placeholder="Will be calculated">\n            </div>\n            <div class="form-field">\n                <label>Selected Items</label>\n                <div class="pill-badge" id="feeItemSummary">₹0.00</div>\n            </div>\n',
            'item summary field',
        )

    if '.item-grid' not in fee_text:
        fee_text = replace_once(
            fee_text,
            '.current-page { padding: 0.3rem 0.8rem; background: var(--primary); color: white; border-radius: 2rem; }\n</style>',
            '.current-page { padding: 0.3rem 0.8rem; background: var(--primary); color: white; border-radius: 2rem; }\n.item-grid { display:grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 1rem; }\n.item-card { background: var(--surface-alt); border: 1px solid var(--border); border-radius: var(--radius); padding: 0.9rem; }\n.item-chip { display:inline-flex; padding:0.25rem 0.5rem; border-radius:999px; background: rgba(59,130,246,0.12); color: var(--primary); font-size: .75rem; font-weight: 700; text-transform: uppercase; }\n.item-card h4 { margin: 0.35rem 0; font-size: 1rem; }\n.item-meta { color: var(--muted); font-size: .86rem; line-height: 1.3; }\n.btn-mini { border:none; border-radius:999px; background: var(--primary); color:white; padding: 0.35rem 0.75rem; cursor:pointer; font-size: .85rem; }\n.cart-box { margin-top: 1rem; padding: 1rem; border: 1px solid var(--border); border-radius: var(--radius); background: var(--surface-alt); }\n.cart-item { display:flex; justify-content:space-between; align-items:center; gap:0.6rem; padding:0.35rem 0; border-bottom:1px dashed var(--border); }\n.cart-actions { display:flex; align-items:center; gap:0.35rem; }\n.cart-actions button { border:1px solid var(--border); border-radius:999px; background: var(--surface); color: var(--text); cursor:pointer; width:1.7rem; height:1.7rem; }\n.pill-badge { display:inline-flex; align-items:center; padding:0.25rem 0.6rem; border-radius:999px; background: rgba(14,165,233,0.12); color: var(--primary); font-size: .78rem; font-weight: 700; }\n.cart-total { text-align:right; margin-top:0.5rem; font-weight:700; color: var(--primary); }\n</style>',
            'CSS injection for item grid',
        )

    if 'const itemCart = {};' not in fee_text:
        fee_text = replace_once(
            fee_text,
            'console.log(\'FeeCollection Debug:\', {\n    recentPaymentsCount: {{ recent_payments|length }},\n    totalPaymentsCount: {{ total_payments_count|default:0 }},\n    pendingTotal: {{ total_pending_all|default:0 }},\n    currentTenantSchema: \'{{ tenant.schema_name }}\'\n});\n',
            'console.log(\'FeeCollection Debug:\', {\n    recentPaymentsCount: {{ recent_payments|length }},\n    totalPaymentsCount: {{ total_payments_count|default:0 }},\n    pendingTotal: {{ total_pending_all|default:0 }},\n    currentTenantSchema: \'{{ tenant.schema_name }}\'\n});\nconst itemCart = {};\nfunction formatMoney(v) { return \'₹\' + Number(v).toFixed(2); }\nfunction syncItemCart(){const cartItems=document.getElementById(\'cartItems\');const cartCount=document.getElementById(\'cartCount\');const cartTotal=document.getElementById(\'cartTotal\');const feeItemSummary=document.getElementById(\'feeItemSummary\');const productItemsJson=document.getElementById(\'productItemsJson\');const entries=Object.values(itemCart);if(!entries.length){cartItems.innerHTML=\'No items selected yet.\';cartCount.textContent=\'0 items\';cartTotal.textContent=\'0.00\';feeItemSummary.textContent=\'₹0.00\';productItemsJson.value=\'[]\';return;}let total=0;let html=\'\';entries.forEach(e=>{total += e.price*e.qty; html += \'<div class=\\\"cart-item\\\"><div><strong>\' + e.name + \'</strong><br><small>\' + e.qty + \' × ₹\' + e.price.toFixed(2) + \'</small></div><div class=\\\"cart-actions\\\"><button type=\\\"button\\\" onclick=\\\"changeCartQty(\' + e.id + \' , -1)\\\">-</button><strong>\'+e.qty+\'</strong><button type=\\\"button\\\" onclick=\\\"changeCartQty(\' + e.id + \' , 1)\\\">+</button><button type=\\\"button\\\" onclick=\\\"removeFromCart(\' + e.id + \' )\\\" style=\\\"width:auto;padding: 0 0.4rem;\\\">×</button></div></div>\';});cartItems.innerHTML=html;cartCount.textContent=entries.length + \' item(s)\';cartTotal.textContent=total.toFixed(2);feeItemSummary.textContent=formatMoney(total);productItemsJson.value=JSON.stringify(entries.map(e=>({product_id:e.id,quantity:e.qty})));}\nfunction addToCart(id){const card=document.querySelector(\'.item-card[data-product-id=\\\"\' + id + \'\\\"]\');if(!card)return;const entry=itemCart[id] || {id, name: card.dataset.name, price:Number(card.dataset.price), qty:0};if(entry.qty >= Number(card.dataset.qty)){alert(\'No more stock available for this item.\');return;}entry.qty += 1;itemCart[id]=entry;syncItemCart();}\nfunction changeCartQty(id,delta){const entry=itemCart[id];if(!entry)return;entry.qty += delta;if(entry.qty <= 0) delete itemCart[id];syncItemCart();}\nfunction removeFromCart(id){delete itemCart[id];syncItemCart();}\ndocument.querySelectorAll(\'.add-item-btn\').forEach(btn=>{btn.addEventListener(\'click\',()=>{const card=btn.closest(\'.item-card\');if(card) addToCart(Number(card.dataset.productId));});});\n',
            'item cart logic injection',
        )

    fee_template.write_text(fee_text, encoding='utf-8')

    student_text = student_template.read_text(encoding='utf-8')
    if 'Item Purchases' not in student_text:
        student_text = replace_once(
            student_text,
            '        <table class="data-table" id="paymentTable">',
            '        <div class="table-card">\n            <h3 class="section-title">Item Purchases</h3>\n            <p class="page-desc">This panel shows item-related charges captured during fee collection.</p>\n            <div id="itemPurchaseSummary" class="empty-row">No item purchases yet.</div>\n        </div>\n\n        <table class="data-table" id="paymentTable">',
            'student profile summary panel',
        )
    student_template.write_text(student_text, encoding='utf-8')


if __name__ == '__main__':
    patch_views(VIEWS)
    patch_student_api(VIEWS)
    patch_templates(FEE_TEMPLATE, STUDENT_TEMPLATE)
    print('Patcher applied successfully.')
