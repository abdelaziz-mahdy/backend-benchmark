import json

from django.http import HttpResponse, HttpResponseNotAllowed, JsonResponse

from .models import Note


def _int(value, fallback):
    try:
        n = int(value)
    except (TypeError, ValueError):
        return fallback
    return n if n >= 0 else fallback


async def health(request):
    try:
        await Note.objects.aexists()
    except Exception as e:  # noqa: BLE001 - report any DB error as not ready
        return HttpResponse(f"not ready: {e}", status=503)
    return HttpResponse("ok")


async def no_db_endpoint(request):
    return JsonResponse({"message": "No db endpoint"})


async def notes(request):
    if request.method == "GET":
        limit = _int(request.GET.get("limit"), 20)
        offset = _int(request.GET.get("offset"), 0)
        qs = Note.objects.order_by("id").values("id", "title", "content")[offset : offset + limit]
        return JsonResponse([row async for row in qs], safe=False)
    if request.method == "POST":
        body = json.loads(request.body)
        note = await Note.objects.acreate(title=body["title"], content=body["content"])
        return JsonResponse({"id": note.id, "title": note.title, "content": note.content}, status=201)
    return HttpResponseNotAllowed(["GET", "POST"])


async def note_detail(request, note_id):
    note = await Note.objects.filter(pk=note_id).values("id", "title", "content").afirst()
    if note is None:
        return HttpResponse("not found", status=404)
    return JsonResponse(note)
