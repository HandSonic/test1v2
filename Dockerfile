ARG GO_VERSION=1.24
ARG NODE_VERSION=20
ARG VERSION=v2.0.13
ARG INSTALLER_REF=""
ARG TARGET_ARCHES="amd64 arm64 arm ppc64le s390x riscv64 loong64"

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
ARG INSTALLER_REF
ARG TARGET_ARCHES
ENV VERSION=${VERSION}
ENV INSTALLER_REF=${INSTALLER_REF}
ENV TARGET_ARCHES=${TARGET_ARCHES}

WORKDIR /opt/1Panel

COPY --from=frontend-builder /src /opt/1Panel

RUN set -ex \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git wget \
    && rm -rf /var/lib/apt/lists/*

RUN set -ex \
    && REF="${INSTALLER_REF:-${VERSION}}" \
    && sed -i "s@installer/raw/v2/@installer/raw/${REF}/@g" ./ci/script.sh \
    && ./ci/script.sh

RUN set -ex \
    && mkdir -p build dist \
    && for ARCH in ${TARGET_ARCHES}; do \
        echo "==> building ${ARCH}"; \
        cd /opt/1Panel/core; \
        CGO_ENABLED=0 GOOS=linux GOARCH=${ARCH} go build -trimpath -ldflags '-s -w' -o ../build/1panel-core ./cmd/server/main.go; \
        cd /opt/1Panel/agent; \
        CGO_ENABLED=0 GOOS=linux GOARCH=${ARCH} go build -trimpath -ldflags '-s -w' -o ../build/1panel-agent ./cmd/server/main.go; \
        PACKAGE_NAME="1panel-${VERSION}-linux-${ARCH}"; \
        mkdir -p "/opt/1Panel/${PACKAGE_NAME}"; \
        cp /opt/1Panel/build/1panel-core /opt/1Panel/build/1panel-agent "/opt/1Panel/${PACKAGE_NAME}/"; \
        cp /opt/1Panel/1pctl /opt/1Panel/install.sh "/opt/1Panel/${PACKAGE_NAME}/"; \
        cp /opt/1Panel/1panel-core.service /opt/1Panel/1panel-agent.service "/opt/1Panel/${PACKAGE_NAME}/"; \
        cp /opt/1Panel/GeoIP.mmdb /opt/1Panel/LICENSE /opt/1Panel/README.md "/opt/1Panel/${PACKAGE_NAME}/"; \
        cp -r /opt/1Panel/initscript /opt/1Panel/lang "/opt/1Panel/${PACKAGE_NAME}/"; \
        tar -czf "/opt/1Panel/${PACKAGE_NAME}.tar.gz" -C /opt/1Panel "${PACKAGE_NAME}"; \
        sha256sum "/opt/1Panel/${PACKAGE_NAME}.tar.gz" > "/opt/1Panel/dist/${PACKAGE_NAME}.tar.gz.sha256"; \
        mv "/opt/1Panel/${PACKAGE_NAME}.tar.gz" /opt/1Panel/dist/; \
        rm -rf "/opt/1Panel/${PACKAGE_NAME}"; \
    done \
    && rm -rf build

FROM debian:bookworm-slim

WORKDIR /opt/1Panel

COPY --from=builder /opt/1Panel/dist /opt/1Panel/dist

VOLUME /dist

CMD ["/bin/sh", "-c", "cp -rf dist/* /dist/"]
