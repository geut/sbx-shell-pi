# sbx-shell-pi

Run [pi](https://pi.dev) coding agents inside [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`): a bit more isolation, a bit less YOLO.

The main kit is the **factory** 🏭: a sandbox where several pi agents work on your project's tickets in parallel, organized in [Herdr](https://herdr.dev) panes, with an optional web dashboard. There are also [single-pi kits](#other-kits) if you only want one agent.

- [Set up the factory](#set-up-the-factory)
- [Everyday use](#everyday-use)
- [Reference](#reference)
- [Other kits](#other-kits)
- [Developing these kits](#developing-these-kits)

## Set up the factory

You need Docker Desktop and `sbx` 0.47 or newer ([install `sbx`](https://docs.docker.com/ai/sandboxes/)). Run every command in this section on your computer (the host), unless a step says "in the sandbox".

### 1. Allow the kit sources

`sbx` only installs kits from sources on its allowlist, and by default that is Docker Hub alone. Allow the factory (`ghcr.io/geut/`) and the dashboard (`ghcr.io/dpaez/`):

```bash
sbx settings set kit.allowedSources '["docker.io/","ghcr.io/geut/","ghcr.io/dpaez/"]'
```

This replaces the whole list. If `sbx settings get kit.allowedSources` already shows other sources, keep them in the new list.

### 2. Create the sandbox

```bash
sbx run --name factory ghcr.io/geut/sbx-shell-pi:node-24-factory /path/to/your/project \
  --kit ghcr.io/dpaez/sbx-kit-factory-dashboard:0.2.0
```

The `--kit` line adds the [dashboard](https://github.com/dpaez/factory-dashboard). Leave it out if you don't want it. The kit set is fixed when the sandbox is created, so adding the dashboard later means creating a new sandbox.

When the sandbox starts, you land in **Herdr**, a terminal multiplexer where the agents run side by side.

### 3. Add your model provider key

The agents need an API key for your model provider. In a second terminal on the host:

```bash
sbx secret set-custom --sandbox factory --host [provider.endpoint] --env [API_KEY_NAME] --value [SECRET]
```

Many providers have a built-in shortcut instead; see [`sbx secret`](https://docs.docker.com/reference/cli/sbx/secret/). The key never enters the sandbox: the sandbox proxy adds it to outgoing requests.

### 4. Start the factory (in the sandbox)

In the Herdr pane, from your project's root:

```bash
cd "$WORKSPACE_DIR"   # your project, if you're not already there
factory-up
```

The first time, this creates `.factory/FACTORY.json` with starter settings, then starts the factory server in a Herdr workspace named `factory`. Open `.factory/FACTORY.json` and check the models (`models.work` and `models.review`) before going on. The [factory-skills README](https://github.com/geut/factory-skills#factory-root) explains every setting.

Then start `pi` in a pane and run:

```text
/factory start
```

Each ticket gets its own Herdr tab, with agents for planning, work, review and wrap-up.

### 5. Open the dashboard

On the host:

```bash
sbx ports factory
```

Open the host port listed for `factory-dashboard` in your browser. Until `factory-up` has run, the dashboard shows a page asking you to run it.

## Everyday use

- **Detach** from Herdr with `ctrl+b`, then `q`. The agents keep running ([Herdr quick start](https://herdr.dev/docs/quick-start/)).
- **Reattach** with `sbx run factory`. `sbx ls` lists your sandboxes.
- **After a restart** (`sbx stop`, then `sbx run factory`), the factory server starts again by itself once Herdr is up. There's no need to run `factory-up` again.
- **Edit files** with `fresh`, the default editor. **Review diffs** with `hunk diff`.

## Reference

### What's in the factory sandbox

- The [`shell-docker`](https://hub.docker.com/r/docker/sandbox-templates) base, so agents get **their own Docker daemon** for tests
- Latest Node.js 24.x, checked against `SHASUMS256.txt`
- [pi](https://pi.dev), with `npm` going through [Socket Firewall](https://github.com/SocketDev/sfw-free/) (`sfw npm`) in bash
- [Herdr](https://herdr.dev) as the entrypoint, with its pi integration and agent skill
- `factory` and the [factory-skills](https://github.com/geut/factory-skills) pi package (the `/factory` command and stage skills), from the same release (`factory_version` kit arg, default `0.2.0`). The binary is checked against the release's `.sha256`.
- `factory-up` and a startup hook that restarts the server at boot
- [GitHub CLI](https://cli.github.com/) (`gh`)
- [Fresh](https://github.com/sinelaw/fresh) editor (`$EDITOR`)
- [Hunk](https://github.com/modem-dev/hunk) diff viewer and its `hunk-review` skill for pi (`hunk_version` kit arg, default `0.24.1`)

### What `factory-up` does

Run it from the repository root in any Herdr pane. It:

1. **Creates `.factory/FACTORY.json`** if the repository has none. The starter config sets `name` to the directory name, `models.work` to `anthropic/claude-sonnet-5-5`, `models.review` to `anthropic/claude-opus-5-5`, and `server` to `0.0.0.0:7731`. Set `FACTORY_WORK_MODEL` and `FACTORY_REVIEW_MODEL` to choose other models (they must differ). When `origin` is a GitHub remote, it also fills in `tracker` (backlog label `factory`) and `codeHost` with `pullRequests: false`. An existing `FACTORY.json` is never rewritten, except for step 2.
2. **Makes the server reachable.** It sets `server.host` to `0.0.0.0` when the host is missing, `127.0.0.1` or `localhost`, because a published port can't reach the sandbox's loopback. Any other host stays as you set it, with a warning. If a server is already running on the old host, `factory-up` asks you to stop it and run again.
3. **Starts `factory serve`** in a Herdr workspace named `factory` (the server refuses to start outside Herdr). If a server already answers on `/health`, this step is skipped.
4. **Writes the dashboard's token** to `.factory/dashboard.env` (mode `0600`):

   ```bash
   FACTORY_API_URL=http://127.0.0.1:7731
   FACTORY_API_TOKEN=...
   ```

   Tokens are shown only once, so `factory-up` keeps a token the server still accepts and replaces a revoked one. The token stays on the dashboard's server and never reaches the browser.

The kit publishes container port `7731` as `factory-api`; `sbx ports factory` shows its host port. The server speaks plain HTTP. If you change `server.port`, the published port no longer matches.

**At boot**, `factory-autostart` waits for Herdr (which starts when you attach), then runs `factory-up` for `$WORKSPACE_DIR`, but only if `factory-up` ran there before. Its log is `~/.local/state/factory/autostart.log`.

**GitHub webhooks (optional).** To verify webhooks, the server needs the secret named by `codeHost.webhookSecretEnv`, for example `FACTORY_GITHUB_WEBHOOK_SECRET`. sbx secrets only reach the sandbox as placeholders, so they can't verify an incoming signature. Pass the real value to `factory-up`:

```bash
FACTORY_GITHUB_WEBHOOK_SECRET=... factory-up
```

### Factory contract

For mixin authors. The factory workload provides `node@24` and `io.github.geut/pi-factory@1`. The single-pi kits provide neither, so a mixin that requires them only composes onto the factory. A mixin that requires `io.github.geut/pi-factory >= 1` can rely on this:

- `factory` and `factory-up` are on `PATH` for the `agent` user, in non-interactive shells too.
- Herdr is the entrypoint. `factory serve` runs in a Herdr pane, which `factory-up` opens.
- After a restart, a startup hook reruns `factory-up` for `$WORKSPACE_DIR` once Herdr is up, if `factory-up` ran there before. Until then the API refuses connections.
- The server listens on container port `7731` on `0.0.0.0`, published as `factory-api`.
- `factory-up` writes `.factory/dashboard.env` (mode `0600`) at the repository root, with `FACTORY_API_URL`, reachable from inside the sandbox, and `FACTORY_API_TOKEN`, an `act` token for the `dashboard` client. It replaces the file only when the server rejects the token. For the sandbox's own repository, that is `$WORKSPACE_DIR/.factory/dashboard.env`.

A change that breaks any of these bumps the major version. The name uses the `io.github.geut/` namespace because bare names belong to Docker's `com.docker.kit/` vocabulary.

The [dashboard](https://github.com/dpaez/factory-dashboard) is such a mixin: it runs beside Herdr on container port `7732` and reads the factory through the server's REST API, using `.factory/dashboard.env`.

## Other kits

Single-agent sandboxes that open `pi` directly:

| Kit | Image | Base |
|---|---|---|
| [pi/](./pi/) | `ghcr.io/geut/sbx-shell-pi:node24` | `shell` |
| [pi-docker/](./pi-docker/) | `ghcr.io/geut/sbx-shell-pi:node24-docker` | `shell-docker` (its own Docker daemon) |

```bash
sbx run --name pi ghcr.io/geut/sbx-shell-pi:node24 /path/to/your/project
```

Steps 1 and 3 of the [factory setup](#set-up-the-factory) apply here too.

## Developing these kits

### Run a kit from a checkout

Pass the kit directory instead of the image:

```bash
sbx run --name factory ./factory /path/to/your/project
```

`sbx` builds the directory with the OCI exporter, which Docker Desktop's default Buildx driver can't do. Use a `docker-container` builder, or turn on the containerd image store:

```bash
docker buildx create --name kits --driver docker-container --use
```

### Publish

Merge the change to `main`, then run the **Publish kits** workflow from the Actions tab and pick one kit or `all`:

```bash
gh workflow run publish.yml --repo geut/sbx-shell-pi -f kit=factory
```

It builds `linux/amd64` and `linux/arm64` in one Buildx call, pushes the image to GHCR, and checks the result.

To publish by hand, you need a GitHub token with read/write access to packages:

```bash
docker buildx build ./factory -f ./factory/factory.yaml \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/geut/sbx-shell-pi:node-24-factory --push
```

Use `./pi` with `pi.yaml` and tag `node24`, or `./pi-docker` with `pi-docker.yaml` and tag `node24-docker`, for the other kits. The platform that isn't your machine's builds under QEMU. If it fails with `Cannot open: Function not implemented`, update the emulators with `docker run --privileged --rm tonistiigi/binfmt --install all`.

## Acknowledgements

Based on Oleg Šelajev's article [Building custom Docker Sandboxes](https://olegselajev.substack.com/p/building-custom-docker-sandboxes).
