#!/usr/bin/env bash
set -euo pipefail

DEFAULT_IMAGE_NAME="localhost/opencode:latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
STATE_DIR="${HOME}/.opencode-container"
CONTAINERFILE="${STATE_DIR}/container/Containerfile"
if [[ ! -f "${CONTAINERFILE}" ]]; then
  CONTAINERFILE="${SCRIPT_DIR}/container/Containerfile"
fi
BUILD_CONTEXT="$(dirname "${CONTAINERFILE}")"

OPENCODE_DATA_DIR="${STATE_DIR}/opencode"
CONFIG_DIR="${STATE_DIR}/config"
LOCAL_DIR="${STATE_DIR}/local"

C_RESET=""
C_BOLD=""
C_DIM=""
C_RED=""
C_GREEN=""
C_YELLOW=""
C_BLUE=""
C_MAGENTA=""
C_CYAN=""

init_colors() {
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_DIM='\033[2m'
    C_RED='\033[31m'
    C_GREEN='\033[32m'
    C_YELLOW='\033[33m'
    C_BLUE='\033[34m'
    C_MAGENTA='\033[35m'
    C_CYAN='\033[36m'
  fi
}

log_info() {
  printf "%b[info]%b %s\n" "$C_CYAN" "$C_RESET" "$*"
}

log_warn() {
  printf "%b[warn]%b %s\n" "$C_YELLOW" "$C_RESET" "$*"
}

log_ok() {
  printf "%b[ ok ]%b %s\n" "$C_GREEN" "$C_RESET" "$*"
}

log_step() {
  printf "%b==>%b %s\n" "$C_MAGENTA" "$C_RESET" "$*"
}

usage() {
  printf "%bOpenCode Container Wrapper%b\n" "$C_BOLD$C_BLUE" "$C_RESET"
  printf "%bUsage%b\n" "$C_BOLD$C_MAGENTA" "$C_RESET"
  cat <<USAGE
  opencode.sh [run] [options] [workspace]
  opencode.sh shell [options] [workspace]
  opencode.sh exec <container-id-or-name>
  opencode.sh stop <container-id-or-name>
  opencode.sh killall
  opencode.sh status
  opencode.sh rebuild
  opencode.sh prune
  opencode.sh help
USAGE

  printf "%bRun/Shell Options%b\n" "$C_BOLD$C_MAGENTA" "$C_RESET"
  cat <<OPTIONS
  -w, --workspace <path>      Workspace to mount at /workspace (default: .)
  -i, --image <image>         Use a different image (always pull, no local build)
  -v, --volume <spec>         Extra volume mount (repeatable)
  -p, --publish <spec>        Port publish mapping (repeatable)
  -e, --env <key=value>       Environment variable (repeatable)
  -m, --memory <value>        Memory limit (example: 4g)
      --cpu <value>           CPU limit passed as --cpus (example: 2)
      --name <name>           Container name (default: opencode-<folder>-<timestamp>)
      --no-rm                 Keep container after exit
OPTIONS

  printf "%bExamples%b\n" "$C_BOLD$C_MAGENTA" "$C_RESET"
  cat <<EXAMPLES
  opencode.sh .
  opencode.sh -w ~/workspaces/app -p 3000:3000 -v ~/src:/extra-src:Z
  opencode.sh -i ghcr.io/some/image:latest .
  opencode.sh shell -w .
  opencode.sh exec opencode-myproj-20260318-120000
EXAMPLES
}

die() {
  printf "%bError:%b %s\n" "$C_RED" "$C_RESET" "$*" >&2
  exit 1
}

resolve_path() {
  local p="$1"
  if [[ -d "$p" ]]; then
    (cd "$p" && pwd -P)
  else
    die "Path does not exist or is not a directory: $p"
  fi
}

sanitize_name_part() {
  local raw="$1"
  local normalized

  normalized="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  if [[ -z "$normalized" ]]; then
    normalized="ws"
  fi
  printf '%s' "$normalized"
}

default_container_name() {
  local workspace="$1"
  local folder slug timestamp

  folder="$(basename "$workspace")"
  slug="$(sanitize_name_part "$folder")"
  slug="${slug:0:18}"
  timestamp="$(date +%Y%m%d-%H%M%S)"
  printf 'opencode-%s-%s' "$slug" "$timestamp"
}

ensure_state_dirs() {
  mkdir -p "$OPENCODE_DATA_DIR" "$CONFIG_DIR" "$LOCAL_DIR"
}

containerfile_sha() {
  sha256sum "$CONTAINERFILE" | awk '{print $1}'
}

image_exists() {
  podman image exists "$DEFAULT_IMAGE_NAME"
}

image_containerfile_sha() {
  podman image inspect --format '{{ index .Labels "opencode.containerfile.sha" }}' "$DEFAULT_IMAGE_NAME" 2>/dev/null || true
}

build_image() {
  local sha
  sha="$(containerfile_sha)"
  log_step "Image build started"
  log_info "Image: ${DEFAULT_IMAGE_NAME}"
  log_info "Containerfile: ${CONTAINERFILE}"
  podman build \
    -t "$DEFAULT_IMAGE_NAME" \
    -f "$CONTAINERFILE" \
    --label "opencode.managed=true" \
    --label "opencode.containerfile.sha=${sha}" \
    "$BUILD_CONTEXT"
  log_ok "Build complete: ${DEFAULT_IMAGE_NAME}"
}

ensure_default_image() {
  local current_sha image_sha
  current_sha="$(containerfile_sha)"

  if ! image_exists; then
    log_warn "Image ${DEFAULT_IMAGE_NAME} not found. Building..."
    build_image
    return
  fi

  image_sha="$(image_containerfile_sha)"
  if [[ -z "$image_sha" || "$image_sha" != "$current_sha" ]]; then
    log_warn "Containerfile changed (or image unlabeled). Rebuilding ${DEFAULT_IMAGE_NAME}..."
    build_image
  fi
}

pull_image() {
  local image_name="$1"
  log_step "Pulling image ${image_name}"
  podman pull "$image_name"
}

list_opencode_ids() {
  podman ps -a --format '{{.ID}}|{{.Names}}|{{.Image}}' | awk -F'|' '($2 ~ /^opencode-/ || $3 ~ /opencode/) {print $1}'
}

status_color() {
  local state="$1"
  case "$state" in
    running)
      printf "%b" "$C_GREEN"
      ;;
    exited|created|configured)
      printf "%b" "$C_YELLOW"
      ;;
    *)
      printf "%b" "$C_RED"
      ;;
  esac
}

status_cmd() {
  local ids
  local running=0
  local stopped=0
  mapfile -t ids < <(list_opencode_ids)

  if [[ ${#ids[@]} -eq 0 ]]; then
    log_info "No opencode containers found."
    return 0
  fi

  printf "%b%-14s  %-44s  %-10s  %s%b\n" "$C_BOLD$C_BLUE" "CONTAINER" "NAME" "STATE" "WORKSPACE" "$C_RESET"
  for id in "${ids[@]}"; do
    local name state workspace workspace_display state_c
    name="$(podman inspect --format '{{.Name}}' "$id" | sed 's#^/##')"
    state="$(podman inspect --format '{{.State.Status}}' "$id")"
    workspace="$(podman inspect --format '{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}' "$id")"
    workspace_display="${workspace:-<none>}"
    if [[ "$workspace_display" == "$HOME" ]]; then
      workspace_display="~"
    elif [[ "$workspace_display" == "$HOME"/* ]]; then
      workspace_display="~${workspace_display#$HOME}"
    fi
    state_c="$(status_color "$state")"

    if [[ "$state" == "running" ]]; then
      running=$((running + 1))
    else
      stopped=$((stopped + 1))
    fi

    printf "%b%-14s%b  %b%-44s%b  %b%-10s%b  %s\n" \
      "$C_CYAN" "${id:0:12}" "$C_RESET" \
      "$C_BOLD" "$name" "$C_RESET" \
      "$state_c" "$state" "$C_RESET" \
      "$workspace_display"
  done

  printf "%bSummary:%b %b%d running%b, %b%d not running%b\n" \
    "$C_BOLD$C_MAGENTA" "$C_RESET" \
    "$C_GREEN" "$running" "$C_RESET" \
    "$C_YELLOW" "$stopped" "$C_RESET"
}

stop_cmd() {
  local target="${1:-}"
  [[ -n "$target" ]] || die "stop requires a container id or name"
  log_step "Stopping container ${target}"
  podman stop "$target"
}

killall_cmd() {
  local ids
  mapfile -t ids < <(list_opencode_ids)
  if [[ ${#ids[@]} -eq 0 ]]; then
    log_info "No opencode containers to stop."
    return 0
  fi
  log_step "Stopping ${#ids[@]} opencode container(s)"
  podman stop "${ids[@]}"
}

exec_cmd() {
  local target="${1:-}"
  [[ -n "$target" ]] || die "exec requires a running container id or name"
  log_step "Opening interactive shell in ${target}"
  podman exec -it "$target" /bin/bash
}

rebuild_cmd() {
  build_image
}

prune_cmd() {
  log_step "Pruning dangling images"
  podman image prune -f
}

run_or_shell_cmd() {
  local mode="$1"
  shift

  local workspace="."
  local workspace_set="false"
  local no_rm="false"
  local memory_limit=""
  local cpu_limit=""
  local image_name="$DEFAULT_IMAGE_NAME"
  local image_set="false"
  local container_name=""
  local container_name_set="false"

  local -a extra_volumes=()
  local -a publish_ports=()
  local -a env_vars=()
  local -a opencode_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -w|--workspace)
        [[ $# -ge 2 ]] || die "$1 requires a value"
        workspace="$2"
        workspace_set="true"
        shift 2
        ;;
      -i|--image)
        [[ $# -ge 2 ]] || die "$1 requires a value"
        image_name="$2"
        image_set="true"
        shift 2
        ;;
      -v|--volume)
        [[ $# -ge 2 ]] || die "$1 requires a value"
        extra_volumes+=("$2")
        shift 2
        ;;
      -p|--publish)
        [[ $# -ge 2 ]] || die "$1 requires a value"
        publish_ports+=("$2")
        shift 2
        ;;
      -e|--env)
        [[ $# -ge 2 ]] || die "$1 requires a value"
        env_vars+=("$2")
        shift 2
        ;;
      -m|--memory)
        [[ $# -ge 2 ]] || die "$1 requires a value"
        memory_limit="$2"
        shift 2
        ;;
      --cpu)
        [[ $# -ge 2 ]] || die "$1 requires a value"
        cpu_limit="$2"
        shift 2
        ;;
      --name)
        [[ $# -ge 2 ]] || die "$1 requires a value"
        container_name="$2"
        container_name_set="true"
        shift 2
        ;;
      --no-rm)
        no_rm="true"
        shift
        ;;
      --)
        shift
        opencode_args+=("$@")
        break
        ;;
      -*)
        die "Unknown option: $1"
        ;;
      *)
        if [[ "$workspace_set" == "false" ]]; then
          workspace="$1"
          workspace_set="true"
        else
          opencode_args+=("$1")
        fi
        shift
        ;;
    esac
  done

  workspace="$(resolve_path "$workspace")"
  if [[ "$container_name_set" == "false" ]]; then
    container_name="$(default_container_name "$workspace")"
  fi

  ensure_state_dirs
  
  # Validate host git configuration
  if [[ ! -f "$HOME/.config/git/config" ]]; then
    log_warn "No git config found at ~/.config/git/config"
    log_info "Container will use fallback git identity or GIT_AUTHOR_* environment variables"
  fi
  
  if [[ "$image_set" == "true" ]]; then
    pull_image "$image_name"
  else
    ensure_default_image
  fi

  local -a cmd=(podman run -it)

  if [[ "$no_rm" == "false" ]]; then
    cmd+=(--rm)
  fi

  cmd+=(
    --name "$container_name"
    --label "opencode.managed=true"
    --label "opencode.workspace=$workspace"
    -v "$workspace:/workspace:Z"
    -v "$OPENCODE_DATA_DIR:/root/.opencode:Z"
    -v "$CONFIG_DIR:/root/.config:Z"
    -v "$LOCAL_DIR:/root/.local:Z"
    -v "$HOME/.config/git/config:/root/.config.host/git/config:ro,Z"
    -w /workspace
  )

  if [[ -n "$memory_limit" ]]; then
    cmd+=(--memory "$memory_limit")
  fi
  if [[ -n "$cpu_limit" ]]; then
    cmd+=(--cpus "$cpu_limit")
  fi

  local v
  for v in "${extra_volumes[@]}"; do
    cmd+=(-v "$v")
  done

  local p
  for p in "${publish_ports[@]}"; do
    cmd+=(-p "$p")
  done

  local e
  for e in "${env_vars[@]}"; do
    cmd+=(-e "$e")
  done

  if [[ "$mode" == "shell" ]]; then
    cmd+=(--entrypoint /bin/bash)
    cmd+=("$image_name")
  else
    cmd+=("$image_name")
    if [[ ${#opencode_args[@]} -gt 0 ]]; then
      cmd+=("${opencode_args[@]}")
    fi
  fi

  log_step "Preparing interactive session"
  log_info "Container: ${container_name}"
  log_info "Workspace: ${workspace}"
  log_info "Image: ${image_name}"
  "${cmd[@]}"
}

main() {
  init_colors

  local command="run"
  if [[ $# -gt 0 ]]; then
    case "$1" in
      run|shell|exec|stop|killall|status|rebuild|prune|help)
        command="$1"
        shift
        ;;
    esac
  fi

  case "$command" in
    run)
      run_or_shell_cmd "run" "$@"
      ;;
    shell)
      run_or_shell_cmd "shell" "$@"
      ;;
    exec)
      exec_cmd "$@"
      ;;
    stop)
      stop_cmd "$@"
      ;;
    killall)
      killall_cmd
      ;;
    status)
      status_cmd
      ;;
    rebuild)
      rebuild_cmd
      ;;
    prune)
      prune_cmd
      ;;
    help)
      usage
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
