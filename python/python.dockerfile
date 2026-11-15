# The mixin's files: uv, Socket Firewall wrappers for it, its system config,
# and the service scripts. A mixin adds files and nothing else (its ENV is not
# the composed image's), so everything sits where the factory's PATH already
# looks. apt packages are installed at sandbox creation by python.yaml's
# install hook.
#
# The download stage runs on the builder's platform: uv is a static binary,
# so a multi-platform build needs no QEMU.
FROM --platform=$BUILDPLATFORM debian:trixie-slim AS download

ARG UV_VERSION=0.13.8
ARG TARGETARCH

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN set -eu; \
    case "${TARGETARCH}" in \
      amd64) triple="x86_64-unknown-linux-musl" ;; \
      arm64) triple="aarch64-unknown-linux-musl" ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    asset="uv-${triple}.tar.gz"; \
    base="https://github.com/astral-sh/uv/releases/download/${UV_VERSION}"; \
    curl -fsSLO "${base}/${asset}"; \
    curl -fsSL "${base}/${asset}.sha256" | sha256sum -c -; \
    mkdir -p /out/usr/local/lib/python-kit/bin; \
    tar -xzf "${asset}" --strip-components=1 -C /out/usr/local/lib/python-kit/bin "uv-${triple}/uv" "uv-${triple}/uvx"

FROM scratch
COPY --from=download /out/ /
COPY uv.toml /etc/uv/uv.toml
# uv and uvx on PATH are wrappers that run the real binaries through sfw.
COPY --chmod=0755 uv-sfw /usr/local/bin/uv
COPY --chmod=0755 uv-sfw /usr/local/bin/uvx
COPY --chmod=0755 sandbox-services with-worktree-env /usr/local/bin/
