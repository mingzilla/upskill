#!/bin/bash
# upskill__uninstall.sh - unlink the skill from every agent on this machine.
#
# Your skills_lib tree is NEVER deleted: it holds your repos, your sandbox and your private files.
# This only removes the links that make agents load upskill.
set -uo pipefail

uns::unlink_agents() {
  local root removed=0
  for root in "$HOME/.claude/skills" "$HOME/.codex/skills"; do
    [[ -e "$root/upskill" || -L "$root/upskill" ]] || continue
    if [[ -L "$root/upskill" ]]; then
      rm -f "$root/upskill"
      echo "  unlinked  $root/upskill"
      removed=1
    else
      echo "  kept      $root/upskill is a real folder, not a link - delete it yourself if you mean to" >&2
    fi
  done
  [[ "$removed" -eq 1 ]] || echo "  nothing linked"
}

ROOT=""

# read the config through the link before it is removed, so the report can still say where
uns::find_root() {
  local cfg
  for cfg in "$HOME/.claude/skills/upskill/upskill__user_config.json" \
             "$HOME/.codex/skills/upskill/upskill__user_config.json"; do
    [[ -f "$cfg" ]] || continue
    ROOT="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("skills_lib_root", ""))' "$cfg" 2>/dev/null)"
    [[ -n "$ROOT" ]] && break
  done
}

uns::report() {
  echo
  echo "== done =="
  [[ -n "$ROOT" ]] && echo "  your skills are still at: $ROOT"
  echo "  re-install by running upskill__install.sh again"
}

uns::find_root
uns::unlink_agents
uns::report
