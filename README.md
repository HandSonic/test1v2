## 1Panel v2 builder

Dockerfile for building 1Panel v2 from source (frontend + core + agent) and packaging the same layout as official releases.

### Build and export（本地 Docker）
```bash
# from repo root
docker build -f diyv2/Dockerfile \
  --build-arg VERSION=v2.0.13 \
  --build-arg TARGET_ARCH=loong64 \
  -t 1panel-v2-builder diyv2

docker run --rm -v "$(pwd)/dist:/dist" 1panel-v2-builder
```

### Args
- `VERSION`: git tag/branch to build (default `v2.0.13`).
- `TARGET_ARCH`: GOARCH value, e.g. `loong64`, `amd64`, `arm64`.
- `GO_VERSION`: Go toolchain (needs to be >=1.24 for current modules).
- `NODE_VERSION`: Node.js for the frontend build (defaults to 20).

### Output
- `dist/1panel-${VERSION}-linux-${TARGET_ARCH}.tar.gz` and matching `.sha256`.
- Contents inside the tarball: `1panel-core`, `1panel-agent`, `1pctl`, `install.sh`, `1panel-core.service`, `1panel-agent.service`, `initscript/`, `lang/`, `GeoIP.mmdb`, `LICENSE`, `README.md`.
- Frontend assets are built inside the container, so no host-side Node.js or Go setup is required.

### GitHub Actions
仓库内置 `.github/workflows/build.yml`，在 GitHub 页面手动触发 `build-offline` 工作流即可自动构建并上传离线包。
- 可在触发时指定 `version`（tag/branch，如 v2.0.13）、`arch`（GOARCH，如 loong64/amd64/arm64）、`go_version`、`node_version`。
- 工作流步骤：`docker build` -> `docker run` 导出到 `dist/` -> `actions/upload-artifact` 上传产物。
