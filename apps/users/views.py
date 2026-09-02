from django.shortcuts import render

# Create your views here.

from rest_framework import generics, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from django.contrib.auth import get_user_model
from apps.users.serializers import UserSerializer, UserRegistrationSerializer

User = get_user_model()

class UserRegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = UserRegistrationSerializer
    permission_classes = (permissions.IsAdminUser,) # Only Admins can create staff users

class UserProfileView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request):
        serializer = UserSerializer(request.user)
        return Response(serializer.data)

from rest_framework.generics import ListCreateAPIView
from rest_framework.permissions import IsAuthenticated
from django.contrib.auth import get_user_model
from .serializers import UserSerializer # Ensure you have a UserSerializer defined

User = get_user_model()

class FarmerListView(ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = UserSerializer

    def get_queryset(self):
        # Returns all users with role 'FARMER'
        return User.objects.filter(role='FARMER')

    def perform_create(self, serializer):
        # Automatically assign role='FARMER' when creating a new farmer record
        serializer.save(role='FARMER')