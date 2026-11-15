# A mixin adds files to the workload and nothing else: its ENV, USER and
# ENTRYPOINT are ignored. So every binary lands in /usr/local/bin (already on
# the workload's PATH, shell or not) and uv reads its settings from
# /etc/uv/uv.toml instead of environment variables.
#
# The build stages start FROM the workload's base image, so the apt packages
# and the interpreter match the Ubuntu release and the architecture they run
# on. Only /out reaches the final image.

# The Ubuntu release of docker/sandbox-templates:shell-docker (checked below).
ARG UBUNTU_VERSION=26.04

# --- uv and just: standalone musl binaries, checked against upstream sums ----
FROM docker/sandbox-templates:shell-docker AS tools

ARG UV_VERSION=0.13.8
ARG JUST_VERSION=1.59.0
ARG PYTHON_VERSION=3.13

USER root
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN case "$(dpkg --print-architecture)" in \
      amd64) triple="x86_64-unknown-linux-musl" ;; \
      arm64) triple="aarch64-unknown-linux-musl" ;; \
      *) echo "unsupported arch: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac \
    && mkdir -p /out/usr/local/bin /tmp/dl && cd /tmp/dl \
    && uv_asset="uv-${triple}.tar.gz" \
    && curl -fsSLO "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${uv_asset}" \
    && curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${uv_asset}.sha256" | sha256sum -c - \
    && tar -xzf "${uv_asset}" --strip-components=1 -C /out/usr/local/bin "uv-${triple}/uv" "uv-${triple}/uvx" \
    && just_asset="just-${JUST_VERSION}-${triple}.tar.gz" \
    && curl -fsSLO "https://github.com/casey/just/releases/download/${JUST_VERSION}/${just_asset}" \
    && curl -fsSL "https://github.com/casey/just/releases/download/${JUST_VERSION}/SHA256SUMS" | grep -F "  ${just_asset}" | sha256sum -c - \
    && tar -xzf "${just_asset}" -C /out/usr/local/bin just \
    && /out/usr/local/bin/uv --version \
    && /out/usr/local/bin/just --version \
    && rm -rf /tmp/dl

# The preinstalled interpreter: a python-build-standalone build from uv, owned
# by root under /opt/uv. uv finds it on PATH as a system interpreter; a
# project's .python-version that asks for another one makes uv download it
# into ~/.local/share/uv as usual.
RUN UV_PYTHON_INSTALL_DIR=/out/opt/uv/python UV_PYTHON_BIN_DIR=/tmp/pybin \
      /out/usr/local/bin/uv python install "${PYTHON_VERSION}" \
    && interp="$(find /out/opt/uv/python -mindepth 1 -maxdepth 1 -type d -name "cpython-${PYTHON_VERSION}*-linux-*" | sort | tail -n1)" \
    && [ -n "$interp" ] && interp="${interp#/out}" \
    && find /out/opt/uv/python -mindepth 1 -maxdepth 1 -type l -delete \
    && minor="$(/out${interp}/bin/python3 -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")')" \
    && for name in "python${minor}" python3 python; do \
         ln -sf "${interp}/bin/python${minor}" "/out/usr/local/bin/${name}"; \
       done \
    && rm -rf /tmp/pybin \
    && "/out${interp}/bin/python3" --version

# --- apt packages: their files and their dependencies' -----------------------
# dpkg's database stays the workload's; only the files are copied out. See
# collect-packages for why the whole dependency closure goes, minus the plain
# Ubuntu image's packages (the floor every workload on this release has).
FROM ubuntu:${UBUNTU_VERSION} AS floor
RUN dpkg-query -W -f='${Package}\n' | sort > /floor.txt

FROM docker/sandbox-templates:shell-docker AS packages

ARG UBUNTU_VERSION
USER root
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

COPY --from=floor /floor.txt /tmp/floor.txt
COPY --chmod=0755 collect-packages /usr/local/sbin/collect-packages
RUN . /etc/os-release \
    && if [ "$VERSION_ID" != "$UBUNTU_VERSION" ]; then \
         echo "The base is Ubuntu $VERSION_ID; the package floor is $UBUNTU_VERSION. Update UBUNTU_VERSION." >&2; exit 1; \
       fi \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
         build-essential pkg-config libpq-dev postgresql-client \
    && collect-packages /out /tmp/floor.txt build-essential pkg-config libpq-dev postgresql-client \
    && for top in bin sbin lib lib64; do \
         if [ -e "/out/$top" ] && [ ! -L "/out/$top" ]; then \
           echo "/out/$top would replace the workload's /$top symlink" >&2; exit 1; \
         fi; \
       done \
    && mkdir -p /out/etc \
    && ldconfig -C /out/etc/ld.so.cache \
    && rm -rf /var/lib/apt/lists/*

# --- the mixin ---------------------------------------------------------------
FROM scratch

COPY --from=packages /out/ /
COPY --from=tools /out/ /
COPY uv.toml /etc/uv/uv.toml
COPY --chmod=0755 sandbox-services with-worktree-env python-kit-startup /usr/local/bin/

# Which services sandbox-services starts, and their images. Written from the
# kit args at build time; the mixin cannot set environment variables.
ARG SERVICES=postgres,redis
ARG POSTGRES_VERSION=18
ARG REDIS_VERSION=8
COPY <<EOF /etc/python-kit/services.env
SERVICES=${SERVICES}
POSTGRES_IMAGE=postgres:${POSTGRES_VERSION}-alpine
REDIS_IMAGE=redis:${REDIS_VERSION}-alpine
EOF
