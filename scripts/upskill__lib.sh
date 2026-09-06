#!/bin/bash
# upskill__lib.sh - shared helpers. Sourced, never executed:
#   source .../upskill__lib.sh && us::init
#
# The skill folder IS the git repo, and the config sits inside it - so nothing is searched for.

US_SKILL_DIR=""   # folder holding SKILL.md (this file's parent)
US_ROOT=""        # skills_lib_root from the config
US_AB_JSON=""     # active address book
US_POOL=""        # <root>/upskill__address_book - one clone per member repo
US_ME_DIR=""      # <root>/public_skills - the only repo I write to
US_SANDBOX=""     # <root>/upskill__sandbox

US_SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# being on PATH is not proof: Windows ships python3 stubs that resolve and then fail to run
us::require() {
  local tool="$1"
  command -v "$tool" >/dev/null 2>&1 && "$tool" --version >/dev/null 2>&1 && return 0
  echo "error: '$tool' is not installed, and upskill needs it" >&2
  exit 1
}

# us::jget <json-file> <python-expr-on-d> - print one value read from a json file
us::jget() {
  python3 -c 'import json,sys
d = json.load(open(sys.argv[1]))
r = eval(sys.argv[2])
print(r if isinstance(r, str) else json.dumps(r))' "$1" "$2"
}

us::load_config() {
  local cfg="$US_SKILL_DIR/upskill__user_config.json"
  if [[ ! -f "$cfg" ]]; then
    echo "error: not configured - $cfg is missing" >&2
    echo "  run the installer: .install/upskill__install.sh" >&2
    exit 1
  fi
  US_ROOT="$(us::jget "$cfg" 'd["skills_lib_root"]')"
  local ab_rel
  ab_rel="$(us::jget "$cfg" 'd["address_book"]')"
  US_AB_JSON="$US_ROOT/${ab_rel#./}"
  US_POOL="$US_ROOT/upskill__address_book"
  US_ME_DIR="$US_ROOT/public_skills"
  US_SANDBOX="$US_ROOT/upskill__sandbox"
}

us::init() {
  us::require python3
  us::require git
  us::load_config
  [[ -d "$US_ROOT" ]] || { echo "error: skills_lib_root does not exist: $US_ROOT" >&2; exit 1; }
  [[ -f "$US_AB_JSON" ]] || { echo "error: address book not found: $US_AB_JSON" >&2; exit 1; }
}

# us::members - one row per member: key<TAB>name<TAB>repo, ordered by display name.
# The order is not cosmetic: the user picks by the number shown, so every listing must agree.
us::members() {
  python3 -c 'import json,sys
ab = json.load(open(sys.argv[1]))
rows = [(k, m.get("name", k), m.get("repo", "")) for k, m in ab.get("users", {}).items()]
for k, n, r in sorted(rows, key=lambda x: (x[1].lower(), x[0])):
    print(k + "\t" + n + "\t" + r)' "$US_AB_JSON"
}

# us::key_of <name-or-key> - print the address book key for a member.
# Two members may share a display name (the key is the repo, the name is only an alias), so an
# ambiguous name is reported rather than guessed.
us::key_of() {
  local want="$1" out
  out="$(python3 -c 'import json,sys
ab = json.load(open(sys.argv[1]))
want = sys.argv[2].strip().lower()
hits = [k for k, m in ab.get("users", {}).items() if m.get("name", k).lower() == want or k.lower() == want]
print("\t".join(hits))' "$US_AB_JSON" "$want")"
  case "$out" in
    "") echo "error: '$want' is not in the address book" >&2
        echo "  members: $(us::members | cut -f2 | paste -sd' ')" >&2
        return 1 ;;
    *$'\t'*) echo "error: '$want' matches more than one member: ${out//$'\t'/, }" >&2
        echo "  say which one by its full key" >&2
        return 1 ;;
    *) printf '%s\n' "$out" ;;
  esac
}

# us::repo_of <key> - print that member's git url
us::repo_of() {
  us::jget "$US_AB_JSON" "d[\"users\"][\"$1\"][\"repo\"]"
}

# us::name_of <key> - print that member's display name
us::name_of() {
  us::jget "$US_AB_JSON" "d[\"users\"].get(\"$1\", {}).get(\"name\", \"$1\")"
}

# us::pool_dir <key> - where that member's repo is cloned
us::pool_dir() {
  printf '%s\n' "$US_POOL/$1"
}

# us::sync_repo <key> - clone it if missing, otherwise pull. Never re-clones: an existing local
# copy is the user's, and re-cloning would throw away anything they did to it.
us::sync_repo() {
  local key="$1" dir url
  dir="$(us::pool_dir "$key")"
  if [[ -d "$dir/.git" ]]; then
    git -c safe.directory='*' -C "$dir" pull --ff-only --quiet 2>/dev/null \
      || echo "note: could not update $(us::name_of "$key") - showing the local copy" >&2
    return 0
  fi
  url="$(us::repo_of "$key")"
  [[ -n "$url" ]] || { echo "error: no repo url for '$key'" >&2; return 1; }
  git clone --quiet "$url" "$dir" 2>/dev/null \
    || { echo "error: cannot clone $url" >&2; return 1; }
}

# us::my_key - my own address book key, matched by the origin url of public_skills.
# Identity comes from the repo I can push to, not from a name in the config: nothing to keep in sync.
us::my_key() {
  local origin
  origin="$(git -c safe.directory='*' -C "$US_ME_DIR" remote get-url origin 2>/dev/null)"
  [[ -n "$origin" ]] || return 1
  python3 -c 'import json,sys

def norm(u):
    # ssh (git@host:owner/repo.git) and https (https://host/owner/repo.git) name the same repo
    u = u.strip().rstrip("/")
    if u.endswith(".git"):
        u = u[:-4]
    for p in ("git@", "https://", "http://", "ssh://"):
        u = u.replace(p, "")
    parts = [x for x in u.replace(":", "/").split("/") if x]
    return "/".join(parts[-2:]).lower()

ab = json.load(open(sys.argv[1]))
want = norm(sys.argv[2])
for k, m in ab.get("users", {}).items():
    if norm(m.get("repo", "")) == want:
        print(k)
        break' "$US_AB_JSON" "$origin"
}

# us::validate_skill <skill-dir> - refuse a skill that would install but never load.
# Only checks failures that are otherwise SILENT: broken frontmatter or a missing description means
# the skill is simply never triggered, and the user concludes upskill is broken.
us::validate_skill() {
  local dir="${1:-}" md="${1:-}/SKILL.md" first close block problems=()
  if [[ ! -f "$md" ]]; then
    echo "error: not a skill folder (no SKILL.md): $dir" >&2
    return 1
  fi
  first="$(head -n 1 "$md" | tr -d '\r')"
  if [[ "$first" != "---" ]]; then
    problems+=("the file must start with a --- frontmatter block")
  else
    close="$(tail -n +2 "$md" | grep -n -m1 '^---[[:space:]]*$' | cut -d: -f1)"
    if [[ -z "$close" ]]; then
      problems+=("the frontmatter block is never closed with ---")
    else
      block="$(tail -n +2 "$md" | head -n $((close - 1)))"
      grep -qE '^name:[[:space:]]*[^[:space:]]' <<< "$block" || problems+=("frontmatter has no 'name:'")
      grep -qE '^description:[[:space:]]*[^[:space:]]' <<< "$block" \
        || problems+=("frontmatter has no 'description:' - without it an agent never triggers the skill")
    fi
  fi
  if [[ "${#problems[@]}" -gt 0 ]]; then
    echo "error: '$(basename "$dir")' cannot be shared - it would install but never load:" >&2
    local p
    for p in "${problems[@]}"; do echo "  - $p" >&2; done
    echo "  fix $md and try again." >&2
    return 1
  fi
  return 0
}

# us::skill_names <dir> - immediate child folders holding a SKILL.md, sorted.
# LC_ALL=C keeps the numbering identical in every locale - the user picks by number.
us::skill_names() {
  local root="$1" d
  [[ -d "$root" ]] || return 0
  for d in "$root"/*/; do
    [[ -e "$d" ]] || continue
    [[ -f "$d/SKILL.md" ]] && printf '%s\n' "$(basename "$d")"
  done | LC_ALL=C sort
  return 0
}

# us::safe_name <name> - reject empty / pathy / dot-dot names before they reach a filesystem path
us::safe_name() {
  local n="$1"
  if [[ -z "$n" || "$n" == */* || "$n" == *".."* ]]; then
    echo "error: not a valid name: '$n'" >&2
    return 1
  fi
}
