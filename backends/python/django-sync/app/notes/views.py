import json

from django.db import connection
from django.http import HttpResponse, HttpResponseNotAllowed, JsonResponse
from django.views.decorators.csrf import csrf_exempt

from .models import Note


def _int(value, fallback):
    try:
        n = int(value)
    except (TypeError, ValueError):
        return fallback
    return n if n >= 0 else fallback


def _as_dict(note):
    return {"id": note.id, "title": note.title, "content": note.content}


def health(request):
    try:
        connection.ensure_connection()
    except Exception as e:  # noqa: BLE001 - report any DB error as not ready
        return HttpResponse(f"not ready: {e}", status=503)
    return HttpResponse("ok")


def no_db_endpoint(request):
    return JsonResponse({"message": "No db endpoint"})


@csrf_exempt
def notes(request):
    if request.method == "GET":
        limit = _int(request.GET.get("limit"), 20)
        offset = _int(request.GET.get("offset"), 0)
        rows = Note.objects.order_by("id").values("id", "title", "content")[offset : offset + limit]
        return JsonResponse(list(rows), safe=False)
    if request.method == "POST":
        body = json.loads(request.body)
        note = Note.objects.create(title=body["title"], content=body["content"])
        return JsonResponse(_as_dict(note), status=201)
    return HttpResponseNotAllowed(["GET", "POST"])


def note_detail(request, note_id):
    note = Note.objects.filter(pk=note_id).values("id", "title", "content").first()
    if note is None:
        return HttpResponse("not found", status=404)
    return JsonResponse(note)
