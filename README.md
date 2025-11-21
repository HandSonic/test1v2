## 1Panel v2 builder

Dockerfile for building 1Panel v2 from source (frontend + core + agent) and packaging the same layout as official releases.

### Build and export（本地 Docker）
```bash
# 在 diyv2 仓库根目录执行
docker build -f Dockerfile \
  --build-arg VERSION=v2.0.13 \
  --build-arg TARGET_ARCH=loong64 \
  -t 1panel-v2-builder .

docker run --rm -v "$(pwd)/dist:/dist" 1panel-v2-builder
```

### Args
- `VERSION`: git tag/branch to build (default `v2.0.13`).
- `TARGET_ARCH`: GOARCH value, e.g. `loong64`, `amd64`, `arm64`.
- `GO_VERSION`: Go toolchain (needs to be >=1.24 for current modules).
- `NODE_VERSION`: Node.js for the frontend build (defaults to 20).
- Go 构建使用默认标签（不开 `xpack`），避免开源仓库缺少 `xpack` 源码导致的 build constraints 错误。
- 前端构建阶段已设置 `NODE_OPTIONS=--max-old-space-size=8192` 以避免 Vite 构建时内存不足。

### Output
- `dist/1panel-${VERSION}-linux-${TARGET_ARCH}.tar.gz` and matching `.sha256`.
- Contents inside the tarball: `1panel-core`, `1panel-agent`, `1pctl`, `install.sh`, `1panel-core.service`, `1panel-agent.service`, `initscript/`, `lang/`, `GeoIP.mmdb`, `LICENSE`, `README.md`.
- Frontend assets are built inside the container, so no host-side Node.js or Go setup is required.

### GitHub Actions
- 仓库内置 `.github/workflows/build.yml`，支持两种用法：
  - 推送 tag（`v*`）时自动触发，默认使用 tag 名作为版本。
  - 定时任务（每天 02:00 UTC）会自动运行，版本号默认取 1Panel 官方仓库最新 release（拉取失败时回落到 `v2.0.13`），架构默认 `loong64`。
  - 手动触发 `workflow_dispatch` 可覆盖 `version/arch/go_version/node_version`，不填 `version` 时同样使用当前 ref 或最新 release。
- 工作流步骤：`docker build` -> `docker run` 导出到 `dist/` -> `actions/upload-artifact` 上传产物（名称：`1panel-<version>-<arch>`）。
