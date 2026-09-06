#!/usr/bin/env bash
# upskill__show_menu.sh - print the /upskill home screen: every address book, who is in each (with
# skill counts when their repo is on this machine), which one is current, and the actions.
# Read-only. The upskill entry skill prints this output verbatim, then acts on the user's pick.
#
# Layout: no column alignment anywhere. Agents render this reply as markdown, which collapses runs
# of spaces, so padded columns arrive mangled. Structure comes from line breaks and a "- " prefix,
# which markdown keeps - and which also reads correctly in a plain terminal. Members go five to a
# line; a continuation line repeats the "- " prefix rather than indenting, because leading spaces
# would be collapsed too.
#
# usage: bash upskill__show_menu.sh     (run from the workspace, or set UP_SKILL_WORKSPACE)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# the shared lib lives at the skill root: scripts/upskill__lib.sh
LIB="$SCRIPT_DIR/../../../scripts/upskill__lib.sh"
if [[ ! -f "$LIB" ]]; then
  echo "error: shared lib not found (expected $LIB)" >&2
  exit 1
fi
# shellcheck source=../../../scripts/upskill__lib.sh
source "$LIB"

us::init "${UP_SKILL_WORKSPACE:-$PWD}"

# Codex refuses a sandboxed command's writes, so adding a skill needs Full access. Mark it in the
# menu rather than letting the user find out by hitting an error. Claude Code has no such prompt,
# so the marker is only shown when Codex is the one asking (the launcher exports which agent).
agent_dir="$(basename "$(dirname "${UP_SKILL_AGENT_SKILLS:-$HOME/.claude/skills}")")"
add_mark="    "
add_note=""
if [[ "$agent_dir" == ".codex" ]]; then
  add_mark=" (F)"
  add_note='(F) Adding skills requires `Full access` permission'
fi

echo "You can share or receive skills with members from the active address book:"
echo

python3 - "$US_WORKSPACE" "$US_TEAM" <<'PY'
import glob
import json
import os
import sys

ws, current = sys.argv[1], sys.argv[2]
base = os.path.join(ws, "address_books")

PER_ROW = 5
rows = []            # (sort_current, sort_alpha, label, is_current, people, tokens)

if os.path.isdir(base):
    for team in sorted(os.listdir(base)):
        td = os.path.join(base, team)
        if not os.path.isdir(td):
            continue
        cand = glob.glob(os.path.join(td, "*", "address_book.json"))
        if not cand:
            continue
        try:
            users = json.load(open(cand[0])).get("users", {})
        except Exception:
            continue
        label = team[6:] if team.startswith("team__") else team
        tokens = []
        for name, m in users.items():
            folder = m.get("folder", "") if isinstance(m, dict) else ""
            clone = os.path.join(td, folder) if folder else ""
            count = 0
            has_clone = os.path.isdir(clone)
            if has_clone:
                for sub in os.listdir(clone):
                    if os.path.isdir(os.path.join(clone, sub)) and \
                            os.path.isfile(os.path.join(clone, sub, "SKILL.md")):
                        count += 1
            # cloned repo -> "name (count)" (0 is real); no local clone -> name only (unknown)
            tokens.append("%s (%d)" % (name, count) if has_clone else name)
        rows.append((0 if team == current else 1, label.lower(), label,
                     team == current, len(users), tokens))

if not rows:
    print("(no address books installed - add one to get started)")
else:
    rows.sort(key=lambda r: (r[0], r[1]))
    for n, (_, _, label, is_current, people, tokens) in enumerate(rows):
        if n:
            print("")      # blank line between books: without it markdown merges the blocks
        suffix = " - active" if is_current else ""
        print("Address Book: %s (%d members)%s" % (label, people, suffix))
        for i in range(0, len(tokens), PER_ROW):
            print("- " + ", ".join(tokens[i:i + PER_ROW]))
PY

echo
echo "---"
echo
echo "What would you like to do?"
echo "1. Show a member's skills        - e.g. \"show Andy's skills\""
echo "2. Add a member's skill$add_mark      - e.g. \"add Andy's say_hello skill\""
echo "3. Share your skill              - e.g. \"share my xxx skill\""
echo "4. Remove a shared skill         - e.g. \"remove my xxx skill\""
[[ -n "$add_note" ]] && echo "$add_note"
echo
echo "To change address book, use option 5"
echo "5. Add or change address book    - e.g. \"add an address book\""
