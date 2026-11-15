## Python

`python`, `python3`, `uv`, `uvx` and `just` are in `/usr/local/bin`, so they work with or without a shell. The preinstalled interpreter is CPython from `uv python install`. A project's `.python-version` wins: `uv` downloads that version on first use. `psql`, `pg_isready`, `pkg-config`, a C compiler and the libpq headers are installed too.

Install packages through [Socket Firewall](https://github.com/SocketDev/sfw-free/). In bash, `pip` and `uv` are aliases for `sfw pip` and `sfw uv`. Commands the factory runs without a shell (`FACTORY.json`) must say it explicitly, e.g. `["sfw", "uv", "sync", "--frozen"]`. Use `uv` for project environments. Don't install into the system interpreter.

The workspace is a host mount, so `uv` copies packages from its cache in `~/.cache/uv` (`link-mode = "copy"` in `/etc/uv/uv.toml`). A second worktree's `uv sync` downloads nothing.

The frontend toolchain is the factory's Node 24 (`npm` goes through `sfw`). `sfw pnpm` and `sfw yarn` work the same way.

## Test services

One Postgres and one Redis serve every worktree. They run on the sandbox's own Docker daemon and start at boot.

| Service | Address | Credentials |
|---|---|---|
| Postgres | `127.0.0.1:5432` | `dev` / `dev`, database `dev`, may create databases. Superuser `postgres` / `postgres` for extensions. |
| Redis | `127.0.0.1:6379` | none |

`sandbox-services status` shows what is up. `sandbox-services start` starts what's missing and is safe to run again. The boot log is `~/.local/state/python-kit/services.log`. Don't start your own Postgres or Redis containers for tests, and don't stop these.

## Worktree isolation

Several tickets test at the same time against the same servers. Run tests through `with-worktree-env`, which exports `WORKTREE_ID` (8 hex characters, stable per worktree) and `WORKTREE_ROOT`:

```bash
with-worktree-env uv run pytest path/to/test_file.py::test_name
```

The project uses `WORKTREE_ID` to keep its test data apart: suffixed test database names (Django `DATABASES[alias]["TEST"]["NAME"]`, or the SQLAlchemy test URL), and a Redis key prefix for Celery and caches. If the project doesn't read it yet, check its `CONTEXT.md` or settings before running tests in parallel.
