#!/bin/bash
# Build and push the v3 workload kit to an OCI registry, tagged with the descriptor's version and :latest.
# A v3 kit is built by BuildKit, so this uses `docker buildx build --push` (NOT `sbx kit push`, which is for the
# older spec.yaml format). arm64 only, as the app image is not built for other platforms.
#
# Requires Docker (buildx) with a running engine and a logged-in registry session (`docker login`).
#
#   DOCKERHUB_NAMESPACE=mynamespace ./scripts/publish.sh
#   ./scripts/publish.sh ghcr.io/myorg/copilot-desktop-kit
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KIT_DIR="$ROOT/copilot-desktop"
DESCRIPTOR="$KIT_DIR/copilot-desktop.yaml"

REPO="${1:-}"
if [ -z "$REPO" ]; then
  : "${DOCKERHUB_NAMESPACE:?set DOCKERHUB_NAMESPACE, or pass a full repo reference as the first argument}"
  REPO="docker.io/${DOCKERHUB_NAMESPACE}/copilot-desktop-kit"
fi

VERSION="$(sed -nE 's/^version:[[:space:]]*"?([^"[:space:]]+)"?.*/\1/p' "$DESCRIPTOR" | head -1)"
[ -n "$VERSION" ] || { echo "error: could not read version from $DESCRIPTOR" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || { echo "error: docker not found" >&2; exit 1; }

echo "== building and pushing $REPO:$VERSION and :latest (linux/arm64)"
docker buildx build -f "$DESCRIPTOR" \
  --platform linux/arm64 \
  --push \
  -t "$REPO:$VERSION" \
  -t "$REPO:latest" \
  "$KIT_DIR"

echo "== done. Use it with:"
echo "   COPILOT_KIT=$REPO:$VERSION ./run-copilot"
