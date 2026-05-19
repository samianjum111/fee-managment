from django.contrib import admin
from django.urls import path
from django.http import HttpResponse, HttpResponseNotFound
from django.shortcuts import redirect, render

from axis_saas.models import SchoolClient


def saas_homepage(request):
    return HttpResponse('''
        <style>
            body { font-family: 'Segoe UI', sans-serif; background: #0f172a; color: #f8fafc; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; }
            .card { background: #1e293b; padding: 40px; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.3); border: 1px solid #334155; max-width: 500px; width: 100%; text-align: center; }
            h1 { color: #38bdf8; margin-bottom: 10px; }
            p { color: #94a3b8; font-size: 1.1em; line-height: 1.5; }
        </style>
        <div class="card">
            <h1>AXIS Engine Active 🚀</h1>
            <p>School portals are available at <strong>/portal/&lt;schema_name&gt;/</strong>.</p>
        </div>
    ''')


def get_school_tenant(schema_name):
    schema_name = schema_name.lower().strip()
    tenant = SchoolClient.objects.filter(schema_name__iexact=schema_name, is_active=True).first()
    if tenant:
        return tenant
    return SchoolClient.objects.filter(name__iexact=schema_name, is_active=True).first()


def school_login(request, schema_name):
    tenant = get_school_tenant(schema_name)
    if not tenant:
        return HttpResponseNotFound('School portal not found.')

    error = None
    if request.method == 'POST':
        username = request.POST.get('username', '').strip()
        password = request.POST.get('password', '')
        if username == tenant.admin_username and password == tenant.admin_password:
            request.session['school_admin_authenticated'] = True
            request.session['school_admin_schema'] = tenant.schema_name
            request.session['school_admin_name'] = tenant.name
            return redirect(f'/portal/{tenant.schema_name}/')
        error = 'Username or password is incorrect.'

    return render(request, 'tenant/login.html', {
        'tenant': tenant,
        'error': error,
    })


def school_logout(request, schema_name):
    tenant = get_school_tenant(schema_name)
    if tenant:
        request.session.pop('school_admin_authenticated', None)
        request.session.pop('school_admin_schema', None)
        request.session.pop('school_admin_name', None)
        return redirect(f'/portal/{tenant.schema_name}/login/')
    return redirect('/')


def school_dashboard(request, schema_name):
    tenant = get_school_tenant(schema_name)
    if not tenant:
        return HttpResponseNotFound('School portal not found.')

    if request.session.get('school_admin_authenticated') is not True or request.session.get('school_admin_schema') != tenant.schema_name:
        return redirect(f'/portal/{tenant.schema_name}/login/')

    return render(request, 'tenant/dashboard.html', {
        'tenant': tenant,
    })

urlpatterns = [
    path('', saas_homepage, name='saas_home'),
    path('admin/', admin.site.urls),
    path('portal/<slug:schema_name>/', school_dashboard, name='school_portal'),
    path('portal/<slug:schema_name>/login/', school_login, name='school_portal_login'),
    path('portal/<slug:schema_name>/logout/', school_logout, name='school_portal_logout'),
]
