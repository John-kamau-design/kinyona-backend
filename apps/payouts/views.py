import uuid
from decimal import Decimal
from django.db import transaction
from django.db.models import Sum
from django.shortcuts import get_object_or_404, render

from rest_framework import request, status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from .models import PayoutBatch, PayoutTransaction
from .serializers import PayoutBatchSerializer

from apps.members.models import Member
from apps.intake.models import IntakeLog
from apps.agrovet.models import MemberPurchase, AgrovetRepayment 


class GeneratePayoutBatchView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        batches = PayoutBatch.objects.all().order_by('-created_at')
        serializer = PayoutBatchSerializer(batches, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)
    
    def post(self, request):
        start_date = request.data.get('start_date')
        end_date = request.data.get('end_date')
        rate_per_liter = Decimal(str(request.data.get('rate_per_liter', 45.00)))

        batch_code = f"BATCH-{start_date.replace('-', '')}-{end_date.replace('-', '')}-{uuid.uuid4().hex[:4].upper()}"

        batch = PayoutBatch.objects.create(
            batch_code=batch_code,
            start_date=start_date,
            end_date=end_date,
            total_liters=0,
            total_gross_amount=0,
            total_deductions=0,
            total_net_disbursed=0,
            status=PayoutBatch.BatchStatus.DRAFT,
            created_by=request.user
        )

        total_batch_liters = Decimal('0.00')
        total_batch_gross = Decimal('0.00')
        total_batch_deductions = Decimal('0.00')

        members = Member.objects.filter(is_active=True)

        for member in members:
            # 1. Total milk earnings
            intake_stats = IntakeLog.objects.filter(
                member=member,
                quality_status=IntakeLog.QualityStatus.ACCEPTED,
                captured_at__date__gte=start_date,
                captured_at__date__lte=end_date
            ).aggregate(total=Sum('liters_collected'))

            member_liters = intake_stats['total'] or Decimal('0.00')
            if member_liters <= 0:
                continue

            gross_amount = member_liters * rate_per_liter

            # 2. Total pending Agrovet deductions
            pending_purchases = MemberPurchase.objects.filter(
                member=member,
                status=MemberPurchase.Status.PENDING_DEDUCTION
            )
            raw_deductions = pending_purchases.aggregate(total=Sum('amount'))['total'] or Decimal('0.00')

            # Cap deductions at gross earnings (prevent negative payout)
            deductions_applied = min(gross_amount, raw_deductions)
            net_amount = gross_amount - deductions_applied

            # Mark credit purchases as deducted
            if deductions_applied > 0:
                pending_purchases.update(status=MemberPurchase.Status.DEDUCTED)

            PayoutTransaction.objects.create(
                batch=batch,
                member=member,
                phone_number=member.phone_number,
                gross_amount=gross_amount,
                deductions_amount=deductions_applied,
                net_amount=net_amount,
                status=PayoutTransaction.TransactionStatus.PENDING
            )

            total_batch_liters += member_liters
            total_batch_gross += gross_amount
            total_batch_deductions += deductions_applied

        batch.total_liters = total_batch_liters
        batch.total_gross_amount = total_batch_gross
        batch.total_deductions = total_batch_deductions
        batch.total_net_disbursed = total_batch_gross - total_batch_deductions
        batch.save()

        return Response({
            "status": "created",
            "batch_code": batch.batch_code,
            "total_members": batch.transactions.count(),
            "total_liters": str(batch.total_liters),
            "total_gross_kes": str(batch.total_gross_amount),
            "total_deductions_kes": str(batch.total_deductions),
            "total_net_disbursed_kes": str(batch.total_net_disbursed)
        }, status=status.HTTP_201_CREATED)


class ProcessMpesaPayoutBatchView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, batch_id):
        batch = get_object_or_404(PayoutBatch, id=batch_id)

        if batch.status == PayoutBatch.BatchStatus.COMPLETED:
            return Response({"error": "Batch is already completed."}, status=status.HTTP_400_BAD_REQUEST)

        batch.status = PayoutBatch.BatchStatus.PROCESSING
        batch.save()

        # Place MPesaB2CClient initialization here when service is wired
        dispatched_count = 0
        pending_txs = batch.transactions.filter(status=PayoutTransaction.TransactionStatus.PENDING)

        for tx in pending_txs:
            try:
                # Dispatched via M-Pesa B2C client logic
                pass
            except Exception as e:
                tx.status = PayoutTransaction.TransactionStatus.FAILED_RETRY
                tx.failure_reason = str(e)
                tx.save()

        return Response({
            "status": "processing",
            "batch_code": batch.batch_code,
            "dispatched_transactions": dispatched_count
        }, status=status.HTTP_200_OK)


class MPesaB2CCallbackView(APIView):
    # Public endpoint required for Safaricom servers to post notifications
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        payload = request.data.get('Result', {})
        result_code = payload.get('ResultCode')
        result_desc = payload.get('ResultDesc')
        conversation_id = payload.get('ConversationID')
        transaction_id = payload.get('TransactionID')

        result_params = payload.get('ResultParameters', {}).get('ResultParameter', [])
        param_dict = {item['Key']: item['Value'] for item in result_params if 'Key' in item and 'Value' in item}

        tx = PayoutTransaction.objects.filter(mpesa_conversation_id=conversation_id).first()
        
        if tx:
            if result_code == 0:
                tx.status = PayoutTransaction.TransactionStatus.SUCCESS_PAID
                tx.mpesa_receipt_number = transaction_id or param_dict.get('TransactionReceipt', '')
                tx.failure_reason = None
            else:
                tx.status = PayoutTransaction.TransactionStatus.FAILED_RETRY
                tx.failure_reason = f"Code {result_code}: {result_desc}"
            tx.save()

            batch = tx.batch
            pending_or_processing = batch.transactions.filter(
                status__in=[
                    PayoutTransaction.TransactionStatus.PENDING,
                ]
            ).exists()
            
            if not pending_or_processing:
                batch.status = PayoutBatch.BatchStatus.COMPLETED
                batch.save()

        return Response({"ResultCode": 0, "ResultDesc": "Accepted"}, status=status.HTTP_200_OK)


class MPesaB2CTimeoutView(APIView):
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        payload = request.data.get('Result', {})
        conversation_id = payload.get('ConversationID')

        tx = PayoutTransaction.objects.filter(mpesa_conversation_id=conversation_id).first()
        if tx:
            tx.status = PayoutTransaction.TransactionStatus.FAILED_RETRY
            tx.failure_reason = "Request Timed Out at Safaricom Gateway."
            tx.save()

        return Response({"ResultCode": 0, "ResultDesc": "Accepted"}, status=status.HTTP_200_OK)