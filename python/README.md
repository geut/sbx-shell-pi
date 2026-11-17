# python

A mixin for the [factory](../README.md) that gives a Python project what it needs: `uv` through Socket Firewall, build tools for packages that compile, and a shared Postgres and Redis for tests. It only composes onto the factory (`requires: io.github.geut/pi-factory >= 1`).

```bash
sbx run --name factory ghcr.io/geut/sbx-shell-pi:node-24-factory /path/to/your/project \
  --kit ghcr.io/geut/sbx-shell-pi:python
```

Your project's own setup (Python version, dependencies, settings, task runner) stays in your project. This kit doesn't ship any.

## What it adds

- **`uv` and `uvx`** in `/usr/local/bin`. They're wrappers that run the real binaries through [Socket Firewall](https://github.com/SocketDev/sfw-free/) (`sfw`), so every package download is checked, including commands the factory runs without a shell. `uv run --no-sync` and `uv run --offline` can't download, so they skip `sfw` (put the flag right after `run`). Other commands under `uv run` inherit `sfw`'s proxy for as long as they run. `/usr/local/lib/python-kit/bin/uv` is the real binary. `uv run`, `sync`, `add` and `remove` refuse to touch a `.venv` whose interpreter doesn't exist in the sandbox, such as the host's macOS one at the root of a mounted checkout; set `UV_PROJECT_ENVIRONMENT` to use another directory.
- **A uv-managed CPython** for every project (`python-preference = "only-managed"` in `/etc/uv/uv.toml`). It follows `.python-version`, and unlike the base's Ubuntu `python3` it has the headers that C extensions build against. uv also copies packages from its cache (`link-mode = "copy"`): worktrees are on the host mount and the cache is in `$HOME`, so hard links fail anyway, and a second worktree's sync still downloads nothing.
- **`build-essential`, `pkg-config`, `libpq-dev` and `postgresql-client`**, installed with apt when the sandbox is created (about 45 s). This is an install hook, not part of the image: the factory image removes the compiler, and apt keeps the packages consistent with the image's own.
- **`sandbox-services start | stop | status`**: Postgres 18 and Redis 8 on the sandbox's Docker daemon, started at boot and shared by every worktree. The boot log is `~/.local/state/python-kit/services.log`.

  | Service | Address | Credentials |
  |---|---|---|
  | Postgres | `127.0.0.1:5432` | `dev`/`dev` (CREATEDB), database `dev`; superuser `postgres`/`postgres` |
  | Redis | `127.0.0.1:6379` | none |

- **`with-worktree-env <cmd>`** runs a command with `WORKTREE_ID`, 8 hex characters that stay the same for the current git worktree.
- **Network:** PyPI and Docker Hub at runtime; Ubuntu's archives (and the Docker and GitHub CLI apt repositories that `apt-get update` refreshes) at install.

## Your `FACTORY.json`

```json
{
  "worktree": { "setup": [{ "name": "install", "argv": ["uv", "sync", "--frozen"] }] },
  "validation": {
    "work": {
      "commands": [
        { "name": "lint", "argv": ["uv", "run", "--no-sync", "ruff", "check"] },
        { "name": "tests", "argv": ["with-worktree-env", "uv", "run", "--no-sync", "pytest", "-x"], "timeoutMs": 1200000 }
      ]
    }
  }
}
```

Setup installs the dependencies through `sfw`, and validation runs with `--no-sync`: a dependency an agent adds mid-ticket must go through `uv add` or `uv sync`, which `sfw` checks, rather than being installed on the side by a validation command. The default validation timeout is 60 s, too short for most database suites. In a large repository, validate with a scoped command (the tests for what changed) and leave the full suite to CI.

## The host's checkout

With the project mounted from the host (the default), the main checkout's `.venv` and `.env` are the host's. A ticket worktree gets its own `.venv` from `uv sync`, but no `.env`, and a loader that searches upward for one (python-dotenv's `load_dotenv()` with no path) finds the main checkout's: the host developer's real configuration. Write the worktree's `.env` in setup, from the project's test template, before anything loads settings:

```json
{ "worktree": { "setup": [
  { "name": "env", "argv": ["cp", ".env.test.example", ".env"] },
  { "name": "install", "argv": ["uv", "sync", "--frozen"] }
] } }
```

Other config loaders that search upward need the same. To keep the host's files out of the sandbox altogether, [keep the code in the sandbox](../README.md#keep-the-code-in-the-sandbox).

## Parallel tickets on one database server

Tickets test at the same time against the same Postgres and Redis. Default test database names (`test_<NAME>` in Django) collide, so one run drops or blocks the other. Read `WORKTREE_ID` in your test settings:

- **Django:** `DATABASES[alias]["TEST"]["NAME"] = f"test_<name>_{WORKTREE_ID}"` for every alias, and `KEY_PREFIX` on Redis caches. `cache.clear()` flushes the whole Redis database, every worktree's keys included, so delete by key in tests instead.
- **SQLAlchemy / FastAPI:** create `test_<name>_{WORKTREE_ID}` in a session fixture and point the engine at it.
- **Celery:** run tasks eagerly in tests, or prefix keys (`broker_transport_options = {"global_keyprefix": ...}`).

Record this in `.factory/CONTEXT.md` so agents follow it.

## Private package index

Allow its host on your computer (`sbx policy allow network <host>`) and configure it in the project (`[[tool.uv.index]]`).

## Args

| Arg | Default | |
|---|---|---|
| `uv_version` | `0.13.8` | astral-sh/uv release, checked against its `.sha256` |

It's a build arg, so the published image carries the default. To change it, run the kit from a checkout: `--kit ./python --kit-arg uv_version=...`.
