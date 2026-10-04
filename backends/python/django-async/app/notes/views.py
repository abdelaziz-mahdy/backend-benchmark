from rest_framework.decorators import action
from rest_framework.response import Response
from adrf.viewsets import ViewSet
# from asgiref.sync import sync_to_async

from .models import Note
from .serializers import NoteSerializer

class AsyncNoteViewSet(ViewSet):

    # @sync_to_async
    async def get_queryset(self):
        return Note.objects.all()[:100]

    async def list(self, request):
        queryset = (await self.get_queryset())
        serializer = NoteSerializer(queryset, many=True)
        return Response(await serializer.adata,)

    async def retrieve(self, request, pk=None):
        queryset = await self.get_queryset()
        note = await queryset.aget(pk=pk)
        serializer = NoteSerializer(note)
        return Response(await serializer.adata,)

    async def create(self, request):
        serializer = NoteSerializer(data=request.data)
        if serializer.is_valid():
            note = await serializer.asave()
            return Response(await serializer.adata, status=201)
        return Response(serializer.errors, status=400)

    async def update(self, request, pk=None):
        queryset = await self.get_queryset()
        note = await queryset.aget(pk=pk)
        serializer = NoteSerializer(note, data=request.data)
        if serializer.is_valid():
            await serializer.asave()
            return Response(await serializer.adata)
        return Response(serializer.errors, status=400)

    async def destroy(self, request, pk=None):
        queryset = await self.get_queryset()
        note = await queryset.aget(pk=pk)
        await note.adelete()
        return Response(status=204)

    
    @action(detail=False, methods=['get'])
    async def no_db_endpoint(self, request):
        return Response("no db endpoint", status=200)

    @action(detail=False, methods=['get'])
    async def no_db_endpoint2(self, request):
        return Response("no db endpoint2", status=200)
