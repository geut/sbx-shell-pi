# sbx-shell-pi

Custom template images for running [pi](https://pi.dev) inside Docker Sandboxes ([`sbx`](https://docs.docker.com/reference/cli/sbx/)). Includes single-pi sandboxes and a **factory** variant where multiple pi sessions collaborate via [Herdr](https://herdr.dev).
___

> Docker Sandboxes (`sbx`) are a nice way to run coding agents with a bit more isolation and a bit less YOLO. There’s no “official” support for pi yet (see supported agents [`sbx create` docs](https://docs.docker.com/reference/cli/sbx/create/)), but it’s easy to add via a custom template image.

**Note**: Docker also has a `docker sandbox` command that overlaps with `sbx`, but it seems to lag behind in features. I recommend sticking to `sbx`. This FAQ section was especially useful for passing custom environment variables: [How do I set custom environment variables inside a sandbox?](https://docs.docker.com/ai/sandboxes/faq/#how-do-i-set-custom-environment-variables-inside-a-sandbox).


## The Images

### Single-pi images

The [Dockerfile](./Dockerfile) extends the `shell` template, installs Node 24, installs `pi`, and tweaks `~/.bashrc` to auto-launch `pi` in interactive shells.

There is also a [Dockerfile.shell-docker](./Dockerfile.shell-docker) file whose only difference is that it uses the [shell-docker](https://hub.docker.com/layers/docker/sandbox-templates/shell-docker/images/) image. With this image, the agent has access to **its own docker daemon**.

Published on GitHub Container Registry (GHCR):
- `ghcr.io/geut/sbx-shell-pi:node24`
- `ghcr.io/geut/sbx-shell-pi:node24-docker`

### Factory image

The [Dockerfile.factory](./Dockerfile.factory) extends `shell-docker` and is the first step toward a **factory sandbox** — multiple pi sessions working together on planning, implementing, reviewing, and testing.

**Includes:**
- `docker/sandbox-templates:shell-docker` base (in-sandbox Docker daemon + sbx agent user)
- Node.js v24 from [nodejs.org prebuilt binaries](https://nodejs.org/dist/) (`NODE_VERSION` build arg, default latest v24)
- [pi](https://pi.dev) coding agent
- [Herdr](https://herdr.dev) terminal multiplexer
- `herdr integration install pi` (native pi lifecycle and session reporting in Herdr)
- Official Herdr agent skill (`npx skills add herdrdev/herdr --skill herdr -g`)
- [Fresh](https://github.com/sinelaw/fresh) terminal IDE (Linux universal build), default editor (`EDITOR=fresh`)
- Auto-launches Herdr on interactive shell entry (start `pi` inside Herdr panes)

Published on GHCR: `ghcr.io/geut/sbx-shell-pi:node-24-factory`

## Usage

1. Install `sbx`: https://docs.docker.com/ai/sandboxes/

2. Run a template image

**Single pi (default shell template):**

```bash
sbx run -t ghcr.io/geut/sbx-shell-pi:node24 shell [PROJECT_DIR]
```

**Single pi with in-sandbox Docker daemon:**

```bash
sbx run -t ghcr.io/geut/sbx-shell-pi:node24-docker shell [PROJECT_DIR]
```

**Factory — Herdr orchestrates multiple pi panes (with Docker for testing):**

```bash
sbx run -t ghcr.io/geut/sbx-shell-pi:node-24-factory shell [PROJECT_DIR]
```

This loads the template image and starts the sandbox. Single-pi images auto-launch `pi`; the factory image auto-launches **Herdr**. Split panes in Herdr and run `pi` in each one for parallel agents (plan, implement, review, test).

Factory tips:
- Detach with Herdr prefix `ctrl+b` then `q` — agents keep running ([Herdr quick start](https://herdr.dev/docs/quick-start/))
- Reattach by running `sbx run [sandbox]` again
- **Fresh** is the default editor (`$EDITOR`); run `fresh` in a Herdr pane to edit files, or let agents/tools like `git commit` open it automatically

Further runs are simpler: list sandboxes (`sbx ls`) and run one (`sbx run [sandbox]`).

## The Keys

How you provide credentials depends on the model/provider. For Claude/Codex and many others, sbx secret is a good starting point: https://docs.docker.com/reference/cli/sbx/secret/.

In my case, I use the OpenCode Zen service and need to pass OPENCODE_API_KEY. After some digging, this FAQ section on passing custom variables did the trick:
[How do I set custom environment variables inside a sandbox?](https://docs.docker.com/ai/sandboxes/faq/#how-do-i-set-custom-environment-variables-inside-a-sandbox).

## Updating the Image

Update the Dockerfile, then build and push.

You’ll need a GitHub Personal Access Token (PAT) with at least read/write permissions for packages.

```bash
docker build -t ghcr.io/geut/sbx-shell-pi:node24 --push .
```

```bash
docker build -f Dockerfile.shell-docker -t ghcr.io/geut/sbx-shell-pi:node24-docker --push .
```

```bash
docker build -f Dockerfile.factory -t ghcr.io/geut/sbx-shell-pi:node-24-factory --push .
```

Override the Node version (for a future builder tool or manual builds):

```bash
docker build -f Dockerfile.factory \
  --build-arg NODE_VERSION=24.20.0 \
  -t ghcr.io/geut/sbx-shell-pi:node-24-factory \
  --push .
```

## Acknowledgements

This is based on Oleg Šelajev's article [Building custom Docker Sandboxes](https://olegselajev.substack.com/p/building-custom-docker-sandboxes). 