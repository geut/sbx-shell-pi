FROM docker/sandbox-templates:shell-docker

ARG PI_VERSION=latest
ARG FACTORY_VERSION=0.1.0
ARG HUNK_VERSION=0.24.1

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

ENV PATH="/home/agent/.hunk/bin:/home/agent/.npm-global/bin:/home/agent/.local/bin:${PATH}" \
    EDITOR=fresh

# agent-local npm "global" installs
RUN mkdir -p "$HOME/.npm-global" \
    && npm config set prefix "$HOME/.npm-global" \
    && printf '\n# npm user-global prefix\nexport PATH="$HOME/.npm-global/bin:$PATH"\nexport PATH="$HOME/.local/bin:$PATH"\n\n# Socket Firewall: bash npm goes through sfw\nalias npm="sfw npm"\n' >> ~/.bashrc \
    && npm install -g sfw \
    && sfw --help \
    && npm install -g --ignore-scripts "@earendil-works/pi-coding-agent@${PI_VERSION}" \
    && mkdir -p "$HOME/.pi/agent/extensions"

# Fresh editor (Linux universal build)
RUN printf '\n# Fresh editor\nexport PATH="$HOME/.local/bin:$PATH"\nexport EDITOR=fresh\n' >> ~/.bashrc \
    && curl -fsSL https://raw.githubusercontent.com/sinelaw/fresh/refs/heads/master/scripts/install.sh \
         | sh -s -- --no-desktop-integration \
    && fresh --version

# Hunk diff viewer (standalone binary). Default install dir keeps bundled skills
# beside the binary. ENV PATH is what non-interactive pane scripts inherit.
RUN curl -fsSL https://hunk.dev/install.sh \
      | HUNK_VERSION="${HUNK_VERSION}" HUNK_NO_MODIFY_PATH=1 HUNK_DISABLE_ANALYTICS=1 sh \
    && printf '\n# Hunk diff viewer\nexport PATH="$HOME/.hunk/bin:$PATH"\n' >> ~/.bashrc \
    && hunk --version \
    && bash -c 'command -v hunk' \
    && npx --yes skills add modem-dev/hunk --skill hunk-review -g -y --agent pi --copy

# Herdr + pi integration + agent skill
RUN printf '\n# Herdr installer path\nexport PATH="$HOME/.local/bin:$PATH"\n' >> ~/.bashrc \
    && curl -fsSL https://herdr.dev/install.sh | sh \
    && herdr integration install pi \
    && npx --yes skills add herdrdev/herdr --skill herdr -g -y --agent pi --copy

# pi-herdr-subagents: one main checkout, registered with pi and linked as an enabled Herdr plugin
RUN herdr_version="$(herdr --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)" \
    && { [ -n "$herdr_version" ] && [ "$(printf '%s\n%s\n' "0.8.2" "$herdr_version" | sort -V | head -n 1)" = "0.8.2" ] \
         || { echo "herdr >= 0.8.2 is required (found: ${herdr_version:-unknown})" >&2; exit 1; }; } \
    && mkdir -p "$HOME/.local/share" \
    && git clone --depth 1 --branch main https://github.com/modem-dev/pi-herdr-subagents.git "$HOME/.local/share/pi-herdr-subagents" \
    && pi install "$HOME/.local/share/pi-herdr-subagents" \
    && herdr plugin link "$HOME/.local/share/pi-herdr-subagents/herdr-plugin" --enabled \
    && pi list | tee /dev/stderr | grep -F "pi-herdr-subagents" \
    && herdr plugin list | tee /dev/stderr | grep -F "pi-herdr-subagents"

# Factory server: prebuilt binary from the geut/factory-skills release, checked against its .sha256
RUN case "$(dpkg --print-architecture)" in \
         amd64) FACTORY_ARCH="x64" ;; \
         arm64) FACTORY_ARCH="arm64" ;; \
         *) echo "unsupported arch: $(dpkg --print-architecture)" >&2; exit 1 ;; \
       esac \
    && asset="factory-linux-${FACTORY_ARCH}" \
    && base="https://github.com/geut/factory-skills/releases/download/v${FACTORY_VERSION}" \
    && cd /tmp \
    && curl -fsSLO "${base}/${asset}" \
    && curl -fsSL "${base}/${asset}.sha256" | sha256sum -c - \
    && mkdir -p "$HOME/.local/bin" \
    && install -m 0755 "${asset}" "$HOME/.local/bin/factory" \
    && rm "${asset}" \
    && factory --help

# factory-skills Pi package (the /factory command and stage skills), pinned to the same release as the binary
RUN pi install "git:github.com/geut/factory-skills@v${FACTORY_VERSION}" \
    && pi list | tee /dev/stderr | grep -F "git:github.com/geut/factory-skills@v${FACTORY_VERSION}"

# factory-up starts `factory serve` in a Herdr workspace and writes the dashboard token
COPY --chmod=0755 factory-up /usr/local/bin/factory-up

# Herdr reads ~/.config/herdr/config.toml for the agent user.
RUN mkdir -p "$HOME/.config/herdr" \
    && cat > "$HOME/.config/herdr/config.toml" <<'EOF'
onboarding = false

[theme]
name = "terminal"
auto_switch = true

[terminal]
default_shell = "/bin/bash"
kitty_graphics = true

[ui.sidebar.agents]
row_gap = 0
rows = [
  ["state_icon", "agent", "pane"],
  ["$status", "$task"],
  ["state_text"],
]

[ui.toast]
delivery = "herdr"
delay_seconds = 1

[ui.sound]
enabled = true
EOF

WORKDIR /home/agent/workspace
ENTRYPOINT ["herdr"]
CMD []
