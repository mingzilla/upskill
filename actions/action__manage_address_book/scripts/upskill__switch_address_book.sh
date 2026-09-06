#!/usr/bin/env bash
# upskill__switch_address_book.sh - point the config at another address book that is already
# installed on this machine (the one whose members you want to see/work with).
# usage: upskill__switch_address_book.sh <team-or-address-book-name>
#   e.g. upskill__switch_address_book.sh sandbox
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/upskill__lib.sh
source "$SCRIPT_DIR/../../../scripts/upskill__lib.sh"

us::init "${UP_SKILL_WORKSPACE:-$PWD}"

want="${1:-}"
if [[ -z "$want" ]]; then
  echo "usage: upskill__switch_address_book.sh <team-or-address-book-name>" >&2
  echo "  e.g. upskill__switch_address_book.sh sandbox" >&2
  exit 1
fi

# normalise the two accepted spellings (sandbox / team__sandbox / upskill__address_book__sandbox)
case "$want" in
  team__*)            team_want="$want" ;;
  upskill__address_book__*) team_want="team__${want#upskill__address_book__}" ;;
  *)                  team_want="team__$want" ;;
esac

# find the address-book folder under the requested team
ab_dir=""
for d in "$US_WORKSPACE"/address_books/"$team_want"/*/; do
  [[ -d "$d" ]] || continue
  if [[ -f "$d/address_book.json" ]]; then ab_dir="${d%/}"; break; fi
done
if [[ -z "$ab_dir" ]]; then
  echo "error: no installed address book for '$team_want'" >&2
  echo "  installed: $(ls -1 "$US_WORKSPACE"/address_books 2>/dev/null | tr '\n' ' ')" >&2
  echo "  add one first with: upskill__create_address_book.sh <repo-url>" >&2
  exit 1
fi
ab_name="$(basename "$ab_dir")"

cfg="$US_WORKSPACE/upskill__user-config.json"
python3 - "$cfg" "$team_want" "$ab_name" <<'PY'
import json, sys
cfg, team, ab = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(cfg))
d["team"] = team
d["address_book"] = f"./address_books/{team}/{ab}"
with open(cfg, "w") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
PY

echo "switched to address book '$team_want' (user '${US_USER}')"
echo "  run upskill again to see its members."
