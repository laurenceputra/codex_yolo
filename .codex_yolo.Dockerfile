ARG BASE_IMAGE=node:20-slim
FROM ${BASE_IMAGE}

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
  && rm -rf /var/lib/apt/lists/*

# Install Codex CLI (provides the `codex` binary).
RUN npm install -g @openai/codex

# Make a writable home for arbitrary UID/GID at runtime.
RUN mkdir -p /home/codex/.codex \
  && chmod -R 0777 /home/codex

# Record the installed Codex CLI version for update checks.
RUN node -e "process.stdout.write(require('/usr/local/lib/node_modules/@openai/codex/package.json').version)" \
  > /opt/codex-version

ENV HOME=/home/codex
WORKDIR /workspace
