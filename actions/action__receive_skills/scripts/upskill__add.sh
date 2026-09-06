#!/usr/bin/env bash
# upskill__add.sh - copy a member's shared skill to a target: global, the current project, or a
# selected project.
# usage:
#   upskill__add.sh <owner> <skill> --project current    -> this project's <agent>/skills
#   upskill__add.sh <owner> <skill> --project <path>     -> that project's <agent>/skills
# <agent> is .claude or .codex, taken from UP_SKILL_AGENT_SKILLS (set by the launcher).
#
# If --project is missing, ASK the user which target (global / this project / a path), then call
# again. Never guess.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/upskill__lib.sh
source "$SCRIPT_DIR/../../../scripts/upskill__lib.sh"

us::init "${UP_SKILL_WORKSPACE:-$PWD}"

owner="${1:-}"
skill="${2:-}"
target=""

# parse --project <value>
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) target="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$owner" || -z "$skill" ]]; then
  echo "usage: upskill__add.sh <owner> <skill> --project <current|<path>>" >&2
  exit 1
fi
us::safe_name "$skill"

# which agent is asking: the launcher exports its own skills folder (~/.claude/skills or
# ~/.codex/skills). Everything below installs into THAT agent's layout - a Codex user must not have
# skills copied into .claude, where Codex will never look for them.
agent_skills="${UP_SKILL_AGENT_SKILLS:-$HOME/.claude/skills}"
agent_dir="$(basename "$(dirname "$agent_skills")")"   # .claude or .codex

if [[ -z "$target" ]]; then
  # no target given: print a numbered "where to add" menu and signal the caller to ask (exit 2)
  echo "Where to add '$skill' (from $owner)?"
  echo "1. current project     - this project's $agent_dir/skills"
  echo "2. another project     - you'll be asked for its path"
  echo
  echo "Reply with a number (e.g. \"1\"), or say the target directly."
  exit 2
fi

# resolve the destination skills dir. Skills always go into a project: agents sandbox their own
# user-level skills folder against writes (Codex refuses outright), and a project copy is the one
# both agents can install and read. Only upskill itself lives user-level, put there by the installer.
case "$target" in
  global|user)
    echo "error: skills are added to a project, not user-level" >&2
    echo "  use --project current, or --project <path-to-a-project>" >&2
    exit 1
    ;;
  current) dest_root="$PWD/$agent_dir/skills" ;;
  *)
    if [[ ! -d "$target" ]]; then
      echo "error: target project not found: $target" >&2
      exit 1
    fi
    dest_root="$target/$agent_dir/skills"
    ;;
esac

folder="$(us::folder_of "$owner")"
if [[ -z "$folder" ]]; then
  echo "error: '$owner' is not in the address book" >&2
  exit 1
fi
clone="$US_TEAM_DIR/$folder"
if [[ ! -d "$clone/.git" ]]; then
  echo "error: no local clone for '$owner' at $clone (run the installer first)" >&2
  exit 1
fi

# refresh the owner's clone when it is not me (best effort - an empty repo has no HEAD yet)
if [[ "$folder" != "$US_ME_FOLDER" ]]; then
  git -c safe.directory='*' -C "$clone" pull --ff-only --quiet 2>/dev/null \
    || echo "note: could not pull '$owner' - reading the local clone as-is" >&2
fi

srcskill="$clone/$skill"
if [[ ! -f "$srcskill/SKILL.md" ]]; then
  echo "error: '$owner' has no shared skill '$skill'. Available from $owner:" >&2
  while IFS= read -r s; do echo "  $s" >&2; done < <(us::skill_names "$clone")
  exit 1
fi

dest="$dest_root/$skill"
rm -rf "$dest"
mkdir -p "$(dirname "$dest")"
cp -R "$srcskill" "$dest"

echo "added '$skill' (from $owner) to $dest"
case "$target" in
  current) echo "  open your agent in '$PWD' and the skill will be available." ;;
  *)       echo "  open your agent in '$target' and the skill will be available." ;;
esac
