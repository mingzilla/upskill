#!/usr/bin/env bash
# upskill__remove.sh - remove one of YOUR shared skills from your own sharing repo (pushes).
# You can only remove your own items - it always acts on your own repo (US_ME_DIR).
#   upskill__remove.sh              -> list your shared skills, numbered
#   upskill__remove.sh <name|n>     -> remove that shared skill (a number from the list, or a name)
set -euo pipefail

ORIG_PWD="$PWD"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"          # the upskill skill folder
cd "$ROOT"

# shared lib (definitions)
# shellcheck source=../../../scripts/upskill__lib.sh
source "$HERE/../../../scripts/upskill__lib.sh"

# us::remove::list - show your own shared skills numbered
us::remove::list() {
  local skills i s
  skills="$(us::skill_names "$US_ME_DIR")"
  if [[ -z "$skills" ]]; then
    echo "You have no shared skills yet - share one first."
    return 0
  fi
  echo "Your shared skills:"
  i=0
  while IFS= read -r s; do
    i=$((i + 1))
    printf '%3d  %s\n' "$i" "$s"
  done <<< "$skills"
  echo
  echo "Example:"
  echo "- remove 2"
  echo "- remove <skill name>"
}

# us::remove::skill_by <name|n> - echo the matching skill name ('' if not one of yours)
us::remove::skill_by() {
  local want="${1:-}" name i=0
  while IFS= read -r name; do
    i=$((i + 1))
    if [[ "$want" == "$name" || ( "$want" =~ ^[0-9]+$ && "$want" -eq "$i" ) ]]; then
      echo "$name"
      return 0
    fi
  done < <(us::skill_names "$US_ME_DIR")
  return 1
}

# us::remove::do <name> - delete the folder and push the removal
us::remove::do() {
  local name="${1:-}" dest
  name="$(us::remove::skill_by "$name" || true)"
  if [[ -z "$name" ]]; then
    echo "error: '$1' is not one of your shared skills" >&2
    echo "  run: upskill__remove.sh   to see your list" >&2
    exit 1
  fi
  dest="$US_ME_DIR/$name"
  rm -rf "$dest"

  git -C "$US_ME_DIR" add -A
  if git -C "$US_ME_DIR" diff --cached --quiet; then
    echo "'$name' was already gone - nothing to do" >&2
    return 0
  fi
  git -C "$US_ME_DIR" commit -m "remove $name"
  git -C "$US_ME_DIR" branch -M main
  git -C "$US_ME_DIR" push -u origin main

  echo "removed '$name' from your shared skills"
}

# us::remove::run <name|n?> - entrypoint
us::remove::run() {
  us::init "${UP_SKILL_WORKSPACE:-$ORIG_PWD}"
  if [[ -z "${1:-}" ]]; then us::remove::list; else us::remove::do "$1"; fi
}

us::remove::run "$@"
