#!/usr/bin/env bash
# upskill__lib.sh - shared helpers for the upskill client scripts.
# Sourced (never executed): `source .../upskill__lib.sh`, then call `us::init`.
#
# Resolves the .upskill__workspace (nearest ancestor holding upskill__user-config.json,
# or $UP_SKILL_WORKSPACE) and loads the user config + team address book into US_* globals.

set -euo pipefail

# the installed copy this run is executing from: <agent skills dir>/upskill/scripts/ -> its parent.
# Captured at source time, because that is when BASH_SOURCE points at this file.
US_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

US_WORKSPACE=""       # root of this machine's upskill__workspace
US_USER=""            # this member's name (matches the address book)
US_TEAM=""            # e.g. team__sandbox
US_ADDRESS_BOOK=""    # dir of the cloned address-book repo
US_AB_JSON=""         # path to address_book.json
US_TEAM_DIR=""        # dir holding the address book + every member's sharing clone
US_ME_FOLDER=""       # my skills-repo clone folder name, e.g. upskill__skills_repo__leah
US_ME_DIR=""          # absolute path of my sharing clone

us::require() {
  local tool="$1"
  # being on PATH is not proof: Windows ships python3/python stubs in WindowsApps that resolve and
  # then fail to run, so ask the tool itself
  if command -v "$tool" >/dev/null 2>&1 && "$tool" --version >/dev/null 2>&1; then return 0; fi
  echo "error: '$tool' is not installed, and upskill needs it" >&2
      # who actually hits this: a Windows user whose agent picked bash. There the fix is not a
      # package manager - it is to run the .ps1 scripts, which need neither python3 nor bash.
      case "$(uname -s 2>/dev/null)" in
        MINGW*|MSYS*|CYGWIN*)
          echo "  you are on Windows - run the .ps1 version of this script instead:" >&2
          echo "    powershell -NoProfile -ExecutionPolicy Bypass -File <same-script>.ps1" >&2
          echo "  it needs neither python3 nor bash. (Or install Python from python.org.)" >&2 ;;
        Darwin)
          echo "  install it: brew install $tool" >&2 ;;
        *)
          echo "  install it: sudo apt install $tool   (or your distro's package manager)" >&2 ;;
      esac
  exit 1
}

# us::jget <json-file> <python-expr-on-d> - print one value read from a JSON file
us::jget() {
  python3 -c 'import json,sys
d = json.load(open(sys.argv[1]))
r = eval(sys.argv[2])
print(r if isinstance(r, str) else json.dumps(r))' "$1" "$2"
}

# us::locate_workspace <start-dir> - set US_WORKSPACE to nearest ancestor holding the config
us::locate_workspace() {
  local dir="${1:-$PWD}"
  [[ -d "$dir" ]] || dir="$(dirname "$dir")"
  while :; do
    if [[ -f "$dir/upskill__user-config.json" ]]; then
      US_WORKSPACE="$dir"
      return 0
    fi
    [[ "$dir" == "/" ]] && break
    dir="$(dirname "$dir")"
  done
  return 1
}

# us::load_config - fill US_* from upskill__user-config.json
us::load_config() {
  local cfg="$US_WORKSPACE/upskill__user-config.json"
  US_USER=$(us::jget "$cfg" 'd["user"]')
  US_TEAM=$(us::jget "$cfg" 'd.get("team", "")')
  local ab_rel
  ab_rel=$(us::jget "$cfg" 'd["address_book"]')
  US_ADDRESS_BOOK="$US_WORKSPACE/$ab_rel"
  US_AB_JSON="$US_ADDRESS_BOOK/address_book.json"
  US_TEAM_DIR="$(dirname "$US_ADDRESS_BOOK")"
}

# us::members - print address-book rows as: name<TAB>folder<TAB>repo
us::members() {
  python3 -c 'import json,sys
ab = json.load(open(sys.argv[1]))
for n, m in ab.get("users", {}).items():
    print(n + "\t" + m.get("folder", "") + "\t" + m.get("repo", ""))' "$US_AB_JSON"
}

# us::folder_of <member-name> - print that member's sharing-clone folder name
us::folder_of() {
  python3 -c 'import json,sys
ab = json.load(open(sys.argv[1]))
print(ab["users"].get(sys.argv[2], {}).get("folder", ""))' "$US_AB_JSON" "$1"
}

# us::validate_skill <skill-dir> - refuse a skill that would install but never load.
# Only checks failures that are otherwise SILENT: an agent given a SKILL.md with broken frontmatter,
# or an empty description, does not complain - the skill is simply never triggered, and the user
# concludes upskill is broken. Everything else about a skill is its author's business.
# Prints what is wrong and returns 1; returns 0 when the skill is loadable.
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
    # the closing --- of the frontmatter, searched from line 2
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

# us::skill_names <sharing-clone-dir> - immediate child names that contain SKILL.md, sorted by name.
# The sort is required, not cosmetic: the user picks a skill by the number shown, so bash and
# PowerShell must number the same list identically - LC_ALL=C keeps that true in any locale.
us::skill_names() {
  local root="$1" d
  [[ -d "$root" ]] || return 0
  for d in "$root"/*/; do
    [[ -e "$d" ]] || continue
    [[ -f "$d/SKILL.md" ]] && printf '%s\n' "$(basename "$d")"
  done | LC_ALL=C sort
  return 0   # a trailing non-skill folder must not make the whole listing look like a failure
}

# us::safe_name <name> - reject empty / pathy / dot-dot names before they reach a filesystem path
us::safe_name() {
  local n="$1"
  if [[ -z "$n" || "$n" == */* || "$n" == *".."* ]]; then
    echo "error: not a valid name: '$n'" >&2
    return 1
  fi
}

# us::init [start-dir] - resolve workspace, load config, validate address book + my membership
us::init() {
  local start="${1:-$PWD}"
  us::require python3
  us::require git
  if [[ -n "${UP_SKILL_WORKSPACE:-}" && -d "$UP_SKILL_WORKSPACE" ]]; then
    US_WORKSPACE="$UP_SKILL_WORKSPACE"
  elif ! us::locate_workspace "$start" && [[ -d "$HOME/.upskill__workspace" ]]; then
    US_WORKSPACE="$HOME/.upskill__workspace"   # global default: workspace lives under the user profile
  elif [[ -z "${US_WORKSPACE:-}" ]]; then
    echo "error: no .upskill__workspace found from '$start' (looked upward for upskill__user-config.json)" >&2
    echo "  run inside your .upskill__workspace, or set UP_SKILL_WORKSPACE=<path>" >&2
    exit 1
  fi
  us::load_config || { echo "error: cannot read config in $US_WORKSPACE" >&2; exit 1; }
  if [[ ! -f "$US_AB_JSON" ]]; then
    echo "error: address book not found at $US_AB_JSON (run install.sh first)" >&2
    exit 1
  fi
  US_ME_FOLDER="$(us::folder_of "$US_USER")"
  if [[ -z "$US_ME_FOLDER" ]]; then
    echo "error: '$US_USER' is not in the address book ($US_AB_JSON)" >&2
    exit 1
  fi
  US_ME_DIR="$US_TEAM_DIR/$US_ME_FOLDER"

  # self-update: pull the workspace solution (prod) and refresh the global skills - quiet, best-effort
  us::self_update
}

# us::self_update - the user never reruns the installer, so take the newest prod on every use.
# Copying it into the agents' folders is the launcher's job (upskill__run.sh): it knows which
# installed copy invoked it, and it must not be attempted from inside the workspace clone - whose
# own layout contains a .claude/skills path that looks exactly like an agent's.
us::self_update() {
  local sol="$US_WORKSPACE/upskill"
  [[ -d "$sol/.git" ]] || return 0
  # a failed pull is usually transient (offline) and self-heals, but local changes in this clone
  # freeze the user on an old version for good - and they never re-run the installer. Say so.
  if ! git -c safe.directory='*' -C "$sol" pull --ff-only --quiet 2>/dev/null; then
    if [[ -n "$(git -c safe.directory='*' -C "$sol" status --porcelain 2>/dev/null)" ]]; then
      echo "note: upskill is not updating - '$sol' has local changes; discard them there." >&2
    fi
  fi
  return 0
}
