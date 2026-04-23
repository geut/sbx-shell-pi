FROM docker/sandbox-templates:shell

USER root

# Install Node.js 24 from NodeSource
RUN apt-get update \
    && apt-get install -y curl ca-certificates gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER agent

# agent-local npm "global" installs
RUN mkdir -p "$HOME/.npm-global" \
  && npm config set prefix "$HOME/.npm-global" \
  && printf '\n# npm user-global prefix\nexport PATH="$HOME/.npm-global/bin:$PATH"\n' >> ~/.bashrc \
  && npm install -g @mariozechner/pi-coding-agent@latest

RUN printf '\n# Auto-launch pi coding agent in interactive shells\nif [[ $- == *i* ]] && command -v pi &> /dev/null; then\n    exec pi\nfi\n' >> ~/.bashrc