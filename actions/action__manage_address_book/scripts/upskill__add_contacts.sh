#!/bin/bash
# upskill__add_contacts.sh - add name+repo pairs to your OWN (active) address book.
# usage: upskill__add_contacts.sh <name> <repo-url> [<name> <repo-url> ...]
#
# Unlike create_address_book (a sandbox draft), this writes into the book you actually use. A key
# that is already there is replaced by the new entry - you are declaring the contact, so the newest
# version wins.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/upskill__lib.sh"

ac::init() {
  us::init   # the active address book must exist - this adds people to it
}

ac::validate_pairs() {
  local args=("$@") i
  if (( ${#args[@]} < 2 )); then
    echo "usage: upskill__add_contacts.sh <name> <repo-url> [<name> <repo-url> ...]" >&2
    exit 1
  fi
  if (( ${#args[@]} % 2 != 0 )); then
    echo "error: pairs must be <name> <repo-url> - got an odd number of arguments" >&2
    exit 1
  fi
  for (( i = 0; i < ${#args[@]}; i += 2 )); do
    us::safe_name "${args[$i]}" || exit 1
  done
}

ac::merge() {
  python3 - "$US_AB_JSON" "$@" <<'PY'
import json, re, sys

book_path, args = sys.argv[1], sys.argv[2:]
pairs = list(zip(args[::2], args[1::2]))

def key_of(url):
    # normalise git@host:owner/repo.git and https://host/owner/repo.git to owner/repo
    u = url.strip().rstrip("/")
    u = re.sub(r"\.git$", "", u).replace("git@", "")
    for p in ("https://", "http://", "ssh://"):
        u = u.replace(p, "")
    parts = [x for x in u.replace(":", "/").split("/") if x]
    if len(parts) < 2:
        return None
    return parts[-2] + "__" + parts[-1]

for name, url in pairs:
    if not re.match(r"^https?://", url.strip()) or not key_of(url):
        print("error: not a valid repo url: %s" % url, file=sys.stderr)
        sys.exit(1)

try:
    book = json.load(open(book_path, encoding="utf-8-sig"))
except Exception:
    print("error: the address book is not valid json: %s" % book_path, file=sys.stderr)
    sys.exit(1)

users = book.setdefault("users", {})
added, updated = [], []
for name, url in pairs:
    key = key_of(url)
    entry = {"name": name, "folder": key, "repo": url}
    if key in users:
        updated.append(name)
    else:
        added.append(name)
    users[key] = entry

with open(book_path, "w") as f:
    json.dump(book, f, indent=2)
    f.write("\n")

if added:
    print("Added: " + ", ".join(sorted(added)))
if updated:
    print("Updated: " + ", ".join(sorted(updated)))
print("Address book: %s (%d members)" % (book_path, len(users)))
PY
}

ac::init
ac::validate_pairs "$@"
ac::merge "$@"
