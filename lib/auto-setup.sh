#!/usr/bin/env bash
# auto-setup.sh — GSD-Town auto-detection, dependency install, and bootstrap module
#
# Source this file to get town detection, dependency installation, and bootstrap
# functions for GSD-Town. Designed to be sourced by gsd-town.js subprocess calls.
#
# Sourcing convention:
#   source "$(gsd-town path-auto-setup)"
#   OR directly: source /path/to/lib/auto-setup.sh
#
# This file does NOT source gastown.sh — the caller is responsible for sourcing
# both files if both are needed. This avoids double-sourcing and side effects.
#
# Exported symbols:
#   detect_town()            — find or start existing town
#   check_and_install_deps() — install missing dependencies
#   bootstrap_town()         — create town, rig, crew on first use
#   GSD_TOWN_ROOT            — managed town path (default ~/.gsd-town)
#   GSD_TOWN_RIG_DIR         — rig database dir (set after bootstrap_town)

set -euo pipefail

# ---------------------------------------------------------------------------
# Module-level variables
# ---------------------------------------------------------------------------

GSD_TOWN_ROOT="${GSD_TOWN_ROOT:-${HOME}/.gsd-town}"
GSD_TOWN_RIG_DIR="${GSD_TOWN_ROOT}/gastown/mayor/rig"
# Vendored gastown source — used for building gt from source
# Prefer local vendor dir (submodule), fall back to remote clone
GT_VENDOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/vendor/gastown"
GT_FORK_REPO="https://github.com/laulpogan/gastown"

# ---------------------------------------------------------------------------
# Internal helper: resolve gt binary path
# Used within this module only — callers that have gastown.sh sourced use gt_cmd().
# ---------------------------------------------------------------------------

_gsd_gt_cmd() {
  if command -v gt >/dev/null 2>&1; then
    echo "gt"
  else
    echo "${HOME}/.local/bin/gt"
  fi
}

# ---------------------------------------------------------------------------
# detect_town()
#
# Checks for an existing gastown town in priority order:
#   1. $GSD_TOWN_ROOT (default ~/.gsd-town) — GSD-Town managed location
#   2. ~/gt — user's personal town (legacy/manual install)
#   3. $GT_TOWN_ROOT env var — explicit override
#
# If a candidate directory exists and contains a gastown subdirectory:
#   - If daemon is running: prints the town path and returns 0.
#   - If daemon is stopped: starts it (gt up), prints the town path, returns 0.
#
# If no candidate is found: returns 1 (caller should proceed to bootstrap).
#
# Outputs: absolute town path to stdout on success.
# Returns: 0 if town found (and daemon started if needed), 1 if not found.
# ---------------------------------------------------------------------------

detect_town() {
  local gt_bin
  gt_bin="$(_gsd_gt_cmd)"

  # Build list of candidates in priority order
  local candidates=()
  candidates+=("${GSD_TOWN_ROOT}")
  candidates+=("${HOME}/gt")
  if [ -n "${GT_TOWN_ROOT:-}" ]; then
    candidates+=("${GT_TOWN_ROOT}")
  fi

  local candidate
  for candidate in "${candidates[@]}"; do
    # Must be a directory AND have the gastown workspace marker
    if [ ! -d "${candidate}" ] || [ ! -d "${candidate}/gastown" ]; then
      continue
    fi

    # Check if daemon is already running
    local daemon_running=0
    (cd "${candidate}" && PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" "${gt_bin}" daemon status >/dev/null 2>&1) \
      && daemon_running=1 || daemon_running=0

    if [ "${daemon_running}" -eq 1 ]; then
      echo "${candidate}"
      return 0
    fi

    # Daemon stopped — try to start it
    echo "  [detect_town] daemon stopped at ${candidate}, starting..." >&2
    if (cd "${candidate}" && PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" "${gt_bin}" up >/dev/null 2>&1); then
      echo "${candidate}"
      return 0
    else
      echo "  [detect_town] WARNING: failed to start daemon at ${candidate}" >&2
      # Continue to next candidate rather than failing hard
      continue
    fi
  done

  # No town found in any candidate location
  return 1
}

# ---------------------------------------------------------------------------
# _ensure_dep()
#
# Internal helper for check_and_install_deps().
# Checks if a dependency is present; if not, runs the install command.
#
# Args:
#   $1 — name: display name for messages
#   $2 — check_cmd: bash expression that exits 0 if dep is present
#   $3 — install_cmd: bash expression to install the dep
#
# Returns: 0 if present (or successfully installed), 1 on failure.
# ---------------------------------------------------------------------------

_ensure_dep() {
  local name="$1"
  local check_cmd="$2"
  local install_cmd="$3"

  if ! eval "${check_cmd}" >/dev/null 2>&1; then
    echo "  [installing] ${name}..."
    if ! eval "${install_cmd}" 2>&1; then
      echo "  [ERROR] failed to install ${name}" >&2
      return 1
    fi
    echo "  [ok] ${name} installed"
  else
    echo "  [ok] ${name} present"
  fi
}

# ---------------------------------------------------------------------------
# check_and_install_deps()
#
# Checks for all GSD-Town dependencies and installs missing ones.
# Dependencies checked (in order): go, dolt, tmux, bd (beads), gt
#
# macOS: brew install for go/dolt/tmux; go install for bd; source build for gt.
# Linux: prints install instructions to stderr and returns 1 (no auto-install).
#
# Returns: 0 if all deps present after check/install, 1 if any missing.
# Outputs: status messages to stdout, errors to stderr.
# ---------------------------------------------------------------------------

check_and_install_deps() {
  echo "[check_and_install_deps] checking dependencies..."

  local is_macos=0
  if [[ "$(uname -s)" == "Darwin" ]]; then
    is_macos=1
  fi

  if [ "${is_macos}" -eq 0 ]; then
    cat >&2 <<'LINUX_INSTRUCTIONS'
[check_and_install_deps] Linux detected — auto-install not supported in v1.
Please install dependencies manually:
  go:   https://go.dev/doc/install
  dolt: curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | sudo bash
  tmux: sudo apt-get install -y tmux  (or equivalent for your distro)
  bd:   CGO_CFLAGS="-I$(icu-config --prefix)/include" CGO_CXXFLAGS="-I$(icu-config --prefix)/include -std=c++17" CGO_LDFLAGS="-L$(icu-config --prefix)/lib" go install github.com/steveyegge/beads/cmd/bd@latest
  gt:   git clone https://github.com/laulpogan/gastown && cd gastown && make install
LINUX_INSTRUCTIONS
    return 1
  fi

  # Ensure brew is available on macOS
  if ! command -v brew >/dev/null 2>&1; then
    echo "  [ERROR] Homebrew not found. Install from https://brew.sh" >&2
    return 1
  fi

  local all_ok=0

  # 1. go
  _ensure_dep "go" \
    "command -v go" \
    "brew install go" || all_ok=1

  # 2. dolt
  _ensure_dep "dolt" \
    "command -v dolt" \
    "brew install dolt" || all_ok=1

  # 3. tmux
  _ensure_dep "tmux" \
    "command -v tmux" \
    "brew install tmux" || all_ok=1

  # 4. bd (beads) — go-installed, not in brew; requires go + icu4c (for go-icu-regex CGO)
  if ! command -v go >/dev/null 2>&1; then
    echo "  [ERROR] go is required to install bd — skipping bd install" >&2
    all_ok=1
  else
    # bd depends on dolthub/go-icu-regex which needs ICU4C headers for CGO
    local icu_prefix
    icu_prefix="$(brew --prefix icu4c 2>/dev/null || echo "")"
    if [ -z "${icu_prefix}" ] || [ ! -d "${icu_prefix}/include" ]; then
      echo "  [ERROR] icu4c not found — install with: brew install icu4c" >&2
      all_ok=1
    else
      _ensure_dep "bd" \
        "command -v bd >/dev/null 2>&1 || [ -x \"${HOME}/go/bin/bd\" ]" \
        "CGO_CFLAGS=\"-I${icu_prefix}/include\" CGO_CXXFLAGS=\"-I${icu_prefix}/include -std=c++17\" CGO_LDFLAGS=\"-L${icu_prefix}/lib\" GOBIN=\"${HOME}/go/bin\" go install github.com/steveyegge/beads/cmd/bd@latest" || all_ok=1
    fi
  fi

  # 5. gt — source-built from gastown fork; must be last (requires go)
  local gt_present=0
  command -v gt >/dev/null 2>&1 && gt_present=1
  [ -x "${HOME}/.local/bin/gt" ] && gt_present=1

  if [ "${gt_present}" -eq 0 ]; then
    if ! command -v go >/dev/null 2>&1; then
      echo "  [ERROR] go is required to build gt — skipping gt install" >&2
      all_ok=1
    else
      echo "  [installing] gt from source..."
      if [ -d "${GT_VENDOR_DIR}" ] && [ -f "${GT_VENDOR_DIR}/Makefile" ]; then
        echo "  [installing] building from vendored submodule: ${GT_VENDOR_DIR}"
        if (cd "${GT_VENDOR_DIR}" && make install 2>&1); then
          echo "  [ok] gt installed (from vendor)"
        else
          echo "  [ERROR] failed to build gt from vendor" >&2
          all_ok=1
        fi
      else
        echo "  [installing] vendored source not found, cloning ${GT_FORK_REPO}..."
        local tmp_dir
        tmp_dir=$(mktemp -d)
        if git clone --depth=1 "${GT_FORK_REPO}" "${tmp_dir}/gastown" 2>&1 \
            && (cd "${tmp_dir}/gastown" && make install 2>&1); then
          echo "  [ok] gt installed (from clone)"
        else
          echo "  [ERROR] failed to build gt from source" >&2
          all_ok=1
        fi
        rm -rf "${tmp_dir}"
      fi
    fi
  else
    echo "  [ok] gt present"
  fi

  # Final verification pass — confirm each dep is actually reachable
  echo "[check_and_install_deps] verifying all deps..."
  local verify_ok=0

  command -v go >/dev/null 2>&1        && echo "  [verified] go"    || { echo "  [MISSING] go" >&2;   verify_ok=1; }
  command -v dolt >/dev/null 2>&1      && echo "  [verified] dolt"  || { echo "  [MISSING] dolt" >&2; verify_ok=1; }
  command -v tmux >/dev/null 2>&1      && echo "  [verified] tmux"  || { echo "  [MISSING] tmux" >&2; verify_ok=1; }
  { command -v bd >/dev/null 2>&1 || [ -x "${HOME}/go/bin/bd" ]; } \
    && echo "  [verified] bd"    || { echo "  [MISSING] bd" >&2;   verify_ok=1; }
  { command -v gt >/dev/null 2>&1 || [ -x "${HOME}/.local/bin/gt" ]; } \
    && echo "  [verified] gt"    || { echo "  [MISSING] gt" >&2;   verify_ok=1; }

  # Return 1 if either install or verification failed
  [ "${all_ok}" -eq 0 ] && [ "${verify_ok}" -eq 0 ] && return 0 || return 1
}

# ---------------------------------------------------------------------------
# bootstrap_town()
#
# Creates the GSD-Town managed town workspace on first use.
# Idempotent — safe to call multiple times; won't duplicate rigs or crew.
#
# Args:
#   $1 — project_dir: absolute path to current GSD project root
#   $2 — rig_name: slugified project name (e.g., "my-project")
#                  [T-03-01] Input is sanitized to [a-z0-9-] before use.
#
# Steps:
#   1. Create managed town at GSD_TOWN_ROOT if not present (gt install + gt up)
#   2. Start daemon
#   3. Register project as rig (idempotent — checks existing rigs first)
#   4. Add crew member from git config (idempotent — checks existing crew first)
#   5. Update GSD_TOWN_RIG_DIR module variable
#   6. Write ~/.gsd-town-config registry file if missing
#
# Returns: 0 on success, 1 on failure.
# Outputs: progress messages on stdout, errors on stderr.
# ---------------------------------------------------------------------------

bootstrap_town() {
  local project_dir="${1:?project_dir required}"
  local raw_rig_name="${2:?rig_name required}"

  # [T-03-01] Slugify rig_name — strip to [a-z0-9-] only
  local rig_name
  rig_name=$(echo "${raw_rig_name}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-' '-' | sed 's/^-//;s/-$//')

  echo "[bootstrap_town] project=${project_dir} rig=${rig_name}"

  local gt_bin
  gt_bin="$(_gsd_gt_cmd)"

  # Inline helper that routes to gt regardless of PATH state
  _local_gt() {
    PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" "${gt_bin}" "$@"
  }

  # Step 1 — Create managed town if not present
  if [ ! -d "${GSD_TOWN_ROOT}/gastown" ]; then
    echo "  [bootstrap] creating managed town at ${GSD_TOWN_ROOT}..."
    _local_gt install "${GSD_TOWN_ROOT}" --git 2>&1 || {
      echo "  [ERROR] gt install failed" >&2
      return 1
    }
  else
    echo "  [bootstrap] town already exists at ${GSD_TOWN_ROOT}"
  fi

  # Step 2 — Start daemon (gt up)
  echo "  [bootstrap] starting daemon..."
  (cd "${GSD_TOWN_ROOT}" && PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" "${gt_bin}" up 2>&1) || {
    echo "  [ERROR] gt up failed" >&2
    return 1
  }

  # Step 3 — Register project as rig (idempotent)
  local existing_rigs
  existing_rigs=$(cd "${GSD_TOWN_ROOT}" && \
    PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" "${gt_bin}" rig list --json 2>/dev/null || echo "[]")

  if ! echo "${existing_rigs}" | python3 -c \
      "import sys,json; rigs=json.load(sys.stdin); exit(0 if any(r.get('name')=='${rig_name}' for r in rigs) else 1)" \
      2>/dev/null; then
    echo "  [bootstrap] adding rig: ${rig_name} -> ${project_dir}"
    # gt rig add expects <name> <git-url> and clones into the town.
    # For external projects (already on disk), we:
    #   1. Create a symlink inside the town pointing to the project
    #   2. Use --adopt to register the symlinked directory as a rig
    local rig_link="${GSD_TOWN_ROOT}/${rig_name}"
    if [ ! -e "${rig_link}" ]; then
      ln -s "${project_dir}" "${rig_link}"
      echo "  [bootstrap] symlinked ${rig_link} -> ${project_dir}"
    fi
    (cd "${GSD_TOWN_ROOT}" && PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" "${gt_bin}" rig add "${rig_name}" --adopt --force 2>&1) || {
      # If --adopt fails, try with the git remote URL instead
      local git_url
      git_url=$(cd "${project_dir}" && git remote get-url origin 2>/dev/null || echo "")
      if [ -n "${git_url}" ]; then
        echo "  [bootstrap] --adopt failed, trying git URL: ${git_url}"
        rm -f "${rig_link}" 2>/dev/null  # remove symlink, let gt clone
        (cd "${GSD_TOWN_ROOT}" && PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" "${gt_bin}" rig add "${rig_name}" "${git_url}" 2>&1) || {
          echo "  [ERROR] gt rig add failed with both --adopt and git URL" >&2
          return 1
        }
      else
        echo "  [ERROR] gt rig add --adopt failed and no git remote found" >&2
        return 1
      fi
    }
  else
    echo "  [bootstrap] rig ${rig_name} already registered"
  fi

  # Step 4 — Add crew member (idempotent)
  local username
  username=$(git config user.name 2>/dev/null | tr ' ' '-' | tr '[:upper:]' '[:lower:]' || echo "${USER:-polecat}")
  # Sanitize username similarly
  username=$(echo "${username}" | tr -cs 'a-z0-9-' '-' | sed 's/^-//;s/-$//')

  local existing_crew
  existing_crew=$(cd "${GSD_TOWN_ROOT}" && \
    PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" "${gt_bin}" crew list --json 2>/dev/null || echo "[]")

  if ! echo "${existing_crew}" | python3 -c \
      "import sys,json; crew=json.load(sys.stdin); exit(0 if any(c.get('name')=='${username}' for c in crew) else 1)" \
      2>/dev/null; then
    echo "  [bootstrap] adding crew member: ${username}"
    (cd "${GSD_TOWN_ROOT}" && PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" "${gt_bin}" crew add "${username}" 2>&1) || {
      echo "  [ERROR] gt crew add failed" >&2
      return 1
    }
  else
    echo "  [bootstrap] crew member ${username} already present"
  fi

  # Step 5 — Update module-level GSD_TOWN_RIG_DIR
  GSD_TOWN_RIG_DIR="${GSD_TOWN_ROOT}/${rig_name}/mayor/rig"
  echo "  [bootstrap] rig dir: ${GSD_TOWN_RIG_DIR}"

  # Step 6 — Write ~/.gsd-town-config registry if not present
  local config_file="${HOME}/.gsd-town-config"
  if [ ! -f "${config_file}" ]; then
    printf 'GSD_TOWN_ROOT="%s"\nGSD_TOWN_RIG="%s"\n' "${GSD_TOWN_ROOT}" "${rig_name}" > "${config_file}"
    echo "  [bootstrap] wrote config: ${config_file}"
  else
    echo "  [bootstrap] config already exists: ${config_file}"
  fi

  echo "[bootstrap_town] complete"
  return 0
}

# ---------------------------------------------------------------------------
# Exported symbols:
#   detect_town()            — find or start existing town
#   check_and_install_deps() — install missing dependencies
#   bootstrap_town()         — create town, rig, crew on first use
#   GSD_TOWN_ROOT            — managed town path (default ~/.gsd-town)
#   GSD_TOWN_RIG_DIR         — rig database dir (set by bootstrap_town)
# ---------------------------------------------------------------------------
