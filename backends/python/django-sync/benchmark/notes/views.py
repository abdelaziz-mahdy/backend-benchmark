from django.shortcuts import render
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework import viewsets
from .models import Note
from .serializers import NoteSerializer

class NoteViewSet(viewsets.ModelViewSet):
    queryset = Note.objects.all()
    serializer_class = NoteSerializer
    
    def get_queryset(self):
        return Note.objects.all()[:100]

    @action(detail=False, methods=['get'])
    async def no_db_endpoint(self, request):
        return Response("no db endpoint", status=200)

    @action(detail=False, methods=['get'])
    async def no_db_endpoint2(self, request):
        return Response("no db endpoint2", status=200)
