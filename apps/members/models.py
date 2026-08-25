from django.db import models

# Create your models here.

import uuid
from django.db import models

class Member(models.Model):
    class PayoutMethod(models.TextChoices):
        MPESA = 'MPESA', 'M-Pesa B2C'
        CASH = 'CASH', 'Cash at Counter'
        BANK = 'BANK', 'Bank Transfer'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member_code = models.CharField(max_length=20, unique=True, db_index=True)
    full_name = models.CharField(max_length=120)
    national_id = models.CharField(max_length=20, unique=True)
    phone_number = models.CharField(max_length=15)
    bank_account_number = models.CharField(max_length=30, blank=True, null=True)
    bank_code = models.CharField(max_length=10, blank=True, null=True)
    payout_method = models.CharField(
        max_length=10,
        choices=PayoutMethod.choices,
        default=PayoutMethod.MPESA
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.member_code} - {self.full_name}"