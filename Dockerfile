FROM node:24-bookworm AS builder


ARG GH_VERSION=2.105.0
ARG CLAUDE_CODE_VERSION=2.1.331
ARG CODEX_CLI_VERSION=0.172.0
ARG OPENCODE_VERSION=1.19.6
ARG PI_VERSION=0.73.1
ARG POSTGRES_MAJOR_VERSION=17

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/* \
  && git --version

RUN set -eux; arch="$(dpkg --print-architecture)"; \
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${arch}.deb" \
      -o /tmp/gh.deb; \
    dpkg -i /tmp/gh.deb; \
    rm /tmp/gh.deb; \
    gh --version | grep -Fq "${GH_VERSION}"

RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
  && claude --version | grep -Fq "${CLAUDE_CODE_VERSION}"

RUN npm install -g "@openai/codex@${CODEX_CLI_VERSION}" \
  && codex --version | grep -Fq "${CODEX_CLI_VERSION}"

RUN npm install -g --allow-scripts=opencode-ai,koffi,protobufjs \
    "opencode-ai@${OPENCODE_VERSION}" \
    "@mariozechner/pi-coding-agent@${PI_VERSION}" \
  && opencode --version | grep -Fq "${OPENCODE_VERSION}" \
  && pi --version 2>&1 | grep -Fq "${PI_VERSION}"

RUN set -eux; \
    install -d /usr/share/postgresql-common/pgdg; \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
      -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc; \
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      "postgresql-${POSTGRES_MAJOR_VERSION}" \
      "postgresql-${POSTGRES_MAJOR_VERSION}-pgvector"; \
    rm -rf /var/lib/apt/lists/*; \
    "/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/postgres" --version
ENV PATH=/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin:$PATH

ENV COREPACK_HOME=/usr/local/share/corepack
RUN corepack enable \
  && corepack prepare yarn@4.12.0 --activate \
  && corepack prepare yarn@4.17.1 \
  && corepack prepare yarn@4.12.0 --activate \
  && yarn --version | grep -qx 4.12.0

COPY services/cezar.service services/open-mercato.service services/postgres.service /var/lib/systemd/system/


RUN groupmod -n open-mercato-builder node \
  && usermod -l open-mercato-builder -g open-mercato-builder -d /home/open-mercato-builder -m node \
  && test "$(id -u open-mercato-builder)" = "1000" \
  && test "$(id -g open-mercato-builder)" = "1000" \
  && mkdir -p /home/open-mercato-builder/workspace \
  && chown -R open-mercato-builder:open-mercato-builder /home/open-mercato-builder

ENV HOME=/home/open-mercato-builder
USER open-mercato-builder
WORKDIR /home/open-mercato-builder/workspace
