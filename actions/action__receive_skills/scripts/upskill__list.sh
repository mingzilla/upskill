#!/usr/bin/env bash
# upskill__list.sh - show shared skills (upskill receive action).
#   no owner  -> every member and their skills (team shelf view)
#   <owner>   -> one member's skills, numbered 1..n (so the user can say "Add <n> to <target>")
set -euo pipefail

# path-agnostic entry root (this script runs from any cwd)
ORIG_PWD="$PWD"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"          # the upskill skill folder
cd "$ROOT"

# shared lib (definitions) - resolves the workspace + address book
# shellcheck source=../../../scripts/upskill__lib.sh
source "$HERE/../../../scripts/upskill__lib.sh"

# us::list::team_shelf - every member and their skills
us::list::team_shelf() {
  echo "Skills shared in team '$US_TEAM':"
  local any=0 name folder _repo clone skills s
  while IFS=$'\t' read -r name folder _repo; do
    [[ -n "$name" && -n "$folder" ]] || continue
    clone="$US_TEAM_DIR/$folder"
    if [[ -d "$clone/.git" ]]; then
      git -c safe.directory='*' -C "$clone" pull --ff-only --quiet 2>/dev/null || true
    fi
    skills="$(us::skill_names "$clone")"
    if [[ -n "$skills" ]]; then
      printf '  %s:\n' "$name"
      while IFS= read -r s; do printf '    %s\n' "$s"; done <<< "$skills"
      any=1
    fi
  done < <(us::members)
  if [[ "$any" -eq 0 ]]; then echo "  (no skills shared yet)"; fi   # never the function's status
}

# us::list::member <owner> - one member's skills, numbered with the pick examples
us::list::member() {
  local owner="${1:-}" folder clone skills i s
  folder="$(us::folder_of "$owner")"
  if [[ -z "$folder" ]]; then
    echo "error: '$owner' is not in the address book" >&2
    exit 1
  fi
  clone="$US_TEAM_DIR/$folder"
  if [[ -d "$clone/.git" ]]; then
    git -c safe.directory='*' -C "$clone" pull --ff-only --quiet 2>/dev/null || true
  fi
  skills="$(us::skill_names "$clone")"
  if [[ -z "$skills" ]]; then
    echo "($owner has no skills shared yet)"
    return 0
  fi
  echo "$owner's skills:"
  i=0
  while IFS= read -r s; do
    i=$((i + 1))
    printf '%d. %s\n' "$i" "$s"
  done <<< "$skills"
  echo
  echo "Example:"
  echo "- Add 1 to the current project"
  echo "- Add 1 - (you will be asked where to add it to)"
}

# us::list::run <owner?> - entrypoint
us::list::run() {
  us::init "${UP_SKILL_WORKSPACE:-$ORIG_PWD}"
  if [[ -z "${1:-}" ]]; then us::list::team_shelf; else us::list::member "$1"; fi
}

us::list::run "$@"
