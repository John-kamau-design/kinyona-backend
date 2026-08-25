from django.urls import path
from apps.payouts.views import (
    GeneratePayoutBatchView, 
    ProcessMpesaPayoutBatchView,
    MPesaB2CCallbackView,
    MPesaB2CTimeoutView
)

urlpatterns = [
    path('generate/', GeneratePayoutBatchView.as_view(), name='payout_generate'),
    path('process/<uuid:batch_id>/', ProcessMpesaPayoutBatchView.as_view(), name='payout_process'),
    path('mpesa/callback/', MPesaB2CCallbackView.as_view(), name='mpesa_callback'),
    path('mpesa/timeout/', MPesaB2CTimeoutView.as_view(), name='mpesa_timeout'),
]