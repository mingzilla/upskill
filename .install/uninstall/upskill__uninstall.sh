#!/bin/bash
# upskill__uninstall.sh - remove upskill from this machine's agents.
#
# This runs on someone else's computer, so nothing is deleted on the strength of a path alone.
# Every removal is proved first: a link must BE a link and point where we expect; the real install
# must BE a git clone of the upskill repo. Anything that fails a check is left alone and reported.
#
# Your skills_lib tree - repos, sandbox, private files - is never touched.
set -uo pipefail

CORE_REPO="mingzilla/upskill"
SKILL_DIR="$HOME/.claude/skills/upskill"
AGENT_LINKS=("$HOME/.codex/skills/upskill" "$HOME/.agent/skills/upskill")
ROOT=""

# read the config before anything is removed, so the report can still say where the skills are
uns::find_root() {
  local cfg="$SKILL_DIR/upskill__user_config.json"
  [[ -f "$cfg" ]] || return 0
  ROOT="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("skills_lib_root",""))' "$cfg" 2>/dev/null)"
}

# owner/repo from either git@host:owner/repo.git or https://host/owner/repo.git
uns::norm_repo() {
  local u="${1%/}"
  u="${u%.git}"
  u="${u#git@}"; u="${u#https://}"; u="${u#http://}"; u="${u#ssh://}"
  u="${u//://}"
  awk -F/ '{ if (NF>=2) print tolower($(NF-1) "/" $NF) }' <<< "$u"
}

# uns::remove_link <path> - delete it only when it is a symlink named upskill pointing at SKILL_DIR
uns::remove_link() {
  local p="$1" target
  if [[ ! -e "$p" && ! -L "$p" ]]; then
    echo "  absent   $p"
    return 0
  fi
  if [[ ! -L "$p" ]]; then
    echo "  REFUSED  $p is a real folder, not a link - left alone" >&2
    return 0
  fi
  if [[ "$(basename "$p")" != "upskill" ]]; then
    echo "  REFUSED  $p is not named upskill - left alone" >&2
    return 0
  fi
  target="$(readlink -f "$p" 2>/dev/null)"
  if [[ "$target" != "$(readlink -f "$SKILL_DIR" 2>/dev/null)" ]]; then
    echo "  REFUSED  $p points at $target, not $SKILL_DIR - left alone" >&2
    return 0
  fi
  rm -f "$p"          # on a symlink this removes the link, never the target
  echo "  removed  $p"
}

# uns::remove_install - delete ~/.claude/skills/upskill only when it is provably our clone
uns::remove_install() {
  local origin
  if [[ -L "$SKILL_DIR" ]]; then
    # a development link to someone's own checkout - remove the link, never their work
    rm -f "$SKILL_DIR"
    echo "  removed  $SKILL_DIR (was a development link)"
    return 0
  fi
  if [[ ! -d "$SKILL_DIR" ]]; then
    echo "  absent   $SKILL_DIR"
    return 0
  fi
  if [[ "$(basename "$SKILL_DIR")" != "upskill" || "$(dirname "$SKILL_DIR")" != "$HOME/.claude/skills" ]]; then
    echo "  REFUSED  $SKILL_DIR is not where upskill installs - left alone" >&2
    return 0
  fi
  if [[ ! -d "$SKILL_DIR/.git" ]]; then
    echo "  REFUSED  $SKILL_DIR is not a git clone - left alone" >&2
    echo "           delete it yourself if you are sure it is upskill" >&2
    return 0
  fi
  origin="$(git -c safe.directory='*' -C "$SKILL_DIR" remote get-url origin 2>/dev/null)"
  if [[ "$(uns::norm_repo "$origin")" != "$(uns::norm_repo "$CORE_REPO")" ]]; then
    echo "  REFUSED  $SKILL_DIR is a clone of '$origin', not $CORE_REPO - left alone" >&2
    return 0
  fi
  rm -rf "$SKILL_DIR"
  echo "  removed  $SKILL_DIR"
}

uns::run() {
  local p
  echo "-- other agents:"
  for p in "${AGENT_LINKS[@]}"; do uns::remove_link "$p"; done
  echo
  echo "-- the skill:"
  uns::remove_install
}

uns::report() {
  echo
  echo "== done =="
  [[ -n "$ROOT" ]] && echo "  your skills are untouched at: $ROOT"
  echo "  re-install by running upskill__install.sh again"
}

uns::find_root
uns::run
uns::report
