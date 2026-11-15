SHARED_APPS = {"audit"}


class SharedRouter:
    """Keeps the audit app in the "shared" database and everything else in "default"."""

    def db_for_read(self, model, **hints):
        return "shared" if model._meta.app_label in SHARED_APPS else "default"

    db_for_write = db_for_read

    def allow_relation(self, obj1, obj2, **hints):
        return (obj1._meta.app_label in SHARED_APPS) == (obj2._meta.app_label in SHARED_APPS)

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        if app_label in SHARED_APPS:
            return db == "shared"
        return db == "default"
