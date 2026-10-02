FROM docker/sandbox-templates:shell-docker

ARG NODE_VERSION=24.20.0
ARG PI_VERSION=latest

USER root

# Install Node.js from official prebuilt binaries (version overridable via --build-arg)
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl xz-utils \
    && ARCH="$(dpkg --print-architecture)" \
    && case "$ARCH" in \
         amd64) NODE_ARCH="x64" ;; \
         arm64) NODE_ARCH="arm64" ;; \
         *) echo "unsupported arch: $ARCH" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" \
         -o /tmp/node.tar.xz \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && node --version && npm --version \
    && apt-get purge -y xz-utils \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Non-interactive bash reads BASH_ENV, not ~/.bashrc. The shell template
# points BASH_ENV at this file.
RUN printf '\n# Socket Firewall alias for non-interactive bash\nshopt -s expand_aliases\nalias npm="sfw npm"\n' \
      >> /etc/sandbox-persistent.sh

USER agent

ENV PATH="/home/agent/.npm-global/bin:/home/agent/.local/bin:${PATH}" \
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
