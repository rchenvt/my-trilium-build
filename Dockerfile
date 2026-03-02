
FROM alpine:3.23 AS downloader
ARG ARCH=arm64
ARG VERSION
RUN apk add --no-cache curl tar xz
WORKDIR /dist

RUN VERSION=$(curl -s https://api.github.com/repos/TriliumNext/Trilium/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/') \
 && curl -L https://github.com/TriliumNext/Trilium/releases/download/v${VERSION}/TriliumNotes-Server-v${VERSION}-linux-${ARCH}.tar.xz | tar -xJ --strip-components=1
WORKDIR /tmp
RUN curl -L https://raw.githubusercontent.com/TriliumNext/Trilium//main/apps/server/docker/package.json -o package.json \
 && curl -L https://raw.githubusercontent.com/TriliumNext/Trilium//main/apps/server/docker/pnpm-workspace.yaml -o pnpm-workspace.yaml \
 && curl -L https://raw.githubusercontent.com/TriliumNext/Trilium//main/apps/server/start-docker.sh -o start-docker.sh

FROM node:24.14.0-alpine AS builder
RUN corepack enable

# Install native dependencies since we might be building cross-platform.
WORKDIR /usr/src/app
COPY --from=downloader /tmp/package.json /tmp/pnpm-workspace.yaml /usr/src/app/
# We have to use --no-frozen-lockfile due to CKEditor patches
RUN pnpm install --no-frozen-lockfile --prod && pnpm rebuild

FROM node:24.14.0-alpine
# Install runtime dependencies
RUN apk add --no-cache su-exec shadow

WORKDIR /usr/src/app
COPY --from=downloader /dist /usr/src/app
RUN rm -rf /usr/src/app/node_modules/better-sqlite3
COPY --from=builder /usr/src/app/node_modules/better-sqlite3 /usr/src/app/node_modules/better-sqlite3
COPY --from=downloader /tmp/start-docker.sh /usr/src/app

# Add application user
RUN adduser -s /bin/false node; exit 0

# Configure container
EXPOSE 8080
CMD [ "sh", "./start-docker.sh" ]
HEALTHCHECK --start-period=10s CMD exec su-exec node node /usr/src/app/docker_healthcheck.cjs
