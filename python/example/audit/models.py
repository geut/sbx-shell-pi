from django.db import models


class AuditEntry(models.Model):
    """Lives in the "shared" database (see config.routers)."""

    action = models.CharField(max_length=50)
    object_id = models.BigIntegerField()
    created_at = models.DateTimeField(auto_now_add=True)
