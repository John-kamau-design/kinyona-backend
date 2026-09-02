import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'kinyona.settings')  # Replace 'kinyona' with your Django project package name

django.setup()

from django.contrib.auth import get_user_model

User = get_user_model()
username = "John073"
password = "Kinyona#2026!Wx7"

if not User.objects.filter(username=username).exists():
    user = User.objects.create_superuser(username=username, password=password, email="")
    user.role = "MANAGER"
    user.save()
    print("Admin user John073 created successfully!")
else:
    user = User.objects.get(username=username)
    user.role = "MANAGER"
    user.save()
    print("Admin user John073 already exists - role updated to MANAGER!")