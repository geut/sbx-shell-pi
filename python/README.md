# python

A mixin for the [factory](../README.md) that gives a Python project what it needs: `uv` through Socket Firewall, a uv-managed CPython, and build tools for packages that compile. It only composes onto the factory (`requires: io.github.geut/pi-factory >= 1`).

```bash
sbx run --name factory ghcr.io/geut/sbx-shell-pi:node-24-factory /path/to/your/project \
  --kit ghcr.io/geut/sbx-shell-pi:python
```

Your project's own setup (Python version, dependencies, settings, task runner) and the services its tests need (databases, caches, queues) stay in your project. This kit doesn't ship any.

## What it adds

- **`uv` and `uvx`** in `/usr/local/bin`. They're wrappers that run the real binaries through [Socket Firewall](https://github.com/SocketDev/sfw-free/) (`sfw`), so every package download is checked, including commands the factory runs without a shell. `uv run --no-sync` and `uv run --offline` can't download, so they skip `sfw` (put the flag right after `run`). Other commands under `uv run` inherit `sfw`'s proxy for as long as they run. `/usr/local/lib/python-kit/bin/uv` is the real binary. `uv run`, `sync`, `add` and `remove` refuse to touch the project environment when its interpreter doesn't exist in the sandbox, such as the host's macOS `.venv` in a mounted checkout. That's the environment uv itself would use: `.venv` at the root of the workspace that `--project`, `--directory`, `UV_PROJECT` or the current directory selects (`uv workspace dir`). Set `UV_PROJECT_ENVIRONMENT` to use another directory. `python/test-uv-sfw` tests the guard.
- **A uv-managed CPython** for every project (`python-preference = "only-managed"` in `/etc/uv/uv.toml`). It follows `.python-version`, and unlike the base's Ubuntu `python3` it has the headers that C extensions build against. uv also copies packages from its cache (`link-mode = "copy"`): worktrees are on the host mount and the cache is in `$HOME`, so hard links fail anyway, and a second worktree's sync still downloads nothing.
- **`build-essential` and `pkg-config`**, installed with apt when the sandbox is created. This is an install hook, not part of the image: the factory image removes the compiler, and apt keeps the packages consistent with the image's own.
- **Network:** PyPI and uv's Python downloads at runtime; Ubuntu's archives (and the Docker and GitHub CLI apt repositories that `apt-get update` refreshes) at install.

## Your `FACTORY.json`

```json
{
  "worktree": { "setup": [{ "name": "install", "argv": ["uv", "sync", "--frozen"] }] },
  "validation": {
    "work": {
      "commands": [
        { "name": "lint", "argv": ["uv", "run", "--no-sync", "ruff", "check"] },
        { "name": "tests", "argv": ["uv", "run", "--no-sync", "pytest", "-x"], "timeoutMs": 1200000 }
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

## Services for tests

Postgres, Redis and anything else your tests need are your project's to bring, at the versions it uses, for example with a Compose file on the sandbox's own Docker daemon. The factory allows Docker Hub; for images from another registry, allow its host on your computer (`sbx policy allow network <host>`).

Tickets run in parallel, so tests from two worktrees can run at once. Either give each worktree its own services (a Compose project per worktree, on ports Docker assigns), or share one set and keep each worktree's databases and keys apart. Record how in `.factory/CONTEXT.md` so agents follow it.

Images, containers and volumes fill the sandbox's Docker volume, 10 GiB by default. A full suite with databases can outgrow it, so create the sandbox with a larger one (`DOCKER_SANDBOXES_DOCKER_SIZE=40g sbx create …`); see [Keep the code in the sandbox](../README.md#set-it-up).

## Private package index

Allow its host on your computer (`sbx policy allow network <host>`) and configure it in the project (`[[tool.uv.index]]`).

## Args

| Arg | Default | |
|---|---|---|
| `uv_version` | `0.13.8` | astral-sh/uv release, checked against its `.sha256` |

It's a build arg, so the published image carries the default. To change it, run the kit from a checkout: `--kit ./python --kit-arg uv_version=...`.
