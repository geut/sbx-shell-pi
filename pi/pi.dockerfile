FROM docker/sandbox-templates:shell

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
