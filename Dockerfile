# STAGE 1: Clone and Build Source (The "Heavy" part)
FROM node:24-alpine AS source-builder
# Added python3/make/g++ because the Pi needs them to build Trilium's frontend assets
RUN apk add --no-cache git python3 make g++ && corepack enable

WORKDIR /usr/src/app
RUN git clone https://github.com/TriliumNext/Trilium.git .
RUN pnpm install --no-frozen-lockfile
RUN pnpm run build

# STAGE 2: Build Native Modules (The "ARM-specific" part)
FROM node:24-alpine AS builder
# Pi MUST have these to compile better-sqlite3 for ARM64
RUN apk add --no-cache python3 make g++ && corepack enable
WORKDIR /usr/src/app
COPY --from=source-builder /usr/src/app/docker/package.json ./
COPY --from=source-builder /usr/src/app/docker/pnpm-workspace.yaml ./
RUN pnpm install --no-frozen-lockfile --prod && pnpm rebuild

# STAGE 3: Final Runtime (The "Slim" part)
FROM node:24-alpine
RUN apk add --no-cache su-exec shadow
WORKDIR /usr/src/app

COPY --from=source-builder /usr/src/app/dist /usr/src/app
COPY --from=source-builder /usr/src/app/start-docker.sh /usr/src/app
# Replace generic modules with your ARM-compiled version
RUN rm -rf /usr/src/app/node_modules/better-sqlite3
COPY --from=builder /usr/src/app/node_modules/better-sqlite3 /usr/src/app/node_modules/better-sqlite3

RUN adduser -s /bin/false -D node || true
EXPOSE 8080
CMD [ "sh", "./start-docker.sh" ]
