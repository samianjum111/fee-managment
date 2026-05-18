from django.urls import path
from django.contrib import admin
from axis_saas.tenant_views import tenant_dashboard, add_student_instance
from django.contrib.auth import views as auth_views

urlpatterns = [
    path('', tenant_dashboard, name='school_home'),
    path('students/add/', add_student_instance, name='add_student'),
    path('admin/', admin.site.urls),
    path('logout/', auth_views.LogoutView.as_view(next_page='school_home'), name='school_logout'),
]
