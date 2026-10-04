from django.urls import path

from notes import views

urlpatterns = [
    path("health", views.health),
    path("no_db_endpoint/", views.no_db_endpoint),
    path("notes/", views.notes),
    path("notes/<int:note_id>", views.note_detail),
]
