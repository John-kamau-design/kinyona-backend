from django.urls import path
from apps.intake.views import FieldIntakeSyncView, PlantReconciliationView

urlpatterns = [
    path('sync/', FieldIntakeSyncView.as_view(), name='intake_sync'),
    path('reconcile/<uuid:shift_id>/', PlantReconciliationView.as_view(), name='plant_reconcile'),
]