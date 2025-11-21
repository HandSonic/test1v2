ARG GO_VERSION=1.24
ARG NODE_VERSION=20
ARG VERSION=v2.0.13
ARG TARGET_ARCH=loong64

FROM node:${NODE_VERSION}-bookworm AS frontend-builder
ARG VERSION
ENV VERSION=${VERSION}
ENV NODE_OPTIONS=--max-old-space-size=8192

RUN set -ex \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

RUN git clone -b ${VERSION} --depth=1 https://github.com/1Panel-dev/1Panel /src

WORKDIR /src/frontend

RUN set -ex \
    && npm install \
    && npm run build:pro \
    && rm -rf node_modules ~/.npm

FROM golang:${GO_VERSION}-bookworm AS builder
ARG VERSION
ARG TARGET_ARCH
ENV VERSION=${VERSION}
ENV TARGET_ARCH=${TARGET_ARCH}

WORKDIR /opt/1Panel

COPY --from=frontend-builder /src /opt/1Panel

RUN set -ex \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git wget \
    && rm -rf /var/lib/apt/lists/*

RUN set -ex && ./ci/script.sh

RUN set -ex \
    && mkdir -p build dist \
    && cd core \
    && CGO_ENABLED=0 GOOS=linux GOARCH=${TARGET_ARCH} go build -tags=xpack -trimpath -ldflags '-s -w' -o ../build/1panel-core ./cmd/server/main.go

RUN set -ex \
    && cd agent \
    && CGO_ENABLED=0 GOOS=linux GOARCH=${TARGET_ARCH} go build -tags=xpack -trimpath -ldflags '-s -w' -o ../build/1panel-agent ./cmd/server/main.go

RUN set -ex \
    && PACKAGE_NAME="1panel-${VERSION}-linux-${TARGET_ARCH}" \
    && mkdir -p "${PACKAGE_NAME}" \
    && cp build/1panel-core build/1panel-agent "${PACKAGE_NAME}/" \
    && cp 1pctl install.sh "${PACKAGE_NAME}/" \
    && cp 1panel-core.service 1panel-agent.service "${PACKAGE_NAME}/" \
    && cp GeoIP.mmdb LICENSE README.md "${PACKAGE_NAME}/" \
    && cp -r initscript lang "${PACKAGE_NAME}/" \
    && tar -czf "${PACKAGE_NAME}.tar.gz" "${PACKAGE_NAME}" \
    && sha256sum "${PACKAGE_NAME}.tar.gz" > dist/"${PACKAGE_NAME}.tar.gz.sha256" \
    && mv "${PACKAGE_NAME}.tar.gz" dist/ \
    && rm -rf "${PACKAGE_NAME}"

FROM debian:bookworm-slim

WORKDIR /opt/1Panel

COPY --from=builder /opt/1Panel/dist /opt/1Panel/dist

VOLUME /dist

CMD cp -rf dist/* /dist/
