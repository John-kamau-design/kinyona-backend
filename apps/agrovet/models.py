from django.db import models

# Create your models here.

import uuid
from django.db import models
from apps.members.models import Member

class AgrovetItem(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100)
    unit_price = models.DecimalField(max_digits=10, decimal_places=2)
    stock_quantity = models.IntegerField(default=0)

    def __str__(self):
        return f"{self.name} - KES {self.unit_price}"

class MemberPurchase(models.Model):
    class Status(models.TextChoices):
        PENDING_DEDUCTION = 'PENDING', 'Pending Payout Deduction'
        DEDUCTED = 'DEDUCTED', 'Deducted from Payout'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member = models.ForeignKey(Member, on_delete=models.PROTECT, related_name='agrovet_purchases')
    item = models.ForeignKey(AgrovetItem, on_delete=models.PROTECT, null=True, blank=True)
    description = models.CharField(max_length=200)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING_DEDUCTION)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.member.member_code} - {self.description} (KES {self.amount})"


from django.db import models
from django.core.validators import MinValueValidator
from apps.members.models import Member  # Import Member from your members app

class AgrovetRepayment(models.Model):
    class PaymentMethod(models.TextChoices):
        CASH = 'CASH', 'Cash'
        MPESA_DIRECT = 'MPESA_DIRECT', 'M-Pesa Direct/Paybill'
        BANK_DEPOSIT = 'BANK_DEPOSIT', 'Bank Deposit'

    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='agrovet_repayments')
    amount = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(0.01)])
    payment_method = models.CharField(max_length=15, choices=PaymentMethod.choices, default=PaymentMethod.CASH)
    reference_number = models.CharField(max_length=50, unique=True, help_text="M-Pesa Code or Receipt No.")
    recorded_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.member.member_code} - KES {self.amount} ({self.payment_method})"

    