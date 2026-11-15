import time

import pytest
from django.conf import settings
from django.core.cache import cache
from django.db import connections

from audit.models import AuditEntry
from notes.models import Note
from notes.services import create_note, note_count

pytestmark = pytest.mark.django_db(databases=["default", "shared"])


def test_test_databases_carry_the_worktree_id():
    suffix = f"_{settings.WORKTREE_ID}"
    for alias in ("default", "shared"):
        name = connections[alias].settings_dict["NAME"]
        assert name.startswith("test_") and name.endswith(suffix), name


def test_create_note_writes_both_databases():
    note = create_note("hello", "from the factory")

    assert Note.objects.using("default").filter(pk=note.pk).exists()
    entry = AuditEntry.objects.using("shared").get(object_id=note.pk)
    assert entry.action == "note.created"


def test_note_count_is_cached_per_worktree():
    cache.clear()
    create_note("one")
    assert note_count() == 1

    # Another worktree's key never collides: the cache prefix holds WORKTREE_ID.
    assert settings.WORKTREE_ID in cache.make_key("notes:count")

    create_note("two")
    assert note_count() == 2


def test_slow_enough_to_overlap():
    """Keeps the run open for a moment so two worktrees' runs overlap in the check."""
    create_note("overlap")
    time.sleep(2)
    assert Note.objects.count() == 1
