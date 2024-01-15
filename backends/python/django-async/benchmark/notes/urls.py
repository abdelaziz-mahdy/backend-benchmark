from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import AsyncNoteViewSet

router = DefaultRouter()
router.register(r'notes', AsyncNoteViewSet, basename="async")

urlpatterns = [
    path('', include(router.urls)),
]
