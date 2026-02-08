ARG BASE_IMAGE=node:20-slim
FROM ${BASE_IMAGE}
ARG CODEX_VERSION=latest

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    gosu \
    openssh-client \
    passwd \
    sudo \
  && rm -rf /var/lib/apt/lists/*

# Install Codex CLI (provides the `codex` binary).
RUN npm install -g @openai/codex@${CODEX_VERSION}

# Make a writable home for arbitrary UID/GID at runtime.
RUN mkdir -p /home/codex/.codex \
  && chmod -R 0777 /home/codex

# Runtime entrypoint to create a matching user, enable sudo, and cleanup perms.
COPY .codex_yolo_entrypoint.sh /usr/local/bin/codex-entrypoint
COPY default-AGENTS.md /etc/codex/default-AGENTS.md
RUN chmod +x /usr/local/bin/codex-entrypoint \
  && chmod 0644 /etc/codex/default-AGENTS.md

# Record the installed Codex CLI version for update checks.
RUN node -e "process.stdout.write(require('/usr/local/lib/node_modules/@openai/codex/package.json').version)" \
  > /opt/codex-version

ENV HOME=/home/codex
WORKDIR /workspace
ENTRYPOINT ["codex-entrypoint"]
