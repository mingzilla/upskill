#!/bin/bash
# upskill__share.sh - copy one of my skills into public_skills and push it.
# usage: upskill__share.sh <skill-folder|skill-name> [message]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/upskill__lib.sh"

WANT=""
MSG=""
SRC=""
NAME=""
DEST=""

share::parse_args() {
  WANT="${1:-}"
  MSG="${2:-}"
  [[ -n "$WANT" ]] || { echo "usage: upskill__share.sh <skill-folder|skill-name> [message]" >&2; exit 1; }
}

# a skill can be named rather than pathed, so look where a person actually keeps them
share::resolve_src() {
  if [[ -d "$WANT" ]]; then
    SRC="$(cd "$WANT" && pwd)"
  else
    us::safe_name "$WANT" || exit 1
    local found=()
    [[ -d "$PWD/.claude/skills/$WANT" ]] && found+=("$PWD/.claude/skills/$WANT")
    local d
    for d in "$US_ROOT/private_skills/$WANT" "$US_ROOT/private_skills"/*/.claude/skills/"$WANT"; do
      [[ -d "$d" ]] && found+=("$d")
    done
    if [[ "${#found[@]}" -eq 0 ]]; then
      echo "error: skill not found: '$WANT'" >&2
      echo "  give a folder path, or a skill name in this project or in private_skills" >&2
      exit 1
    fi
    if [[ "${#found[@]}" -gt 1 ]]; then
      echo "error: '$WANT' matches more than one folder - share it by path:" >&2
      printf '  %s\n' "${found[@]}" >&2
      exit 1
    fi
    SRC="${found[0]}"
  fi
  NAME="$(basename "$SRC")"
  us::safe_name "$NAME" || exit 1
  # a skill only reaches the team if it will actually load for them
  us::validate_skill "$SRC" || exit 1
}

# a credential that reaches a public repo is public forever, even after the next commit deletes it
share::scan_source() {
  bash "$SCRIPT_DIR/upskill__scan_secrets.sh" --quiet "$SRC" || exit 1
}

share::check_repo() {
  if [[ ! -d "$US_ME_DIR/.git" ]]; then
    echo "error: your skills repo is missing: $US_ME_DIR" >&2
    echo "  run the installer, or see .install/guide__create_public_skills/README.md" >&2
    exit 1
  fi
  DEST="$US_ME_DIR/$NAME"
}

share::copy() {
  rm -rf "$DEST"
  cp -R "$SRC" "$DEST" || { echo "error: copy failed: $DEST" >&2; exit 1; }
}

# `add -A` stages the whole repo, not just what was copied, so anything an earlier direct edit left
# behind would ride along. Roll the copy back rather than commit it.
share::scan_repo() {
  bash "$SCRIPT_DIR/upskill__scan_secrets.sh" --quiet "$US_ME_DIR" && return 0
  rm -rf "$DEST"
  exit 1
}

share::push() {
  git -c safe.directory='*' -C "$US_ME_DIR" add -A || { echo "error: git add failed" >&2; exit 1; }
  if git -c safe.directory='*' -C "$US_ME_DIR" diff --cached --quiet; then
    echo "no change - \`$NAME\` is already shared"
    exit 0
  fi
  if ! git -c safe.directory='*' -C "$US_ME_DIR" commit -q -m "share $NAME${MSG:+: $MSG}"; then
    echo "error: commit failed" >&2
    # by far the most common cause on a fresh machine, and git's own message is easy to miss
    if [[ -z "$(git -C "$US_ME_DIR" config user.email 2>/dev/null)" ]]; then
      echo "  git does not know who you are. Set it once:" >&2
      echo "    git config --global user.name \"Your Name\"" >&2
      echo "    git config --global user.email \"you@example.com\"" >&2
    fi
    exit 1
  fi
  git -c safe.directory='*' -C "$US_ME_DIR" push -q \
    || { echo "error: push failed - check your github access for $(share::origin)" >&2; exit 1; }
}

share::origin() {
  git -c safe.directory='*' -C "$US_ME_DIR" remote get-url origin 2>/dev/null
}

# my own listing is read from the pool clone, not from public_skills - without this refresh the
# skill I just shared is missing from "show my skills"
share::refresh_pool() {
  local key dir
  key="$(us::my_key)" || return 0
  [[ -n "$key" ]] || return 0
  dir="$(us::pool_dir "$key")"
  [[ -d "$dir/.git" ]] || return 0
  git -c safe.directory='*' -C "$dir" pull --ff-only --quiet 2>/dev/null
  return 0
}

share::report() {
  echo "\`$NAME\` has been uploaded to \`$(share::origin)\`"
}

us::init
share::parse_args "$@"
share::resolve_src
share::scan_source
share::check_repo
share::copy
share::scan_repo
share::push
share::refresh_pool
share::report
