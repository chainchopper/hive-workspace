# syntax=docker/dockerfile:1.6
FROM node:22-slim AS build
RUN corepack enable && apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app

COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --no-frozen-lockfile --config.ignore-scripts=true && pnpm rebuild esbuild

# Approve esbuild for the build step (needed by Vite/Rollup)
RUN pnpm approve-builds esbuild

COPY . .
RUN pnpm build

FROM node:22-slim AS stage-2
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && rm -rf /var/lib/apt/lists/*
RUN groupadd -r workspace && useradd -r -g workspace workspace
WORKDIR /app

COPY --from=build --chown=workspace:workspace /app/dist ./dist
COPY --from=build --chown=workspace:workspace /app/node_modules ./node_modules
COPY --from=build --chown=workspace:workspace /app/package.json ./package.json
COPY --from=build --chown=workspace:workspace /app/server-entry.js ./server-entry.js
COPY --from=build --chown=workspace:workspace /app/skills ./skills
COPY --chown=workspace:workspace docker/entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh
RUN curl -fsSL https://tailscale.com/install.sh | sh
RUN mkdir -p /home/workspace/.hermes && chown workspace:workspace /home/workspace
RUN mkdir -p /app/.runtime && chown workspace:workspace /app/.runtime
USER workspace
EXPOSE 3000
ENV NODE_ENV=production
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["node", "server-entry.js"]
