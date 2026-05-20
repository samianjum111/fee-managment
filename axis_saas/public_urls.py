from django.contrib import admin, messages
from django.urls import path
from django.http import HttpResponse, HttpResponseNotFound
from django.shortcuts import redirect, render, get_object_or_404
from django.conf import settings
from django.conf.urls.static import static
from django import forms
from axis_saas.models import SchoolClient
from .models import Student
from .tenant_views import StudentAdmissionForm
from django.db.models import Q
from django_tenants.utils import schema_context

# ----------------------------------------------------------------------
# DECORATOR: ensures user is logged into the correct tenant schema
# ----------------------------------------------------------------------
def tenant_login_required(view_func):
    def wrapper(request, schema_name, *args, **kwargs):
        tenant = get_school_tenant(schema_name)
        if not tenant:
            return HttpResponseNotFound('School not found')
        if not request.session.get('school_admin_authenticated') or \
           request.session.get('school_admin_schema') != tenant.schema_name:
            request.session.pop('school_admin_authenticated', None)
            request.session.pop('school_admin_schema', None)
            return redirect(f'/portal/{tenant.schema_name}/login/')
        return view_func(request, schema_name, tenant=tenant, *args, **kwargs)
    return wrapper

# ----------------------------------------------------------------------
# Helper: fetch tenant from public schema (safe)
# ----------------------------------------------------------------------
def get_school_tenant(schema_name):
    schema_name = schema_name.lower().strip()
    with schema_context('public'):
                    tenant = SchoolClient.objects.filter(schema_name__iexact=schema_name, is_active=True).first()
    return tenant

# ----------------------------------------------------------------------
# Public home
# ----------------------------------------------------------------------
def saas_homepage(request):
    return HttpResponse('<h1>AXIS Engine Active</h1><p>School portals: /portal/&lt;schema_name&gt;/</p>')

# ----------------------------------------------------------------------
# Login / Logout (public, no decorator)
# ----------------------------------------------------------------------
def school_login(request, schema_name):
    tenant = get_school_tenant(schema_name)
    if not tenant:
        return HttpResponseNotFound('School not found')
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        if username == tenant.admin_username and password == tenant.admin_password:
            request.session['school_admin_authenticated'] = True
            request.session['school_admin_schema'] = tenant.schema_name
            request.session.save()
            return redirect(f'/portal/{tenant.schema_name}/')
        return render(request, 'tenant/login.html', {'tenant': tenant, 'error': 'Invalid credentials'})
    return render(request, 'tenant/login.html', {'tenant': tenant})

def school_logout(request, schema_name):
    request.session.flush()
    return redirect(f'/portal/{schema_name}/login/')

# ----------------------------------------------------------------------
# Protected views (tenant-specific session required)
# ----------------------------------------------------------------------
@tenant_login_required
def school_dashboard(request, schema_name, tenant=None):
    logo_url = tenant.school_logo.url if tenant.school_logo else None
    return render(request, 'tenant/dashboard.html', {'tenant': tenant, 'logo_url': logo_url})

@tenant_login_required
def school_students_list(request, schema_name, tenant=None):
    grade_filter = request.GET.get('grade', '')
    section_filter = request.GET.get('section', '')
    status_filter = request.GET.get('status', '')
    search_query = request.GET.get('search', '').strip()
    with schema_context(tenant.schema_name):
        students_qs = Student.objects.all()
        if search_query:
            students_qs = students_qs.filter(
                Q(roll_number__icontains=search_query) |
                Q(name__icontains=search_query) |
                Q(father_name__icontains=search_query) |
                Q(father_cnic__icontains=search_query) |
                Q(grade__icontains=search_query) |
                Q(section__icontains=search_query) |
                Q(status__icontains=search_query)
            )
        if grade_filter:
            students_qs = students_qs.filter(grade=grade_filter)
        if section_filter:
            students_qs = students_qs.filter(section=section_filter)
        if status_filter:
            students_qs = students_qs.filter(status=status_filter)
        students = students_qs.order_by('-enrolled_on')
        grades = Student.objects.values_list('grade', flat=True).distinct().order_by('grade')
        sections = Student.objects.values_list('section', flat=True).distinct().order_by('section')
        status_choices = Student.STATUS_CHOICES
    logo_url = tenant.school_logo.url if tenant.school_logo else None
    return render(request, 'tenant/students_list.html', {
        'tenant': tenant,
        'students': students,
        'grades': grades,
        'sections': sections,
        'status_choices': status_choices,
        'logo_url': logo_url,
        'search_query': search_query,
    })

@tenant_login_required
def school_add_student(request, schema_name, tenant=None):
    with schema_context(tenant.schema_name):
        if request.method == 'POST':
            form = StudentAdmissionForm(request.POST)
            if form.is_valid():
                student = form.save(commit=False)
                total = Student.objects.count() + 1
                student.roll_number = f"AX-{tenant.schema_name.upper()}-2026-{total:04d}"
                student.save()
                messages.success(request, f'Student {student.name} added')
                return redirect('school_portal_students', schema_name=tenant.schema_name)
        else:
            form = StudentAdmissionForm()
    logo_url = tenant.school_logo.url if tenant.school_logo else None
    return render(request, 'tenant/student_form.html', {'tenant': tenant, 'form': form, 'logo_url': logo_url})

@tenant_login_required
def school_settings(request, schema_name, tenant=None):
    logo_url = tenant.school_logo.url if tenant.school_logo else None
    return render(request, 'tenant/settings.html', {'tenant': tenant, 'logo_url': logo_url})

@tenant_login_required
def student_profile(request, schema_name, student_id, tenant=None):
    with schema_context(tenant.schema_name):
        try:
            student = Student.objects.get(id=student_id)
        except Student.DoesNotExist:
            return HttpResponseNotFound('Student not found')
    logo_url = tenant.school_logo.url if tenant.school_logo else None
    return render(request, 'tenant/student_profile.html', {
        'tenant': tenant,
        'student': student,
        'logo_url': logo_url,
    })

# ----------------------------------------------------------------------
# FEE MANAGEMENT VIEWS
# ----------------------------------------------------------------------
from .forms import FeeStructureForm, FeeGenerationForm, PaymentForm, FamilyPaymentForm, FeeSettingsForm
from .models import FeeStructure, FeeRecord, PaymentTransaction, SchoolFeeSettings
from datetime import date, timedelta
from decimal import Decimal

@tenant_login_required
def fee_structure(request, schema_name, tenant=None):
    with schema_context(tenant.schema_name):
        fee_structures = FeeStructure.objects.all().order_by('grade')
        if request.method == 'POST':
            form = FeeStructureForm(request.POST)
            if form.is_valid():
                grade = form.cleaned_data['grade']
                amount = form.cleaned_data['monthly_fee']
                FeeStructure.objects.update_or_create(grade=grade, defaults={'monthly_fee': amount})
                Student.objects.filter(grade=grade).update(custom_fee=amount)
                messages.success(request, f'Fee structure for {grade} updated to Rs {amount}')
                return redirect('fee_structure', schema_name=tenant.schema_name)
        else:
            form = FeeStructureForm()
    logo_url = tenant.school_logo.url if tenant.school_logo else None
    return render(request, 'tenant/fee_structure.html', {
        'tenant': tenant,
        'fee_structures': fee_structures,
        'form': form,
        'logo_url': logo_url,
    })

@tenant_login_required
def fee_generate(request, schema_name, tenant=None):
    if request.method == 'POST':
        form = FeeGenerationForm(request.POST)
        if form.is_valid():
            month = int(form.cleaned_data['month'])
            year = int(form.cleaned_data['year'])
            generate_all = form.cleaned_data['generate_for_all']
            with schema_context(tenant.schema_name):
                students = Student.objects.filter(status='active')
                if not generate_all:
                    existing = FeeRecord.objects.filter(month=month, year=year).values_list('student_id', flat=True)
                    students = students.exclude(id__in=existing)
                with schema_context('public'):
                    fee_settings, _ = SchoolFeeSettings.objects.get_or_create(tenant=tenant)
                if month == 12:
                    due_year = year + 1
                    due_month = 1
                else:
                    due_year = year
                    due_month = month + 1
                due_date = date(due_year, due_month, 1) + timedelta(days=fee_settings.due_date_offset - 1)
                created_count = 0
                for student in students:
                    base_fee = student.custom_fee if student.custom_fee > 0 else (FeeStructure.objects.filter(grade=student.grade).first().monthly_fee if FeeStructure.objects.filter(grade=student.grade).exists() else 0)
                    if base_fee > 0:
                        FeeRecord.objects.get_or_create(
                            student=student, month=month, year=year,
                            defaults={'amount': base_fee, 'due_date': due_date, 'status': 'pending'}
                        )
                        created_count += 1
                messages.success(request, f'Generated {created_count} fee records for {month}/{year}')
                return redirect('fee_generate', schema_name=tenant.schema_name)
    else:
        form = FeeGenerationForm()
    logo_url = tenant.school_logo.url if tenant.school_logo else None
    return render(request, 'tenant/fee_generate.html', {'tenant': tenant, 'form': form, 'logo_url': logo_url})

@tenant_login_required
def pending_fees(request, schema_name, tenant=None):
    with schema_context(tenant.schema_name):
        fee_records = FeeRecord.objects.filter(status__in=['pending', 'partial', 'overdue']).select_related('student').order_by('due_date')
        total_pending = sum(fr.remaining for fr in fee_records)
    logo_url = tenant.school_logo.url if tenant.school_logo else None
    return render(request, 'tenant/pending_fees.html', {
        'tenant': tenant,
        'fee_records': fee_records,
        'total_pending': total_pending,
        'logo_url': logo_url,
    })

@tenant_login_required
def payment_history(request, schema_name, tenant=None):
    with schema_context(tenant.schema_name):
        payments = PaymentTransaction.objects.all().order_by('-payment_date').select_related('student')
    logo_url = tenant.school_logo.url if tenant.school_logo else None
    return render(request, 'tenant/payment_history.html', {'tenant': tenant, 'payments': payments, 'logo_url': logo_url})

@tenant_login_required
def make_payment(request, schema_name, student_id=None, tenant=None):
    with schema_context(tenant.schema_name):
        if student_id:
            student = get_object_or_404(Student, id=student_id)
            pending_fees = FeeRecord.objects.filter(student=student, status__in=['pending', 'partial', 'overdue'])
            total_pending = sum(fr.remaining for fr in pending_fees)
        else:
            student = None
            pending_fees = []
            total_pending = 0
        if request.method == 'POST':
            form = PaymentForm(request.POST)
            if form.is_valid():
                student_id = form.cleaned_data['student_id']
                amount = Decimal(str(form.cleaned_data['amount']))
                payment_mode = form.cleaned_data['payment_mode']
                remarks = form.cleaned_data['remarks']
                student = get_object_or_404(Student, id=student_id)
                pending = FeeRecord.objects.filter(student=student, status__in=['pending', 'partial', 'overdue']).order_by('due_date')
                if amount <= 0:
                    messages.error(request, 'Amount must be greater than zero')
                    return redirect('make_payment', schema_name=tenant.schema_name, student_id=student.id)
                remaining_amount = amount
                fee_records_to_update = []
                for fee in pending:
                    if remaining_amount <= 0:
                        break
                    due_amount = fee.remaining
                    if remaining_amount >= due_amount:
                        fee.paid_amount = fee.amount
                        fee.save()
                        remaining_amount -= due_amount
                        fee_records_to_update.append(fee)
                    else:
                        fee.paid_amount += remaining_amount
                        fee.save()
                        remaining_amount = 0
                        fee_records_to_update.append(fee)
                payment = PaymentTransaction.objects.create(
                    student=student, amount=amount, payment_mode=payment_mode,
                    payment_type='full' if (amount >= total_pending - remaining_amount) else 'partial',
                    remarks=remarks, created_by=request.session.get('school_admin_username', 'admin')
                )
                payment.fee_records.set(fee_records_to_update)
                payment.save()
                messages.success(request, f'Payment of Rs {amount} recorded for {student.name}. Receipt No: {payment.receipt_number}')
                return redirect('fee_receipt', schema_name=tenant.schema_name, receipt_id=payment.id)
        else:
            form = PaymentForm(initial={'student_id': student.id if student else ''})
        logo_url = tenant.school_logo.url if tenant.school_logo else None
        return render(request, 'tenant/make_payment.html', {
            'tenant': tenant,
            'student': student,
            'pending_fees': pending_fees,
            'total_pending': total_pending,
            'form': form,
            'logo_url': logo_url,
        })
    return redirect('pending_fees', schema_name=tenant.schema_name)

@tenant_login_required
def family_payment(request, schema_name, tenant=None):
    if request.method == 'POST':
        form = FamilyPaymentForm(request.POST)
        if form.is_valid():
            father_cnic = form.cleaned_data['father_cnic']
            amount_str = form.cleaned_data.get('amount', '')
            amount = Decimal(amount_str) if amount_str else None
            payment_mode = form.cleaned_data['payment_mode']
            remarks = form.cleaned_data['remarks']
            with schema_context(tenant.schema_name):
                students = Student.objects.filter(father_cnic=father_cnic, status='active')
                if not students.exists():
                    messages.error(request, 'No student found with this CNIC')
                    return redirect('family_payment', schema_name=tenant.schema_name)
                all_fee_records = []
                total_pending_amount = Decimal(0)
                for student in students:
                    pending = FeeRecord.objects.filter(student=student, status__in=['pending', 'partial', 'overdue']).order_by('due_date')
                    total_pending_amount += sum(fr.remaining for fr in pending)
                    all_fee_records.extend(pending)
                if amount is None:
                    amount = total_pending_amount
                if amount > total_pending_amount:
                    messages.error(request, f'Amount exceeds total pending fees (Rs {total_pending_amount})')
                    return redirect('family_payment', schema_name=tenant.schema_name)
                remaining = amount
                paid_records = []
                for fee in sorted(all_fee_records, key=lambda x: x.due_date):
                    if remaining <= 0:
                        break
                    due = fee.remaining
                    if remaining >= due:
                        fee.paid_amount = fee.amount
                        fee.save()
                        remaining -= due
                        paid_records.append(fee)
                    else:
                        fee.paid_amount += remaining
                        fee.save()
                        remaining = 0
                        paid_records.append(fee)
                for student in students:
                    student_records = [fr for fr in paid_records if fr.student == student]
                    if student_records:
                        payment = PaymentTransaction.objects.create(
                            student=student,
                            amount=sum(fr.paid_amount for fr in student_records),
                            payment_mode=payment_mode, payment_type='full',
                            remarks=remarks, created_by=request.session.get('school_admin_username', 'admin')
                        )
                        payment.fee_records.set(student_records)
                        payment.save()
                messages.success(request, f'Payment of Rs {amount} processed for family of CNIC {father_cnic}')
                return redirect('payment_history', schema_name=tenant.schema_name)
    else:
        form = FamilyPaymentForm()
    logo_url = tenant.school_logo.url if tenant.school_logo else None
    return render(request, 'tenant/family_payment.html', {'tenant': tenant, 'form': form, 'logo_url': logo_url})

@tenant_login_required
def fee_receipt(request, schema_name, receipt_id, tenant=None):
    with schema_context(tenant.schema_name):
        payment = get_object_or_404(PaymentTransaction, id=receipt_id)
        fee_records = payment.fee_records.all()
    logo_url = tenant.school_logo.url if tenant.school_logo else None
    return render(request, 'tenant/fee_receipt.html', {
        'tenant': tenant,
        'payment': payment,
        'fee_records': fee_records,
        'logo_url': logo_url,
    })

@tenant_login_required
def fee_settings(request, schema_name, tenant=None):
    # SchoolFeeSettings lives in public schema only
    from django_tenants.utils import schema_context
    with schema_context('public'):
        settings_obj, created = SchoolFeeSettings.objects.get_or_create(tenant=tenant)
        if request.method == 'POST':
            form = FeeSettingsForm(request.POST, instance=settings_obj)
            if form.is_valid():
                form.save()
                messages.success(request, 'Fee settings updated successfully')
                return redirect('fee_settings', schema_name=tenant.schema_name)
        else:
            form = FeeSettingsForm(instance=settings_obj)
    logo_url = tenant.school_logo.url if tenant.school_logo else None
    return render(request, 'tenant/fee_settings.html', {'tenant': tenant, 'form': form, 'logo_url': logo_url})

# ----------------------------------------------------------------------
# URL patterns
# ----------------------------------------------------------------------
urlpatterns = [
    path('portal/<slug:schema_name>/fee/structure/', fee_structure, name='fee_structure'),
    path('portal/<slug:schema_name>/fee/generate/', fee_generate, name='fee_generate'),
    path('portal/<slug:schema_name>/fee/pending/', pending_fees, name='pending_fees'),
    path('portal/<slug:schema_name>/fee/history/', payment_history, name='payment_history'),
    path('portal/<slug:schema_name>/fee/pay/<int:student_id>/', make_payment, name='make_payment'),
    path('portal/<slug:schema_name>/fee/family-pay/', family_payment, name='family_payment'),
    path('portal/<slug:schema_name>/fee/receipt/<int:receipt_id>/', fee_receipt, name='fee_receipt'),
    path('portal/<slug:schema_name>/fee/settings/', fee_settings, name='fee_settings'),
    path('portal/<slug:schema_name>/students/', school_students_list, name='school_portal_students'),
    path('portal/<slug:schema_name>/students/add/', school_add_student, name='school_add_student'),
    path('portal/<slug:schema_name>/students/<int:student_id>/', student_profile, name='student_profile'),
    path('portal/<slug:schema_name>/', school_dashboard, name='school_portal'),
    path('portal/<slug:schema_name>/login/', school_login, name='school_portal_login'),
    path('portal/<slug:schema_name>/logout/', school_logout, name='school_portal_logout'),
    path('portal/<slug:schema_name>/settings/', school_settings, name='school_portal_settings'),
    path('', saas_homepage),
    path('admin/', admin.site.urls),
]
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
