from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import permissions, status
from django.db.models import Sum
from django.utils import timezone

from apps.members.models import Member
from apps.intake.models import IntakeLog
from apps.agrovet.models import MemberPurchase, AgrovetRepayment

class DashboardStatsAPIView(APIView):
    permission_classes = (permissions.AllowAny,)

    def get(self, request):
        today = timezone.now().date()

        # 1. Today's Milk Intake Metrics
        todays_liters = IntakeLog.objects.filter(
            quality_status='ACCEPTED',
            captured_at__date=today
        ).aggregate(total=Sum('liters_collected'))['total'] or 0.00

        # 2. Agrovet Credit Metrics
        total_credit = MemberPurchase.objects.filter(
            status=MemberPurchase.Status.PENDING_DEDUCTION
        ).aggregate(total=Sum('amount'))['total'] or 0.00

        total_repayments = AgrovetRepayment.objects.aggregate(
            total=Sum('amount')
        )['total'] or 0.00

        net_outstanding_debt = max(0.00, float(total_credit) - float(total_repayments))

        # 3. Member Metrics
        total_active_members = Member.objects.filter(is_active=True).count()

        return Response({
            "todays_liters_collected": todays_liters,
            "net_outstanding_agrovet_debt_kes": net_outstanding_debt,
            "total_active_farmers": total_active_members,
            "timestamp": timezone.now()
        }, status=status.HTTP_200_OK)