#!/bin/bash
# upskill__remove.sh - take one of MY shared skills back out of public_skills.
# usage: upskill__remove.sh [<skill|number>]   (no argument lists them, numbered)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/upskill__lib.sh"

WANT=""
NAME=""

rm::parse_args() {
  WANT="${1:-}"
}

rm::check_repo() {
  [[ -d "$US_ME_DIR/.git" ]] || {
    echo "error: your skills repo is missing: $US_ME_DIR" >&2
    exit 1
  }
}

# no argument: show what can be removed, numbered, and stop - the user picks
rm::list_mine() {
  [[ -n "$WANT" ]] && return 0
  local names n=0 name
  names="$(us::skill_names "$US_ME_DIR")"
  if [[ -z "$names" ]]; then
    echo "you have not shared any skills yet"
    exit 0
  fi
  echo "Your shared skills - say which to remove"
  while IFS= read -r name; do
    n=$((n + 1))
    echo "$n. $name"
  done <<< "$names"
  exit 0
}

rm::resolve() {
  if [[ "$WANT" =~ ^[0-9]+$ ]]; then
    NAME="$(us::skill_names "$US_ME_DIR" | sed -n "${WANT}p")"
    [[ -n "$NAME" ]] || { echo "error: there is no shared skill $WANT" >&2; exit 1; }
  else
    NAME="$WANT"
  fi
  us::safe_name "$NAME" || exit 1
  [[ -d "$US_ME_DIR/$NAME" ]] || {
    echo "error: you have not shared a skill called '$NAME'" >&2
    exit 1
  }
}

rm::unpushed() {
  local up
  up="$(git -c safe.directory='*' -C "$US_ME_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"
  [[ -n "$up" ]] || { echo 1; return 0; }
  git -c safe.directory='*' -C "$US_ME_DIR" rev-list --count "$up..HEAD" 2>/dev/null || echo 1
}

rm::push() {
  rm -rf "${US_ME_DIR:?}/$NAME"
  git -c safe.directory='*' -C "$US_ME_DIR" add -A || { echo "error: git add failed" >&2; exit 1; }
  if git -c safe.directory='*' -C "$US_ME_DIR" diff --cached --quiet; then
    # already gone locally - but an earlier run may have failed to push the removal
    if [[ "$(rm::unpushed)" -eq 0 ]]; then
      echo "no change - \`$NAME\` was not shared"
      exit 0
    fi
  else
    if ! git -c safe.directory='*' -C "$US_ME_DIR" commit -q -m "remove $NAME"; then
      echo "error: commit failed" >&2
      if [[ -z "$(git -C "$US_ME_DIR" config user.email 2>/dev/null)" ]]; then
        echo "  git does not know who you are - set user.name and user.email" >&2
      fi
      exit 1
    fi
  fi
  if ! git -c safe.directory='*' -C "$US_ME_DIR" push -q; then
    echo "error: push failed - $(rm::unpushed) commit(s) are waiting to be uploaded" >&2
    echo "  fix your github access, then run the same remove again - it will retry the push" >&2
    exit 1
  fi
}

# without this the pool copy still lists the skill I just removed
rm::refresh_pool() {
  local key dir
  key="$(us::my_key)" || return 0
  [[ -n "$key" ]] || return 0
  dir="$(us::pool_dir "$key")"
  [[ -d "$dir/.git" ]] || return 0
  git -c safe.directory='*' -C "$dir" pull --ff-only --quiet 2>/dev/null
  return 0
}

rm::report() {
  local origin
  origin="$(git -c safe.directory='*' -C "$US_ME_DIR" remote get-url origin 2>/dev/null)"
  echo "\`$NAME\` has been removed from \`$origin\`"
}

us::init
rm::parse_args "$@"
rm::check_repo
rm::list_mine
rm::resolve
rm::push
rm::refresh_pool
rm::report
