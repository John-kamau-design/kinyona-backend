from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from apps.users.views import FarmerListView, UserRegisterView, UserProfileView

urlpatterns = [
    path('token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('register/', UserRegisterView.as_view(), name='user_register'),
    path('me/', UserProfileView.as_view(), name='user_profile'),
    path('farmers/', FarmerListView.as_view(), name='farmer_list'),  # New endpoint for listing and creating farmers
]