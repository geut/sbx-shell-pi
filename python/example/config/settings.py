"""Settings for the sample project.

Two database aliases on the sandbox's shared Postgres (the app's own data and a
"shared" database, as in a multi-database product) and a Redis cache.

Several worktrees run these tests at the same time against one server, so
every name a test run creates carries WORKTREE_ID, which `with-worktree-env`
exports. Without it (a plain `pytest`), the suffix is "local".
"""

import os

WORKTREE_ID = os.environ.get("WORKTREE_ID", "local")

SECRET_KEY = "not-a-secret: sample project only"
DEBUG = True
ALLOWED_HOSTS: list[str] = []
USE_TZ = True
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

INSTALLED_APPS = [
    "django.contrib.contenttypes",
    "django.contrib.auth",
    "notes",
    "audit",
]


def _database(name: str) -> dict:
    return {
        "ENGINE": "django.db.backends.postgresql",
        "HOST": os.environ.get("POSTGRES_HOST", "127.0.0.1"),
        "PORT": os.environ.get("POSTGRES_PORT", "5432"),
        "USER": os.environ.get("POSTGRES_USER", "dev"),
        "PASSWORD": os.environ.get("POSTGRES_PASSWORD", "dev"),
        "NAME": name,
        # test_<name> by default: the same for every worktree. Suffix it.
        "TEST": {"NAME": f"test_{name}_{WORKTREE_ID}"},
    }


DATABASES = {
    "default": _database("example"),
    "shared": _database("example_shared"),
}
DATABASE_ROUTERS = ["config.routers.SharedRouter"]

CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": os.environ.get("REDIS_URL", "redis://127.0.0.1:6379/0"),
        # One Redis serves every worktree: keep their keys apart.
        "KEY_PREFIX": f"example:{WORKTREE_ID}",
    }
}
