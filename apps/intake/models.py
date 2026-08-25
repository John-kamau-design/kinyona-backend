from django.db import models

# Create your models here.

import uuid
from django.db import models
from django.conf import settings
from apps.members.models import Member

class ShiftLedger(models.Model):
    class ShiftStatus(models.TextChoices):
        OPEN = 'OPEN', 'Open'
        SYNCED = 'SYNCED', 'Synced'
        CLOSED_AUDITED = 'CLOSED_AUDITED', 'Closed & Audited'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    vehicle_id = models.CharField(max_length=20)
    collector = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='shifts')
    start_time = models.DateTimeField(auto_now_add=True)
    end_time = models.DateTimeField(null=True, blank=True)
    total_field_liters = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    plant_received_liters = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    variance_liters = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    status = models.CharField(max_length=20, choices=ShiftStatus.choices, default=ShiftStatus.OPEN)

    def __str__(self):
        return f"Shift {self.vehicle_id} - {self.start_time.strftime('%Y-%m-%d')}"

class IntakeLog(models.Model):
    class QualityStatus(models.TextChoices):
        ACCEPTED = 'ACCEPTED', 'Accepted'
        REJECTED = 'REJECTED', 'Rejected'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    receipt_number = models.CharField(max_length=50, unique=True, db_index=True)
    shift = models.ForeignKey(ShiftLedger, on_delete=models.CASCADE, related_name='intakes')
    member = models.ForeignKey(Member, on_delete=models.PROTECT, related_name='deliveries')
    liters_collected = models.DecimalField(max_digits=8, decimal_places=2)
    quality_status = models.CharField(max_length=20, choices=QualityStatus.choices, default=QualityStatus.ACCEPTED)
    captured_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.receipt_number} - {self.liters_collected}L"