#!/bin/bash
# upskill__import_contacts.sh - merge people from another address book into the active one.
# usage: upskill__import_contacts.sh <url|path>
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/upskill__lib.sh"

SRC=""
INCOMING=""

imp::parse_args() {
  SRC="${1:-}"
  [[ -n "$SRC" ]] || {
    echo "usage: upskill__import_contacts.sh <url|path-to-address_book.json>" >&2
    exit 1
  }
}

imp::fetch() {
  INCOMING="$(mktemp)"
  trap 'rm -f "$INCOMING"' EXIT
  if [[ -f "$SRC" ]]; then
    cp "$SRC" "$INCOMING"
  else
    # a github page url returns html; only the raw url returns the json
    local url
    url="$(echo "$SRC" | sed -E 's|github\.com/([^/]+)/([^/]+)/(blob\|tree)/|raw.githubusercontent.com/\1/\2/|')"
    us::require curl
    curl -fsSL "$url" -o "$INCOMING" || { echo "error: cannot download $url" >&2; exit 1; }
  fi
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))["users"]' "$INCOMING" 2>/dev/null \
    || { echo "error: not an address book (no \"users\"): $SRC" >&2; exit 1; }
}

# merge by key. A key already present is left exactly as it is - the local entry is the user's,
# and an import must never rewrite where their skills come from.
imp::merge() {
  python3 -c 'import json,sys

book_path, incoming_path = sys.argv[1], sys.argv[2]
book = json.load(open(book_path))
incoming = json.load(open(incoming_path))
users = book.setdefault("users", {})

added, existing = [], []
for key, member in incoming.get("users", {}).items():
    if key in users:
        existing.append(users[key].get("name", key))
    else:
        users[key] = member
        added.append(member.get("name", key))

# two keys may carry one display name - legal, but the menu would show it twice
seen = {}
for key, member in users.items():
    seen.setdefault(member.get("name", key), []).append(key)
clashes = {n: ks for n, ks in seen.items() if len(ks) > 1}

if added:
    with open(book_path, "w") as f:
        json.dump(book, f, indent=2)
        f.write("\n")

print("Imported: " + ", ".join(sorted(added)) if added else "Imported: nothing new")
if existing:
    print("Already in your address book: " + ", ".join(sorted(existing)))
for name, keys in sorted(clashes.items()):
    print("Name clash - \"" + name + "\" is used by: " + ", ".join(sorted(keys)))
' "$US_AB_JSON" "$INCOMING"
}

us::init
imp::parse_args "$@"
imp::fetch
imp::merge
