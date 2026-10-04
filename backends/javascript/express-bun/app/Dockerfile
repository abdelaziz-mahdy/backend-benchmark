FROM oven/bun:1.3-slim
WORKDIR /app
ENV NODE_ENV=production
COPY package.json bun.lock ./
RUN bun install --production --frozen-lockfile
COPY server.js migration.sql ./
EXPOSE 8000
CMD ["bun", "run", "server.js"]
