from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from apps.users.views import CustomTokenObtainPairView, FarmerListView, UserRegisterView, UserProfileView

urlpatterns = [
    path('token/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('register/', UserRegisterView.as_view(), name='user_register'),
    path('me/', UserProfileView.as_view(), name='user_profile'),
    path('farmers/', FarmerListView.as_view(), name='farmer_list'),
]