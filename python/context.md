## Python

Use `uv` for Python: `uv sync`, `uv run`, `uv add`, `uv pip`. `uv` and `uvx` run through Socket Firewall (`sfw`) on their own, with or without a shell. uv always uses a uv-managed CPython, the version in `.python-version`; the system `python3` is not for projects. `gcc` and `pkg-config` are installed.

Run `uv` in your ticket's worktree, never at the main checkout's root. If `uv` refuses because a `.venv` was made by an interpreter that isn't in this sandbox, that environment belongs to the host: don't delete it or work around the refusal.

A worktree has no `.env` of its own unless setup writes one. A config loader that searches upward for `.env` (python-dotenv's `load_dotenv()` with no path) then reads the main checkout's, which may hold real credentials. Don't copy or read the main checkout's `.env`.

Databases, caches and other services the tests need come from the project, not from this sandbox. Check the project's `.factory/CONTEXT.md` for how to start them and how tickets running at the same time keep apart.
