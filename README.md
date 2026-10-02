# sbx-shell-pi

v3 sandbox kits for running [pi](https://pi.dev) inside Docker Sandboxes (`[sbx](https://docs.docker.com/ai/sandboxes/)`). Includes single-pi sandboxes and a **factory** kit where multiple pi sessions collaborate via [Herdr](https://herdr.dev).

---

> Docker Sandboxes (`sbx`) are a nice way to run coding agents with a bit more isolation and a bit less YOLO. These kits install pi on Node.js 24 or newer and launch it as the workload, instead of as a template under the built-in `shell` agent.

## The kits

### Single-pi kits

[pi/](./pi/) extends the `shell` template, installs Node 24 or newer, installs `pi`, and launches `pi`.

[pi-docker/](./pi-docker/) is the same kit on the [shell-docker](https://hub.docker.com/layers/docker/sandbox-templates/shell-docker/images/) template. With this kit, the agent has access to **its own docker daemon**.

Published on GitHub Container Registry (GHCR):

- `ghcr.io/geut/sbx-shell-pi:node24`
- `ghcr.io/geut/sbx-shell-pi:node24-docker`

### Factory kit 🏭

[factory/](./factory/) extends `shell-docker`. Herdr is the entrypoint: split panes and run `pi` in each one.

**Includes:**

- `docker/sandbox-templates:shell-docker` base (in-sandbox Docker daemon + sbx agent user)
- Node.js 24 or newer from [nodejs.org prebuilt binaries](https://nodejs.org/dist/) (`node_version` kit arg, default `24.20.0`)
- [pi](https://pi.dev) coding agent
- [Socket Firewall Free](https://github.com/SocketDev/sfw-free/) (`npm` in bash runs `sfw npm`)
- [Herdr](https://herdr.dev) terminal multiplexer
- `herdr integration install pi` (native pi lifecycle and session reporting in Herdr)
- Official Herdr agent skill (`npx skills add herdrdev/herdr --skill herdr -g`)
- [pi-herdr-subagents](https://github.com/modem-dev/pi-herdr-subagents) from `main`: `pi install` of `$HOME/.local/share/pi-herdr-subagents`, plus the bundled Herdr plugin linked and enabled. Example agent definitions are not copied; run `/subagents-init` inside pi if you want `worker`, `planner`, `scout`, and `reviewer`.
- [Fresh](https://github.com/sinelaw/fresh) terminal IDE (Linux universal build), default editor (`EDITOR=fresh`)

Published on GHCR: `ghcr.io/geut/sbx-shell-pi:node-24-factory`

The factory workload provides `node` at the installed `node_version` and `pi-factory@1`. The single-pi kits do not provide those names. A [factory-dashboard](https://github.com/dpaez/factory-dashboard) mixin that requires `node >= 24` and `pi-factory >= 1` composes only onto this workload. Herdr stays the entrypoint. The dashboard runs beside it and reads the project’s `.factory/db/state.sqlite`.

Once that mixin is published, add it when you create the sandbox:

```bash
sbx run --name factory ghcr.io/geut/sbx-shell-pi:node-24-factory /path/to/project \
  --kit ghcr.io/geut/sbx-kit-factory-dashboard:0.1.0
```

Create a new sandbox to change the mixin set. A published set of the two images can come later. A set lists registry references, so it cannot point at a local kit directory.

## Usage

1. Install `sbx` 0.45 or newer: [https://docs.docker.com/ai/sandboxes/](https://docs.docker.com/ai/sandboxes/)
2. Set your custom secret, usually the provider key. 
```bash
sbx secret set-custom --sandbox [SANDBOX_NAME] --host [provider.endpoint] --env [API_KEY_NAME] --value [SECRET]
```
3. Run a kit

**Single pi:**

```bash
sbx run --name pi ghcr.io/geut/sbx-shell-pi:node24 [PROJECT_DIR]
```

**Single pi with in-sandbox Docker daemon:**

```bash
sbx run --name pi-docker ghcr.io/geut/sbx-shell-pi:node24-docker [PROJECT_DIR]
```

**Factory — Herdr orchestrates multiple pi panes (with Docker for testing):**

```bash
sbx run --name factory ghcr.io/geut/sbx-shell-pi:node-24-factory [PROJECT_DIR]
```

From a checkout of this repo, pass the kit directory instead of the image:

```bash
sbx run --name pi ./pi [PROJECT_DIR]
sbx run --name pi-docker ./pi-docker [PROJECT_DIR]
sbx run --name factory ./factory [PROJECT_DIR]
```

`sbx` builds that directory with the OCI exporter. Docker Desktop’s default Buildx driver cannot do that export. Use a `docker-container` builder, or turn on the containerd image store, before running a local kit directory. A published image does not need that builder.

Single-pi kits open `pi`. The factory kit opens **Herdr**. Split panes in Herdr and run `pi` in each one for parallel agents (plan, implement, review, test).

Factory tips:

- Detach with Herdr prefix `ctrl+b` then `q` — agents keep running ([Herdr quick start](https://herdr.dev/docs/quick-start/))
- Reattach by running `sbx run [sandbox]` again
- **Fresh** is the default editor (`$EDITOR`); run `fresh` in a Herdr pane to edit files, or let agents/tools like `git commit` open it automatically

Further runs are simpler: list sandboxes (`sbx ls`) and run one (`sbx run [sandbox]`).

## The Keys

How you provide credentials depends on the model/provider. For Claude/Codex and many others, sbx secret is a good starting point: [https://docs.docker.com/reference/cli/sbx/secret/](https://docs.docker.com/reference/cli/sbx/secret/). Use [set-custom](https://docs.docker.com/reference/cli/sbx/secret/set-custom/) for other providers.

## Updating the kits

Update the kit directory, then build and push with Buildx. Pass the YAML descriptor to `-f` and the kit directory as the build context.

You’ll need a GitHub Personal Access Token (PAT) with at least read/write permissions for packages.

```bash
docker buildx build ./pi -f ./pi/pi.yaml \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/geut/sbx-shell-pi:node24 --push
```

```bash
docker buildx build ./pi-docker -f ./pi-docker/pi-docker.yaml \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/geut/sbx-shell-pi:node24-docker --push
```

```bash
docker buildx build ./factory -f ./factory/factory.yaml \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/geut/sbx-shell-pi:node-24-factory --push
```

Override the Node version with the kit argument name (`node_version`, not `NODE_VERSION`). The value must be 24 or newer:

```bash
docker buildx build ./factory -f ./factory/factory.yaml \
  --platform linux/amd64,linux/arm64 \
  --build-arg node_version=24.20.0 \
  -t ghcr.io/geut/sbx-shell-pi:node-24-factory \
  --push
```

## Acknowledgements

This is based on Oleg Šelajev's article [Building custom Docker Sandboxes](https://olegselajev.substack.com/p/building-custom-docker-sandboxes).