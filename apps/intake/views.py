from django.shortcuts import render

# Create your views here.

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from django.db import transaction
from django.shortcuts import get_object_or_404
from apps.intake.models import ShiftLedger, IntakeLog
from apps.members.models import Member
from apps.intake.serializers import ShiftLedgerSerializer, IntakeLogSerializer

class FieldIntakeSyncView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    @transaction.atomic
    def post(self, request):
        """
        Accepts a batch of offline collection logs from a mobile device.
        Payload format:
        {
            "vehicle_id": "TRUCK-01",
            "start_time": "2026-08-18T08:00:00Z",
            "deliveries": [
                {
                    "receipt_number": "REC-20260818-001",
                    "member_code": "KIN-001",
                    "liters_collected": 15.5,
                    "quality_status": "ACCEPTED",
                    "captured_at": "2026-08-18T08:15:00Z"
                }
            ]
        }
        """
        data = request.data
        vehicle_id = data.get('vehicle_id')
        deliveries = data.get('deliveries', [])

        # Get or create active shift for this vehicle & collector
        shift, created = ShiftLedger.objects.get_or_create(
            vehicle_id=vehicle_id,
            collector=request.user,
            status=ShiftLedger.ShiftStatus.OPEN
        )

        synced_records = []
        total_synced_liters = 0

        for item in deliveries:
            receipt_no = item.get('receipt_number')
            
            # Idempotency check: Skip if receipt was already synced earlier
            if IntakeLog.objects.filter(receipt_number=receipt_no).exists():
                continue

            member = get_object_or_404(Member, member_code=item.get('member_code'))
            liters = float(item.get('liters_collected', 0))

            intake_log = IntakeLog.objects.create(
                receipt_number=receipt_no,
                shift=shift,
                member=member,
                liters_collected=liters,
                quality_status=item.get('quality_status', 'ACCEPTED'),
                captured_at=item.get('captured_at')
            )
            synced_records.append(intake_log.id)
            total_synced_liters += liters

        # Update cumulative shift total
        shift.total_field_liters += total_synced_liters
        shift.status = ShiftLedger.ShiftStatus.SYNCED
        shift.save()

        return Response({
            "status": "success",
            "shift_id": shift.id,
            "synced_count": len(synced_records),
            "total_field_liters": shift.total_field_liters
        }, status=status.HTTP_201_CREATED)


from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from django.shortcuts import get_object_or_404
from decimal import Decimal
from apps.intake.models import ShiftLedger
from apps.intake.serializers import ShiftLedgerSerializer

class PlantReconciliationView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, shift_id):
        """
        Calculates shift variance when a tanker unloads at the central plant.
        Payload:
        {
            "plant_received_liters": 1250.50
        }
        """
        shift = get_object_or_404(ShiftLedger, id=shift_id)

        # Ensure shift hasn't been closed and audited already
        if shift.status == ShiftLedger.ShiftStatus.CLOSED_AUDITED:
            return Response(
                {"error": "This shift is already closed and audited."},
                status=status.HTTP_400_BAD_REQUEST
            )

        raw_received = request.data.get('plant_received_liters')
        if raw_received is None:
            return Response(
                {"error": "plant_received_liters is required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        plant_received = Decimal(str(raw_received))
        field_total = shift.total_field_liters

        # Variance = Plant Received - Field Collected
        # Negative value = Loss / Shrinkage; Positive value = Unaccounted Gain
        variance = plant_received - field_total

        # Save reconciliation data & finalize shift
        shift.plant_received_liters = plant_received
        shift.variance_liters = variance
        shift.status = ShiftLedger.ShiftStatus.CLOSED_AUDITED
        shift.save()

        # Audit Flag Trigger (Flag shifts exceeding +/- 1% or 5L variance threshold)
        flagged = False
        variance_percentage = (abs(variance) / field_total * 100) if field_total > 0 else Decimal('0.00')
        if abs(variance) > Decimal('5.00') or variance_percentage > Decimal('1.00'):
            flagged = True

        return Response({
            "status": "audited",
            "shift_id": shift.id,
            "vehicle_id": shift.vehicle_id,
            "collector": shift.collector.get_full_name() or shift.collector.username,
            "total_field_liters": str(field_total),
            "plant_received_liters": str(plant_received),
            "variance_liters": str(variance),
            "variance_percentage": f"{variance_percentage:.2f}%",
            "flagged_for_investigation": flagged,
            "audit_summary": (
                f"SHRINKAGE DETECTED: Loss of {abs(variance)}L" if variance < 0
                else f"SURPLUS DETECTED: Unaccounted gain of {variance}L" if variance > 0
                else "MATCHED: Perfect zero-variance shift."
            )
        }, status=status.HTTP_200_OK)
    