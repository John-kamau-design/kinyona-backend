import os
import django

# Set Django settings module using your 'kinyona_core' package
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'kinyona_core.settings')

django.setup()

from django.contrib.auth import get_user_model

User = get_user_model()
username = "John073"
raw_password = "Kinyona#2026!Wx7"

# Retrieve existing user or create a new instance
user, created = User.objects.get_or_create(username=username)

# Set and properly hash password for Django authentication
user.set_password(raw_password)

# Assign administrative access and roles
user.is_staff = True
user.is_superuser = True

if hasattr(user, 'role'):
    user.role = "MANAGER"

user.save()

if created:
    print("Admin user John073 created successfully!")
else:
    print("Admin user John073 password and MANAGER role updated successfully!")