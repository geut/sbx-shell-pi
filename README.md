# sbx-shell-pi

Custom template image for running [pi](https://pi.dev) inside Docker Sandboxes ([`sbx`](https://docs.docker.com/reference/cli/sbx/)).
___

> Docker Sandboxes (`sbx`) are a nice way to run coding agents with a bit more isolation and a bit less YOLO. There’s no “official” support for pi yet (see supported agents [`sbx create` docs](https://docs.docker.com/reference/cli/sbx/create/)), but it’s easy to add via a custom template image.


**Note**: At the time of writing, `sbx` only supports **public** template images (it won’t work with local images). Tracking issue: [docker/sbx-releases#29](https://github.com/docker/sbx-releases/issues/29).


**Note 2**: Docker also has a `docker sandbox` command that overlaps with `sbx`, but it seems to lag behind in features. I recommend sticking to `sbx`. This FAQ section was especially useful for passing custom environment variables: [How do I set custom environment variables inside a sandbox?](https://docs.docker.com/ai/sandboxes/faq/#how-do-i-set-custom-environment-variables-inside-a-sandbox).


## The Image

The [Dockerfile](./Dockerfile) extends the `shell` template, installs Node 24, installs `pi`, and tweaks `~/.bashrc` to auto-launch `pi` in interactive shells.

Published on GitHub Container Registry (GHCR): `ghcr.io/geut/sbx-shell-pi:node24`

## Usage

1. Install `sbx`: https://docs.docker.com/ai/sandboxes/

2. Run the template image

```bash
sbx run -t ghcr.io/geut/sbx-shell-pi:node24 shell [PROJECT_DIR]
```

## The Keys

How you provide credentials depends on the model/provider. For Claude/Codex and many others, sbx secret is a good starting point: https://docs.docker.com/reference/cli/sbx/secret/.

In my case, I use the OpenCode Zen service and need to pass OPENCODE_API_KEY. After some digging, this FAQ section on passing custom variables did the trick: 
[How do I set custom environment variables inside a sandbox?]
(https://docs.docker.com/ai/sandboxes/faq/#how-do-i-set-custom-environment-variables-inside-a-sandbox).

## Updating the Image

Update the Dockerfile, then build and push.

You’ll need a GitHub Personal Access Token (PAT) with at least read/write permissions for packages. 

```bash
docker build -t ghcr.io/geut/sbx-shell-pi:node24-auto-pi --push .
```

## Acknowledgements

This is based on Oleg Šelajev's article [Building custom Docker Sandboxes](https://olegselajev.substack.com/p/building-custom-docker-sandboxes). One key difference: local images never worked for me. `sbx save` completes, but referencing a local image fails. sbx appears to look up the image in a registry instead (you can see this by inspecting `sbx daemon` output).