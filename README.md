## 1Panel v2 builder

Dockerfile for building 1Panel v2 from source (frontend + core + agent) and packaging the same layout as official releases.

### Build and export（本地 Docker）
```bash
# 在 diyv2 仓库根目录执行
docker build -f Dockerfile \
  --build-arg VERSION=v2.0.13 \
  --build-arg TARGET_ARCHES="amd64 arm64 armv7 ppc64le s390x loong64 riscv64" \
  -t 1panel-v2-builder .

docker run --rm -v "$(pwd)/dist:/dist" 1panel-v2-builder
```

### Args
- `VERSION`: git tag/branch to build (default `v2.0.13`).
- `TARGET_ARCHES`: 空格或逗号分隔的 GOARCH 列表（默认 `amd64 arm64 armv7 ppc64le s390x loong64 riscv64`），会依次构建并产出多个离线包。`armv7` 会自动使用 GOARCH=arm GOARM=7 并输出 `linux-armv7` 名称，与官方一致。
- `GO_VERSION`: Go toolchain (default 1.24；已在 Dockerfile 和 Action 固定，可不填).
- `NODE_VERSION`: Node.js for the frontend build (default 20；已在 Dockerfile 和 Action 固定，可不填).
- `INSTALLER_REF`: 覆盖 installer 仓库分支/tag（默认 `v2`，与官方一致；如 installer 有对应 tag 可手动指定）。
- 打包时会将 `1pctl` 中的 `ORIGINAL_VERSION` 写成构建版本，确保安装后系统显示的版本号正确。
- Go 构建使用默认标签（不开 `xpack`），避免开源仓库缺少 `xpack` 源码导致的 build constraints 错误。
- 前端构建阶段已设置 `NODE_OPTIONS=--max-old-space-size=8192` 以避免 Vite 构建时内存不足。

### Output
- `dist/1panel-${VERSION}-linux-${TARGET_ARCH}.tar.gz` and matching `.sha256`.
- Contents inside the tarball: `1panel-core`, `1panel-agent`, `1pctl`, `install.sh`, `1panel-core.service`, `1panel-agent.service`, `initscript/`, `lang/`, `GeoIP.mmdb`, `LICENSE`, `README.md`.
- Frontend assets are built inside the container, so no host-side Node.js or Go setup is required.

### GitHub Actions
- 仓库内置 `.github/workflows/build.yml`，支持两种用法：
  - 推送 tag（`v*`）时自动触发，默认使用 tag 名作为版本。
  - 定时任务（每天 02:00 UTC）会先获取 1Panel 最新 release 版本：若本仓库当前已发布同版本的 Release 则跳过构建，未发布才构建；版本获取失败回落到 `v2.0.13`。架构默认 `amd64 arm64 arm ppc64le s390x riscv64 loong64`。
  - 手动触发 `workflow_dispatch` 可覆盖 `version/arch`（`arch` 支持空格/逗号分隔多架构，默认 `amd64 arm64 arm ppc64le s390x riscv64 loong64`），不填 `version` 时同样使用当前 ref 或最新 release；手动指定版本会强制构建。
- 工作流步骤：`docker build` -> `docker run` 导出到 `dist/` -> 上传 artifact；随后自动创建/推送 tag（若触发时不是 tag），并创建/更新 GitHub Release 附带 dist 内所有包。产物名称：`1panel-<version>-<arch-list>`，`dist` 下包含每个架构的 tar.gz+sha256。

### goreleaser（可选）
- 仓库附带 `.goreleaser.yaml`，按官方 v2 结构（core/agent 双二进制、多架构）但不开启 `xpack` 标签，避免开源代码缺少对应实现。
- 在有源码的情况下直接执行 `goreleaser release --clean`（或 `goreleaser build`）；需要 Go 1.24、Node 20，且需先跑 `./scripts/download_resources.sh` 拉取安装文件（已在 hooks 里自动处理）。

### 跨版本兼容性
- 使用自定义 `scripts/download_resources.sh` 替代官方 `ci/script.sh`，确保构建任意版本（包括旧版本）时不会因官方 installer 仓库文件位置变化而报错。
- 该脚本始终从 installer 仓库的 `initscript/` 目录下载 service 文件，兼容官方最新结构。
