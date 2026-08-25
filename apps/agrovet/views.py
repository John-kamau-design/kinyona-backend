from django.shortcuts import render

# Create your views here.

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions, generics
from django.shortcuts import get_object_or_404
from django.db import transaction

from apps.members.models import Member
from apps.agrovet.models import AgrovetItem, MemberPurchase
from apps.agrovet.serializers import AgrovetItemSerializer, CreateMemberPurchaseSerializer

class AgrovetItemListView(generics.ListCreateAPIView):
    permission_classes = (permissions.IsAuthenticated,)
    queryset = AgrovetItem.objects.all()
    serializer_class = AgrovetItemSerializer

class RecordAgrovetPurchaseView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    @transaction.atomic
    def post(self, request):
        """
        Payload:
        {
            "member_code": "KIN-001",
            "item_id": "optional-uuid-here",
            "description": "50kg Dairy Meal Feed",
            "amount": 2800.00
        }
        """
        serializer = CreateMemberPurchaseSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        member = get_object_or_404(Member, member_code=data['member_code'], is_active=True)

        item = None
        if data.get('item_id'):
            item = get_object_or_404(AgrovetItem, id=data['item_id'])
            if item.stock_quantity <= 0:
                return Response({"error": f"Item '{item.name}' is out of stock."}, status=status.HTTP_400_BAD_REQUEST)
            item.stock_quantity -= 1
            item.save()

        purchase = MemberPurchase.objects.create(
            member=member,
            item=item,
            description=data['description'],
            amount=data['amount'],
            status=MemberPurchase.Status.PENDING_DEDUCTION
        )

        return Response({
            "status": "success",
            "purchase_id": purchase.id,
            "member": f"{member.member_code} - {member.full_name}",
            "description": purchase.description,
            "amount_kes": str(purchase.amount),
            "deduction_status": purchase.status
        }, status=status.HTTP_201_CREATED)


from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.db.models import Sum

from .models import AgrovetRepayment, MemberPurchase
from .serializers import AgrovetRepaymentSerializer

class AgrovetRepayAPIView(APIView):
    def post(self, request):
        serializer = AgrovetRepaymentSerializer(data=request.data)
        if serializer.is_valid():
            repayment = serializer.save()
            
            # 1. Total debt accumulated from store credit
            total_purchases = MemberPurchase.objects.filter(
             member=repayment.member, 
                status=MemberPurchase.Status.PENDING_DEDUCTION
            ).aggregate(total=Sum('amount'))['total'] or 0.00

            # 2. Total direct repayments made so far
            total_repayments = AgrovetRepayment.objects.filter(
                member=repayment.member
            ).aggregate(total=Sum('amount'))['total'] or 0.00

            # 3. Remaining balance after this payment
            net_debt = max(0.00, float(total_purchases) - float(total_repayments))

            return Response({
                "message": "Repayment recorded successfully",
                "receipt": repayment.reference_number,
                "amount_paid": repayment.amount,
                "remaining_agrovet_debt": net_debt
            }, status=status.HTTP_201_CREATED)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    