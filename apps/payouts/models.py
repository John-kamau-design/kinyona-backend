from django.db import models

# Create your models here.

import uuid
from django.db import models
from django.conf import settings
from apps.members.models import Member

class PayoutBatch(models.Model):
    class BatchStatus(models.TextChoices):
        DRAFT = 'DRAFT', 'Draft'
        APPROVED = 'APPROVED', 'Approved'
        PROCESSING = 'PROCESSING', 'Processing M-Pesa'
        COMPLETED = 'COMPLETED', 'Completed'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    batch_code = models.CharField(max_length=30, unique=True)
    start_date = models.DateField()
    end_date = models.DateField()
    total_liters = models.DecimalField(max_digits=12, decimal_places=2)
    total_gross_amount = models.DecimalField(max_digits=12, decimal_places=2)
    total_deductions = models.DecimalField(max_digits=12, decimal_places=2)
    total_net_disbursed = models.DecimalField(max_digits=12, decimal_places=2)
    status = models.CharField(max_length=30, choices=BatchStatus.choices, default=BatchStatus.DRAFT)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.batch_code} ({self.status})"

class PayoutTransaction(models.Model):
    class TransactionStatus(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        SUCCESS_PAID = 'SUCCESS_PAID', 'Success Paid'
        FAILED_RETRY = 'FAILED_RETRY', 'Failed - Retry'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    batch = models.ForeignKey(PayoutBatch, on_delete=models.CASCADE, related_name='transactions')
    member = models.ForeignKey(Member, on_delete=models.PROTECT)
    phone_number = models.CharField(max_length=15)
    gross_amount = models.DecimalField(max_digits=10, decimal_places=2)
    deductions_amount = models.DecimalField(max_digits=10, decimal_places=2)
    net_amount = models.DecimalField(max_digits=10, decimal_places=2)
    mpesa_conversation_id = models.CharField(max_length=100, blank=True, null=True)
    mpesa_receipt_number = models.CharField(max_length=50, blank=True, null=True)
    status = models.CharField(max_length=20, choices=TransactionStatus.choices, default=TransactionStatus.PENDING)
    failure_reason = models.TextField(blank=True, null=True)
    updated_at = models.DateTimeField(auto_now=True)