#!/usr/bin/env bash
# upskill__run.sh - the launcher every action goes through.
#
# The installed copy of this skill must never need replacing: it pulls the workspace clone to the
# latest prod and then runs the real script FROM THERE. So a push to prod takes effect on the very
# next run, and a user is never asked to install again - even if the copy in ~/.claude/skills or
# ~/.codex/skills is old, because nothing but this launcher is read from it.
#
# usage: upskill__run.sh <action|relative-script-path> [args...]
#   <action> is a short name (menu, list, add, install, share, remove, create-address-book,
#   switch-address-book); an unknown name is treated as a path under the skill folder, so actions
#   added to prod later still work with an old launcher.
set -uo pipefail   # deliberately not -e: a failed pull must never stop the action

rel="${1:-}"
[[ -n "$rel" ]] || { echo "usage: upskill__run.sh <action> [args...]" >&2; exit 1; }
shift

case "$rel" in
  menu)                  rel=actions/action__show_menu/scripts/upskill__show_menu ;;
  list)                  rel=actions/action__receive_skills/scripts/upskill__list ;;
  add)                   rel=actions/action__receive_skills/scripts/upskill__add ;;
  install)               rel=actions/action__receive_skills/scripts/upskill__install ;;
  share)                 rel=actions/action__provide_skills/scripts/upskill__share ;;
  remove)                rel=actions/action__provide_skills/scripts/upskill__remove ;;
  create-address-book)   rel=actions/action__manage_address_book/scripts/upskill__create_address_book ;;
  switch-address-book)   rel=actions/action__manage_address_book/scripts/upskill__switch_address_book ;;
esac

# resolve the workspace the same way the library does: env, then upward from here, then the profile
ws="${UP_SKILL_WORKSPACE:-}"
if [[ -z "$ws" ]]; then
  d="$PWD"
  while :; do
    [[ -f "$d/upskill__user-config.json" ]] && { ws="$d"; break; }
    [[ "$d" == "/" ]] && break
    d="$(dirname "$d")"
  done
fi
[[ -z "$ws" && -d "$HOME/.upskill__workspace" ]] && ws="$HOME/.upskill__workspace"

# take the newest prod before deciding what to run
# git refuses to touch a repo whose owner differs from the caller ("dubious ownership") - which
# happens routinely here: the workspace can be created by the Windows installer and then read by
# WSL, or vice versa. Trust it for the length of a single command rather than editing the user's
# global git config.
sol="$ws/upskill"
if [[ -n "$ws" && -d "$sol/.git" ]]; then
  if ! git -c safe.directory='*' -C "$sol" pull --ff-only --quiet 2>/dev/null; then
    if [[ -n "$(git -c safe.directory='*' -C "$sol" status --porcelain 2>/dev/null)" ]]; then
      echo "note: upskill is not updating - '$sol' has local changes; discard them there." >&2
    fi
  fi
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # the installed skill folder
src="$sol/_system/l2_share_skills/.claude/skills/upskill"

# keep the installed copy in step with prod - it is what the agent READS (SKILL.md, the action
# docs) even though it is not what runs. Overlay rather than delete-and-replace, so the launcher
# executing right now is never removed out from under itself. Best effort: never fatal.
here_parent="$(dirname "$here")"
if [[ "$here_parent" == */.claude/skills || "$here_parent" == */.codex/skills ]]; then
  # tell the action which agent invoked it. The action scripts run from the workspace now, so their
  # own path no longer says whether this is Claude Code or Codex - and "add to my user skills" must
  # land in the caller's folder, not always ~/.claude/skills.
  export UP_SKILL_AGENT_SKILLS="$here_parent"
  if [[ -f "$src/SKILL.md" ]]; then
    cp -R "$src/." "$here/" 2>/dev/null || echo "note: could not refresh $here" >&2
  fi
fi

target="$src/$rel.sh"
[[ -f "$target" ]] || target="$here/$rel.sh"              # no workspace? run what is installed
[[ -f "$target" ]] || { echo "error: no such upskill action: $rel" >&2; exit 1; }

exec bash "$target" "$@"
