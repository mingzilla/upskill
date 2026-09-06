#!/bin/bash
# upskill__find_skill.sh - locate a skill folder by name, wherever the person keeps it.
#
# People lay their repos out differently, so nothing is assumed beyond "a skill is a folder holding
# SKILL.md". Names are matched loosely: the user is speaking, not typing a path, so typos, missing
# prefixes and wrong separators all still find it.
#
# usage: upskill__find_skill.sh <query> [--root <dir>]...
# exit: 0 matches printed | 1 nothing matched
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/upskill__lib.sh"

QUERY=""
ROOTS=()

find::parse_args() {
  QUERY="${1:-}"; shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --root) ROOTS+=("${2:-}"); shift 2 ;;
      *) echo "error: unknown option: $1" >&2; exit 1 ;;
    esac
  done
  [[ -n "$QUERY" ]] || { echo "usage: upskill__find_skill.sh <query> [--root <dir>]..." >&2; exit 1; }
}

# where a person's own skills actually live: this project, and their two repos
find::default_roots() {
  [[ "${#ROOTS[@]}" -gt 0 ]] && return 0
  local d
  for d in "$PWD" "$US_ROOT/private_skills" "$US_ROOT/public_skills"; do
    [[ -d "$d" ]] && ROOTS+=("$d")
  done
}

find::search() {
  UP_SKILL_EXCLUDE="$US_POOL" python3 - "$QUERY" "${ROOTS[@]}" <<'PY'
import os, sys, difflib

query, roots = sys.argv[1], sys.argv[2:]
EXCLUDE = os.path.realpath(os.environ.get("UP_SKILL_EXCLUDE", "")) if os.environ.get("UP_SKILL_EXCLUDE") else None
SKIP = {"node_modules", "__pycache__", "venv", "dist", "build", "target", "vendor"}
MAX_DEPTH = 6        # a skill lives at <project>/.claude/skills/<name> - deeper is someone else's tree
MAX_DIRS = 20000     # a root like ~/code can be enormous; stop rather than hang

def norm(s):
    return "".join(c for c in s.lower() if c.isalnum())

def find_skills(root, budget):
    root = os.path.abspath(root)
    base = root.rstrip(os.sep).count(os.sep)
    for dirpath, dirnames, filenames in os.walk(root):
        if budget[0] <= 0:
            return
        budget[0] -= 1
        if dirpath.count(os.sep) - base >= MAX_DEPTH:
            dirnames[:] = []
            continue
        # hidden folders hold no skills, except the two the agents read from
        dirnames[:] = [d for d in dirnames
                       if d not in SKIP and (not d.startswith(".") or d in (".claude", ".codex"))]
        if "SKILL.md" in filenames:
            yield dirpath
            dirnames[:] = []          # a skill never contains another skill

def score(name, q):
    n, qn = norm(name), norm(q)
    if name == q:      return 100
    if n == qn:        return 95
    if n.startswith(qn) or qn.startswith(n): return 85
    if qn in n:        return 75
    if n in qn:        return 70
    return int(difflib.SequenceMatcher(None, n, qn).ratio() * 65)

budget = [MAX_DIRS]
seen, hits = set(), []
for root in roots:
    for path in find_skills(root, budget):
        real = os.path.realpath(path)
        if real in seen:
            continue
        if EXCLUDE and (real == EXCLUDE or real.startswith(EXCLUDE + os.sep)):
            continue   # that is a copy of someone else's repo, not mine to share
        seen.add(real)
        hits.append((score(os.path.basename(path), query), os.path.basename(path), path))

# a weak best match is still worth showing when it is the only thing close
hits = [h for h in hits if h[0] >= 45]
hits.sort(key=lambda h: (-h[0], h[1]))
hits = hits[:10]

if not hits:
    sys.exit(1)

# nothing to choose between is not a question
if hits[0][0] >= 95 and (len(hits) == 1 or hits[1][0] < hits[0][0]):
    hits = hits[:1]
    print("Found:")
elif len(hits) == 1:
    print("Found:" if hits[0][0] >= 70 else "Closest match - is this the one?")
else:
    print("Which skill did you mean?")
for i, (_, name, path) in enumerate(hits, 1):
    print("%d. %s" % (i, name))
    print("   %s" % path)
PY
}

us::init
find::parse_args "$@"
find::default_roots
find::search || {
  echo "no skill found matching '$QUERY'" >&2
  echo "  looked in: ${ROOTS[*]}" >&2
  exit 1
}
