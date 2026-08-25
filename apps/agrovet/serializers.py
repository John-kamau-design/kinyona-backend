from rest_framework import serializers
from apps.agrovet.models import AgrovetItem, MemberPurchase

class AgrovetItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = AgrovetItem
        fields = '__all__'

class CreateMemberPurchaseSerializer(serializers.Serializer):
    member_code = serializers.CharField()
    item_id = serializers.UUIDField(required=False, allow_null=True)
    description = serializers.CharField(max_length=200)
    amount = serializers.DecimalField(max_digits=10, decimal_places=2)

from rest_framework import serializers
from apps.members.models import Member
from .models import AgrovetRepayment

class AgrovetRepaymentSerializer(serializers.ModelSerializer):
    member_code = serializers.CharField(write_only=True)

    class Meta:
        model = AgrovetRepayment
        fields = ['id', 'member_code', 'amount', 'payment_method', 'reference_number', 'recorded_at']
        read_only_fields = ['id', 'recorded_at']

    def validate_member_code(self, value):
        try:
            return Member.objects.get(member_code=value)
        except Member.DoesNotExist:
            raise serializers.ValidationError("Member with this code does not exist.")

    def create(self, validated_data):
        member = validated_data.pop('member_code')
        return AgrovetRepayment.objects.create(member=member, **validated_data)

