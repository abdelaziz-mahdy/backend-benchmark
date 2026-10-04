from django.db import models


class Note(models.Model):
    title = models.TextField()
    content = models.TextField()

    class Meta:
        db_table = "note"
