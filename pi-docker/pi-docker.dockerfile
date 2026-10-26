FROM docker/sandbox-templates:shell-docker

ARG PI_VERSION=latest

USER root

# Latest Node.js 24.x. The tarball name includes the version, so the
# checksum list selects it: https://nodejs.org/dist/latest-v24.x/
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl xz-utils \
    && ARCH="$(dpkg --print-architecture)" \
    && case "$ARCH" in \
         amd64) NODE_ARCH="x64" ;; \
         arm64) NODE_ARCH="arm64" ;; \
         *) echo "unsupported arch: $ARCH" >&2; exit 1 ;; \
       esac \
    && curl -fsSL https://nodejs.org/dist/latest-v24.x/SHASUMS256.txt -o /tmp/node-SHASUMS256.txt \
    && NODE_TARBALL="$(grep -E "node-v[0-9.]+-linux-${NODE_ARCH}\\.tar\\.xz$" /tmp/node-SHASUMS256.txt | awk '{ print $2 }')" \
    && [ -n "$NODE_TARBALL" ] && [ "$(printf '%s\n' "$NODE_TARBALL" | wc -l)" -eq 1 ] \
    && curl -fsSL "https://nodejs.org/dist/latest-v24.x/${NODE_TARBALL}" -o "/tmp/${NODE_TARBALL}" \
    && grep -F " ${NODE_TARBALL}" /tmp/node-SHASUMS256.txt | (cd /tmp && sha256sum -c -) \
    && tar -xJf "/tmp/${NODE_TARBALL}" -C /usr/local --strip-components=1 \
    && rm -f "/tmp/${NODE_TARBALL}" /tmp/node-SHASUMS256.txt \
    && node --version && npm --version \
    && node -e 'const major = Number(process.versions.node.split(".")[0]); if (major !== 24) { console.error("node 24.x required, found " + process.versions.node); process.exit(1); }' \
    && apt-get purge -y xz-utils \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Non-interactive bash reads BASH_ENV, not ~/.bashrc. The shell template
# points BASH_ENV at this file.
RUN printf '\n# Socket Firewall alias for non-interactive bash\nshopt -s expand_aliases\nalias npm="sfw npm"\n' \
      >> /etc/sandbox-persistent.sh

USER agent

ENV PATH="/home/agent/.npm-global/bin:/home/agent/.local/bin:${PATH}"

# agent-local npm "global" installs
RUN mkdir -p "$HOME/.npm-global" \
    && npm config set prefix "$HOME/.npm-global" \
    && printf '\n# npm user-global prefix\nexport PATH="$HOME/.npm-global/bin:$PATH"\nexport PATH="$HOME/.local/bin:$PATH"\n\n# Socket Firewall: bash npm goes through sfw\nalias npm="sfw npm"\n' >> ~/.bashrc \
    && npm install -g sfw \
    && sfw --help \
    && npm install -g --ignore-scripts "@earendil-works/pi-coding-agent@${PI_VERSION}"

WORKDIR /home/agent/workspace
ENTRYPOINT ["pi"]
CMD []
