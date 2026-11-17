## Python

Use `uv` for Python: `uv sync`, `uv run`, `uv add`, `uv pip`. `uv` and `uvx` run through Socket Firewall (`sfw`) on their own, with or without a shell. uv always uses a uv-managed CPython, the version in `.python-version`; the system `python3` is not for projects. `gcc`, `pkg-config`, the libpq headers and `psql` are installed.

Run `uv` in your ticket's worktree, never at the main checkout's root. If `uv` refuses because a `.venv` was made by an interpreter that isn't in this sandbox, that environment belongs to the host: don't delete it or work around the refusal.

A worktree has no `.env` of its own unless setup writes one. A config loader that searches upward for `.env` (python-dotenv's `load_dotenv()` with no path) then reads the main checkout's, which may hold real credentials. Don't copy or read the main checkout's `.env`.

## Test services

A shared Postgres (`127.0.0.1:5432`, user `dev`/`dev` with CREATEDB, database `dev`; superuser `postgres`/`postgres`) and Redis (`127.0.0.1:6379`) run on the sandbox's Docker daemon for every worktree. `sandbox-services status` shows them; `sandbox-services start` starts what's missing. Don't start other Postgres or Redis containers for tests.

Other tickets test against the same servers at the same time. Run tests through `with-worktree-env` (e.g. `with-worktree-env uv run pytest`), which sets `WORKTREE_ID`, and keep test database names and Redis keys suffixed or prefixed with it. Check the project's `.factory/CONTEXT.md` for how it does this.
