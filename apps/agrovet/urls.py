from django.urls import path
from apps.agrovet.views import AgrovetItemListView, AgrovetRepayAPIView, RecordAgrovetPurchaseView

urlpatterns = [
    path('items/', AgrovetItemListView.as_view(), name='agrovet_items'),
    path('purchase/', RecordAgrovetPurchaseView.as_view(), name='agrovet_purchase'),
    path('repay/', AgrovetRepayAPIView.as_view(), name='agrovet_repay'),
]