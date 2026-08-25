from django.db import models

# Create your models here.

import uuid
from django.contrib.auth.models import AbstractUser
from django.db import models

class User(AbstractUser):
    class Roles(models.TextChoices):
        ADMIN = 'ADMIN', 'System Administrator'
        PLANT_MANAGER = 'PLANT_MANAGER', 'Plant Manager'
        FINANCE_OFFICER = 'FINANCE_OFFICER', 'Finance Officer'
        AGROVET_CLERK = 'AGROVET_CLERK', 'Agrovet Clerk'
        FIELD_COLLECTOR = 'FIELD_COLLECTOR', 'Field Collector'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    role = models.CharField(max_length=30, choices=Roles.choices, default=Roles.FIELD_COLLECTOR)
    phone_number = models.CharField(max_length=15, blank=True, null=True)

    def __str__(self):
        return f"{self.username} ({self.role})"
