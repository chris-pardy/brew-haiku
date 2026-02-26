FROM oven/bun:1
WORKDIR /app

# Install dependencies — copy all workspace package.json files
COPY package.json bun.lock ./
COPY shared/package.json shared/
COPY ingest/package.json ingest/
COPY feed/package.json feed/
COPY timers/package.json timers/
COPY gateway/package.json gateway/
RUN bun install --frozen-lockfile

# Download classifier model (needed by ingest; feed/timers ignore it)
COPY ingest/scripts/download-model.ts ingest/scripts/
RUN bun run ingest/scripts/download-model.ts

# Copy application source
COPY shared/src/ shared/src/
COPY ingest/src/ ingest/src/
COPY feed/src/ feed/src/
COPY feed/feed-config.json feed/
COPY timers/src/ timers/src/
COPY timers/search-config.json timers/
COPY gateway/src/ gateway/src/

# Create volume mount point
RUN mkdir -p /data

ENV HOST=::
EXPOSE 8080 8081 8082 8083

# Default CMD — overridden by fly.toml [processes]
CMD ["bun", "run", "feed/src/index.ts"]
