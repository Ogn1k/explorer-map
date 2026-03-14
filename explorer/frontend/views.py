import json

from django.http import JsonResponse
from django.shortcuts import render
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from .models import MapMark

def map_view(request):
    return render(request, 'frontend/map.html')


def list_marks(request):
    marks = MapMark.objects.order_by("id").values(
        "id",
        "created_at",
        "latitude",
        "longitude",
        "name",
        "description",
    )
    return JsonResponse({"ok": True, "items": list(marks)})


@csrf_exempt
@require_POST
def add_mark(request):
    try:
        payload = json.loads(request.body or "{}")
    except json.JSONDecodeError:
        return JsonResponse({"ok": False, "error": "invalid_json"}, status=400)

    try:
        latitude = float(payload.get("latitude"))
        longitude = float(payload.get("longitude"))
    except (TypeError, ValueError):
        return JsonResponse({"ok": False, "error": "invalid_coordinates"}, status=400)

    mark = MapMark.objects.create(latitude=latitude, longitude=longitude)
    return JsonResponse(
        {
            "ok": True,
            "id": mark.pk,
            "created_at": mark.created_at.isoformat(),
            "name": mark.name,
            "description": mark.description,
        }
    )


@csrf_exempt
@require_POST
def delete_mark(request):
    try:
        payload = json.loads(request.body or "{}")
    except json.JSONDecodeError:
        return JsonResponse({"ok": False, "error": "invalid_json"}, status=400)

    mark_id = payload.get("id")
    if not mark_id:
        return JsonResponse({"ok": False, "error": "missing_id"}, status=400)

    deleted_count, _ = MapMark.objects.filter(pk=mark_id).delete()
    if deleted_count == 0:
        return JsonResponse({"ok": False, "error": "not_found"}, status=404)

    return JsonResponse({"ok": True, "id": mark_id})
