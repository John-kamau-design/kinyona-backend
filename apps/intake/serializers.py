from rest_framework import serializers
from apps.intake.models import ShiftLedger, IntakeLog

class IntakeLogSerializer(serializers.ModelSerializer):
    member_code = serializers.CharField(source='member.member_code', read_only=True)

    class Meta:
        model = IntakeLog
        fields = ('id', 'receipt_number', 'shift', 'member', 'member_code', 'liters_collected', 'quality_status', 'captured_at', 'created_at')
        read_only_fields = ('id', 'created_at')

class ShiftLedgerSerializer(serializers.ModelSerializer):
    intakes = IntakeLogSerializer(many=True, read_only=True)

    class Meta:
        model = ShiftLedger
        fields = ('id', 'vehicle_id', 'collector', 'start_time', 'end_time', 'total_field_liters', 'plant_received_liters', 'variance_liters', 'status', 'intakes')
        read_only_fields = ('id', 'start_time')