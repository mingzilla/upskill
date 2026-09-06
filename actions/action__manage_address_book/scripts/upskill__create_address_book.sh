#!/usr/bin/env bash
# upskill__create_address_book.sh - add an address book to this machine (clone it into the
# workspace under the address_books/<team>/ convention). Does NOT switch to it.
# usage: upskill__create_address_book.sh <repo-url|local-path>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/upskill__lib.sh
source "$SCRIPT_DIR/../../../scripts/upskill__lib.sh"

us::init "${UP_SKILL_WORKSPACE:-$PWD}"

url="${1:-}"
if [[ -z "$url" ]]; then
  echo "usage: upskill__create_address_book.sh <repo-url|local-path>" >&2
  echo "  e.g. upskill__create_address_book.sh https://github.com/mingzilla/upskill__address_book__design.git" >&2
  exit 1
fi
us::require git

# folder name follows the convention: <...>/upskill__address_book__<team> -> team__<team>
base="$(basename "${url%%/}")"
base="${base%.git}"
if [[ "$base" == upskill__address_book__* ]]; then
  team="team__${base#upskill__address_book__}"
else
  team="$base"
fi

dest="$US_WORKSPACE/address_books/$team/$base"
if [[ -d "$dest/.git" ]]; then
  echo "address book already exists at $dest - nothing to do" >&2
  exit 0
fi
mkdir -p "$(dirname "$dest")"
echo "cloning $url"
git clone --quiet "$url" "$dest"

if [[ ! -f "$dest/address_book.json" ]]; then
  echo "error: no address_book.json in the cloned repo ($dest) - not an address book" >&2
  exit 1
fi

echo "created address book '$team' at $dest"
echo "  switch to it with: upskill__switch_address_book.sh ${team#team__}"
