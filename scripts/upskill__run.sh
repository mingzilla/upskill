#!/bin/bash
# upskill__run.sh - the launcher every action goes through.
#
# ~/.claude/skills/upskill is a git clone (or a link to one), so updating is a git operation, not a
# reinstall. On prod it mirrors the remote exactly before running; on any other branch it leaves
# the working tree alone, so development is never interrupted.
#
# usage: upskill__run.sh <action|relative-script-path> [args...]
set -uo pipefail   # deliberately not -e: a failed update must never stop the action

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL=""

run::resolve_action() {
  REL="${1:-}"
  [[ -n "$REL" ]] || { echo "usage: upskill__run.sh <action> [args...]" >&2; exit 1; }
  case "$REL" in
    menu)   REL=actions/action__show_menu/scripts/upskill__show_menu ;;
    list)   REL=actions/action__receive_skills/scripts/upskill__list ;;
    add)    REL=actions/action__receive_skills/scripts/upskill__add ;;
    find)   REL=actions/action__provide_skills/scripts/upskill__find_skill ;;
    share)  REL=actions/action__provide_skills/scripts/upskill__share ;;
    remove) REL=actions/action__provide_skills/scripts/upskill__remove ;;
    scan)   REL=actions/action__provide_skills/scripts/upskill__scan_secrets ;;
    import) REL=actions/action__manage_address_book/scripts/upskill__import_contacts ;;
  esac
  # an unknown name is treated as a path, so an action added later works with an older launcher
}

# git refuses a repo owned by another user ("dubious ownership"), which happens routinely when a
# tree on a Windows drive is read from WSL. Trust it per command rather than editing global config.
run::self_update() {
  [[ -d "$SKILL_DIR/.git" ]] || return 0
  local branch
  branch="$(git -c safe.directory='*' -C "$SKILL_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  # only prod is a mirror of the remote; any other branch is someone's working copy
  [[ "$branch" == "prod" ]] || return 0
  git -c safe.directory='*' -C "$SKILL_DIR" fetch --quiet origin prod 2>/dev/null || return 0
  git -c safe.directory='*' -C "$SKILL_DIR" reset --hard --quiet origin/prod 2>/dev/null
  git -c safe.directory='*' -C "$SKILL_DIR" clean -fdq 2>/dev/null
  return 0
}

run::exec_action() {
  local target="$SKILL_DIR/$REL.sh"
  [[ -f "$target" ]] || { echo "error: no such upskill action: $REL" >&2; exit 1; }
  exec bash "$target" "$@"
}

run::resolve_action "$@"
shift
run::self_update
run::exec_action "$@"
