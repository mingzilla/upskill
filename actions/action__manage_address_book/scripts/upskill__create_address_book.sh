#!/bin/bash
# upskill__create_address_book.sh - make an address book from name+repo pairs, as a sandbox draft.
# usage: upskill__create_address_book.sh <name> <repo-url> [<name> <repo-url> ...]
#
# The draft lives at <sandbox>/address_book.json and never touches the active book. If a draft is
# already there the user is told up front and the new entries are merged in - on a matching key the
# new entry replaces the existing one.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/upskill__lib.sh"

cr::init() {
  us::require python3
  us::load_config
  [[ -d "$US_ROOT" ]] || { echo "error: skills_lib_root does not exist: $US_ROOT" >&2; exit 1; }
  mkdir -p "$US_SANDBOX"   # create has no existing book to copy from - the dir may not exist yet
}

cr::validate_pairs() {
  local args=("$@") i
  if (( ${#args[@]} < 2 )); then
    echo "usage: upskill__create_address_book.sh <name> <repo-url> [<name> <repo-url> ...]" >&2
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

# build/merge in one pass so the book is never left half-written
cr::write() {
  python3 - "$US_SANDBOX" "$@" <<'PY'
import json, os, re, sys

sandbox, args = sys.argv[1], sys.argv[2:]
pairs = list(zip(args[::2], args[1::2]))
target = os.path.join(sandbox, "address_book.json")

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

existed = os.path.exists(target)
if existed:
    try:
        book = json.load(open(target))
    except Exception:
        print("error: the existing address book is not valid json: %s" % target, file=sys.stderr)
        sys.exit(1)
    print("An address book already exists: %s" % target)
    print("New entries are merged in - on a matching key the new entry replaces the existing one.")
else:
    book = {}

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

with open(target, "w") as f:
    json.dump(book, f, indent=2)
    f.write("\n")

if added:
    print("Added: " + ", ".join(sorted(added)))
if updated:
    print("Updated: " + ", ".join(sorted(updated)))
print("Address book: %s (%d members)" % (target, len(users)))
PY
}

cr::init
cr::validate_pairs "$@"
cr::write "$@"
