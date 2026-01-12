FROM oven/bun:1 AS builder
WORKDIR /app
COPY backend/package.json backend/bun.lock ./
RUN bun install --frozen-lockfile --production
COPY backend/src ./src
COPY backend/tsconfig.json ./

FROM oven/bun:1-slim
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/src ./src
COPY --from=builder /app/package.json ./
COPY --from=builder /app/tsconfig.json ./
RUN mkdir -p /data && chown -R bun:bun /data
USER bun
ENV NODE_ENV=production PORT=8080 DATABASE_PATH=/data/brew-haiku.db
EXPOSE 8080
CMD ["bun", "run", "src/index.ts"]
