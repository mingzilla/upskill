#!/bin/bash
# upskill__list.sh - show one member's shared skills, numbered.
# usage: upskill__list.sh <member>
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/upskill__lib.sh"

WHO=""
KEY=""
DIR=""

list::parse_args() {
  WHO="${1:-}"
  if [[ -z "$WHO" ]]; then
    echo "usage: upskill__list.sh <member>" >&2
    echo "  members: $(us::members | cut -f2 | paste -sd, - | sed 's/,/, /g')" >&2
    exit 1
  fi
}

# only this one member's repo is fetched - listing must never cost a whole address book
list::sync() {
  KEY="$(us::key_of "$WHO")" || exit 1
  us::sync_repo "$KEY" || exit 1
  DIR="$(us::pool_dir "$KEY")"
}

list::print() {
  local names n=0 name
  names="$(us::skill_names "$DIR")"
  if [[ -z "$names" ]]; then
    echo "$(us::name_of "$KEY") has not shared any skills yet"
    return 0
  fi
  echo "Choose what to add to your projects"
  while IFS= read -r name; do
    n=$((n + 1))
    echo "$n. $name"
  done <<< "$names"
}

us::init
list::parse_args "$@"
list::sync
list::print
