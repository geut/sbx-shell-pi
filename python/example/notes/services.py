from django.core.cache import cache
from django.db import transaction

from audit.models import AuditEntry
from notes.models import Note


def create_note(title: str, body: str = "") -> Note:
    """Writes the note to "default" and its audit entry to "shared"."""
    with transaction.atomic(using="default"), transaction.atomic(using="shared"):
        note = Note.objects.create(title=title, body=body)
        AuditEntry.objects.create(action="note.created", object_id=note.pk)
    cache.delete("notes:count")
    return note


def note_count() -> int:
    count = cache.get("notes:count")
    if count is None:
        count = Note.objects.count()
        cache.set("notes:count", count, timeout=60)
    return count
