#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/build/release_common.sh
source "$SCRIPT_DIR/release_common.sh"

usage() {
    cat <<'EOF'
Usage: scripts/build/push_docker_multiarch.sh --version X.Y.Z [options]

Options:
  --version VERSION         Release version (required)
  --git-hash HASH           Short git hash to tag alongside the version
  --image IMAGE             Docker image name (default: docker.io/jkingsman/remoteterm-meshcore)
  --platforms CSV           Buildx platforms CSV (default: linux/amd64,linux/arm64)
  --tag TAG                 Publish TAG instead of the default tag set.
                            Repeatable. Given one or more times, the defaults
                            (latest, VERSION, GIT_HASH) are not applied, so a
                            caller can publish an unreleased build without
                            moving :latest or overwriting :VERSION.
  --help                    Show this message

By default the image is pushed as :latest, :VERSION and :GIT_HASH.
EOF
}

VERSION=""
GIT_HASH=""
IMAGE="docker.io/jkingsman/remoteterm-meshcore"
PLATFORMS="linux/amd64,linux/arm64"
TAGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --version)
            VERSION="${2:-}"
            shift 2
            ;;
        --git-hash)
            GIT_HASH="${2:-}"
            shift 2
            ;;
        --image)
            IMAGE="${2:-}"
            shift 2
            ;;
        --platforms)
            PLATFORMS="${2:-}"
            shift 2
            ;;
        --tag)
            [ -n "${2:-}" ] || release_die "--tag requires a value"
            TAGS+=("$2")
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            release_die "Unknown argument: $1"
            ;;
    esac
done

[ -n "$VERSION" ] || release_die "--version is required"
release_validate_version "$VERSION"

REPO_ROOT="$(release_repo_root)"
GIT_HASH="${GIT_HASH:-$(release_resolve_short_hash "$REPO_ROOT")}"

echo "[push_docker_multiarch] Ensuring docker buildx builder..." >&2
release_ensure_buildx_builder

if [ "${#TAGS[@]}" -eq 0 ]; then
    TAGS=("latest" "$VERSION" "$GIT_HASH")
fi

docker_buildx_args=(
    build
    --platform "$PLATFORMS"
    --build-arg "COMMIT_HASH=$GIT_HASH"
)
for tag in "${TAGS[@]}"; do
    docker_buildx_args+=(-t "$IMAGE:$tag")
done
docker_buildx_args+=(--push .)

echo "[push_docker_multiarch] Building and pushing $IMAGE for $PLATFORMS..." >&2
echo "[push_docker_multiarch] Tags: ${TAGS[*]}" >&2
(
    cd "$REPO_ROOT"
    docker buildx "${docker_buildx_args[@]}"
)
