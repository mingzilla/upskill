#!/bin/bash
# upskill__add.sh - copy a member's shared skill into a project.
# usage: upskill__add.sh <member> <skill|number> [--project <sandbox|current|<path>>] [--agent <claude|codex>]
# exit: 0 added | 1 error | 2 no target given (the target menu was printed)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/upskill__lib.sh"

WHO=""
WANT=""
PROJECT=""
AGENT="${UP_SKILL_AGENT:-claude}"
KEY=""
SRC_DIR=""
SKILL=""
DEST=""
WHERE=""

add::parse_args() {
  WHO="${1:-}"; shift || true
  WANT="${1:-}"; shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) PROJECT="${2:-}"; shift 2 ;;
      --agent)   AGENT="${2:-}"; shift 2 ;;
      *) echo "error: unknown option: $1" >&2; exit 1 ;;
    esac
  done
  if [[ -z "$WHO" || -z "$WANT" ]]; then
    echo "usage: upskill__add.sh <member> <skill|number> [--project <sandbox|current|<path>>]" >&2
    exit 1
  fi
  case "$AGENT" in claude|codex) ;; *) echo "error: --agent must be claude or codex" >&2; exit 1 ;; esac
}

add::resolve_skill() {
  KEY="$(us::key_of "$WHO")" || exit 1
  us::sync_repo "$KEY" || exit 1
  SRC_DIR="$(us::pool_dir "$KEY")"
  # a bare number means "the nth of the list just shown", so it is resolved against the same order
  if [[ "$WANT" =~ ^[0-9]+$ ]]; then
    SKILL="$(us::skill_names "$SRC_DIR" | sed -n "${WANT}p")"
    [[ -n "$SKILL" ]] || { echo "error: there is no skill $WANT in $(us::name_of "$KEY")'s list" >&2; exit 1; }
  else
    SKILL="$WANT"
  fi
  us::safe_name "$SKILL" || exit 1
  [[ -d "$SRC_DIR/$SKILL" ]] || {
    echo "error: $(us::name_of "$KEY") has no skill called '$SKILL'" >&2
    exit 1
  }
}

# no target given: print the menu and stop with 2, so the caller asks rather than guessing a path
add::require_target() {
  [[ -n "$PROJECT" ]] && return 0
  cat <<'TXT'
Where would you like to add this?
1. upskill__sandbox (Recommended)
2. your current project
3. specify a project path
TXT
  exit 2
}

add::resolve_dest() {
  local base
  case "$PROJECT" in
    1|sandbox) base="$US_SANDBOX";        WHERE="\`upskill__sandbox\`" ;;
    2|current) base="$PWD";               WHERE="this project" ;;
    3)         echo "error: say which path - re-run with --project <path>" >&2; exit 1 ;;
    *)         base="${PROJECT/#\~/$HOME}"; WHERE="\`$base\`" ;;
  esac
  [[ -d "$base" ]] || { echo "error: no such project folder: $base" >&2; exit 1; }
  DEST="$base/.$AGENT/skills/$SKILL"
}

add::copy() {
  local prep="added to"
  [[ -d "$DEST" ]] && prep="updated in"
  # the agent may be sandboxed out of the project folder; say so rather than failing obscurely
  if ! mkdir -p "$(dirname "$DEST")" 2>/dev/null; then
    echo "error: cannot write to $(dirname "$DEST")" >&2
    echo "  Adding a skill writes outside this project, which needs bypass permission." >&2
    echo "  Allow it, then run the same command again, unchanged." >&2
    exit 1
  fi
  rm -rf "$DEST"
  cp -R "$SRC_DIR/$SKILL" "$DEST" || { echo "error: copy failed: $DEST" >&2; exit 1; }
  # a broken SKILL.md installs silently and then never loads - the receiver should hear it now
  us::validate_skill "$DEST" >/dev/null 2>&1 \
    || echo "note: '$SKILL' has a malformed SKILL.md and may never load - tell $(us::name_of "$KEY")" >&2
  echo "\`$SKILL\` from \`$(us::name_of "$KEY")\` has been $prep $WHERE"
}

us::init
add::parse_args "$@"
add::resolve_skill
add::require_target
add::resolve_dest
add::copy
