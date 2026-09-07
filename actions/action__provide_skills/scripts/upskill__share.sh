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

# how many commits exist here but not on the remote. A run can commit and then fail to push - no
# auth yet, offline, a rejected push - and that commit is then invisible to `diff --cached`. Without
# this check the next share reports "already shared" and the work never reaches anybody.
share::unpushed() {
  local up
  up="$(git -c safe.directory='*' -C "$US_ME_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"
  [[ -n "$up" ]] || { echo 1; return 0; }   # no upstream yet - treat as pending
  git -c safe.directory='*' -C "$US_ME_DIR" rev-list --count "$up..HEAD" 2>/dev/null || echo 1
}

share::do_push() {
  local up
  up="$(git -c safe.directory='*' -C "$US_ME_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"
  if [[ -z "$up" ]]; then
    git -c safe.directory='*' -C "$US_ME_DIR" push -q -u origin HEAD
  else
    git -c safe.directory='*' -C "$US_ME_DIR" push -q
  fi
}

PENDING_ONLY=0

share::push() {
  git -c safe.directory='*' -C "$US_ME_DIR" add -A || { echo "error: git add failed" >&2; exit 1; }

  if git -c safe.directory='*' -C "$US_ME_DIR" diff --cached --quiet; then
    # nothing new to commit - but an earlier run may have left a commit stranded
    if [[ "$(share::unpushed)" -eq 0 ]]; then
      echo "no change - \`$NAME\` is already shared"
      exit 0
    fi
    PENDING_ONLY=1
  else
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
  fi

  if ! share::do_push; then
    echo "error: push failed - $(share::unpushed) commit(s) are waiting to be uploaded" >&2
    echo "  fix your github access, then run the same share again - it will retry the push" >&2
    exit 1
  fi
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
  if [[ "$PENDING_ONLY" -eq 1 ]]; then
    echo "\`$NAME\` was already committed but had never been uploaded - it is now on \`$(share::origin)\`"
  else
    echo "\`$NAME\` has been uploaded to \`$(share::origin)\`"
  fi
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
