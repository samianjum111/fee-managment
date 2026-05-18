from django.shortcuts import render, redirect
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from .models import Student
from django import forms

class StudentAdmissionForm(forms.ModelForm):
    class Meta:
        model = Student
        fields = [
            'name', 'father_name', 'father_cnic', 'parent_mobile', 
            'grade', 'section', 'admission_date', 'status',
            'gender', 'date_of_birth', 'address', 'notes'
        ]
        widgets = {
            'admission_date': forms.DateInput(attrs={'type': 'date'}),
            'date_of_birth': forms.DateInput(attrs={'type': 'date'}),
            'address': forms.Textarea(attrs={'rows': 2}),
            'notes': forms.Textarea(attrs={'rows': 2}),
        }

@login_required
def tenant_dashboard(request):
    if request.tenant.schema_name == 'public':
        return redirect('/admin/')
    
    students = Student.objects.all().order_by('-enrolled_on')
    return render(request, 'tenant/dashboard.html', {'students': students})

@login_required
def add_student_instance(request):
    if request.tenant.schema_name == 'public':
        return redirect('/admin/')

    if request.method == 'POST':
        form = StudentAdmissionForm(request.POST)
        if form.is_validate_or_not_yet := form.is_valid():
            student = form.save(commit=False)
            # Automatic dynamic sequence token generation for strong isolation tracking
            total_students = Student.objects.count() + 1
            student.roll_number = f"AX-{request.tenant.schema_name.upper()}-{2026}-{total_students:04d}"
            student.save()
            messages.success(request, f"Student {student.name} securely provisioned into ledgers with Token: {student.roll_number}")
            return redirect('school_home')
    else:
        form = StudentAdmissionForm()
        
    return render(request, 'tenant/student_form.html', {'form': form})
