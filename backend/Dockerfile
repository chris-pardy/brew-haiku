FROM oven/bun:1 AS base
WORKDIR /app

# Install dependencies
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

# Download classifier model into the transformers.js cache
COPY scripts/download-model.ts scripts/
RUN bun run scripts/download-model.ts

# Copy application source and config
COPY src/ src/
COPY feed-config.json ./

# Create volume mount point for SQLite data
RUN mkdir -p /data

ENV DATABASE_PATH=/data/brew-haiku.db
ENV PORT=3000

EXPOSE 3000

CMD ["bun", "run", "src/index.ts"]
