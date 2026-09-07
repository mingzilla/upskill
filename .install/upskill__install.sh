#!/bin/bash
# upskill__install.sh - build a machine's upskill__skills_lib tree and install the skill.
#
# The skill itself is NOT part of skills_lib: it is cloned straight into ~/.claude/skills/upskill,
# which is the one canonical copy on any machine. Every other agent gets a symlink to it - claude is
# the setup folder even for someone who does not use Claude - so there is never per-agent logic,
# only one link per agent.
#
# Safe to re-run: existing folders and clones are kept, only the config and the symlink are
# rewritten. Nothing is ever deleted.
#
# usage: upskill__install.sh [--address-book <url|path>] [--root <dir>] [--user <name>]
#                            [--core <url>] [--branch <name>]
#   --address-book  raw json url of an address book (or UP_SKILL_ADDRESS_BOOK)
#   --root          where upskill__skills_lib lives; prompted when omitted
#   --user          your display name in that address book; prompted when omitted
#   --skip-link     build the tree but do not touch ~/.claude/skills (for testing)
#   --skip-auth-check   do not require a github login (for testing)
set -uo pipefail

CORE_URL="https://github.com/mingzilla/upskill.git"
CORE_BRANCH="prod"
AB_SRC="${UP_SKILL_ADDRESS_BOOK:-}"
ROOT=""
ME_NAME="${UP_SKILL_USER:-}"
AB_FILE=""
ME_KEY=""
ME_REPO=""
SKIP_LINK=0
SKIP_AUTH=0

ins::usage() {
  echo "usage: upskill__install.sh [--address-book <url|path>] [--root <dir>] [--user <name>]" >&2
  exit 2
}

ins::parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --address-book) AB_SRC="${2:-}"; shift 2 ;;
      --root)         ROOT="${2:-}"; shift 2 ;;
      --user)         ME_NAME="${2:-}"; shift 2 ;;
      --core)         CORE_URL="${2:-}"; shift 2 ;;
      --branch)       CORE_BRANCH="${2:-}"; shift 2 ;;
      --skip-link)    SKIP_LINK=1; shift ;;
      --skip-auth-check) SKIP_AUTH=1; shift ;;
      -h|--help)      ins::usage ;;
      *) echo "error: unknown option: $1" >&2; ins::usage ;;
    esac
  done
}

# being on PATH is not proof: Windows ships python3 stubs that resolve and then fail to run
ins::require() {
  local tool missing=0
  for tool in git python3 curl; do
    if ! command -v "$tool" >/dev/null 2>&1 || ! "$tool" --version >/dev/null 2>&1; then
      echo "error: '$tool' is not installed, and upskill needs it" >&2
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]] || exit 1
}

# run as `curl | bash` means stdin is the script, so prompts must read the terminal directly
ins::ask() {
  local question="$1" default="${2:-}" answer="" hint=""
  [[ -n "$default" ]] && hint=" [$default]"
  if [[ -t 0 ]]; then
    read -r -p "${question}${hint}: " answer
  elif [[ -r /dev/tty ]]; then
    read -r -p "${question}${hint}: " answer < /dev/tty
  fi
  echo "${answer:-$default}"
}

ins::fetch_address_book() {
  [[ -n "$AB_SRC" ]] || AB_SRC="$(ins::ask 'Address book url')"
  if [[ -z "$AB_SRC" ]]; then
    echo "error: an address book is required (--address-book or UP_SKILL_ADDRESS_BOOK)" >&2
    exit 1
  fi
  AB_FILE="$(mktemp)"
  if [[ -f "$AB_SRC" ]]; then
    cp "$AB_SRC" "$AB_FILE"
  else
    # a github page url shows html; only the raw url returns the json
    local url
    url="$(echo "$AB_SRC" | sed -E 's|github\.com/([^/]+)/([^/]+)/(blob\|tree)/|raw.githubusercontent.com/\1/\2/|')"
    if ! curl -fsSL "$url" -o "$AB_FILE"; then
      echo "error: cannot download the address book: $url" >&2
      exit 1
    fi
  fi
  if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))["users"]' "$AB_FILE" 2>/dev/null; then
    echo "error: not an address book (no \"users\") : $AB_SRC" >&2
    exit 1
  fi
}

# your entry names your public_skills repo - without it there is nothing to share to, so stop
ins::pick_user() {
  local names
  names="$(python3 -c 'import json,sys
d = json.load(open(sys.argv[1]))
print(" ".join(sorted(m.get("name", k) for k, m in d["users"].items())))' "$AB_FILE")"
  [[ -n "$ME_NAME" ]] || ME_NAME="$(ins::ask "Your name - this book lists: $names")"
  read -r ME_KEY ME_REPO < <(python3 -c 'import json,sys
d = json.load(open(sys.argv[1]))
want = sys.argv[2].strip().lower()
hits = [(k, m) for k, m in d["users"].items() if m.get("name", k).lower() == want or k.lower() == want]
if len(hits) == 1:
    print(hits[0][0], hits[0][1].get("repo", ""))
elif len(hits) > 1:
    print("AMBIGUOUS", " ".join(k for k, _ in hits))' "$AB_FILE" "$ME_NAME")
  if [[ "$ME_KEY" == "AMBIGUOUS" ]]; then
    echo "error: '$ME_NAME' matches more than one entry: $ME_REPO" >&2
    echo "  re-run with --user <one of those keys>" >&2
    exit 1
  fi
  if [[ -z "$ME_KEY" || -z "$ME_REPO" ]]; then
    echo "error: '$ME_NAME' is not in this address book, so your public_skills repo is unknown" >&2
    echo "  the book lists: $names" >&2
    echo "  create your repos first - see .install/guide__create_public_skills/README.md" >&2
    exit 1
  fi
}

# Being logged in is not optional. Cloning private_skills needs it, and sharing - the whole point -
# pushes to github. Without it the install "succeeds" and every later share fails at the push, which
# is a far worse place to discover it. Checked before anything is created.
ins::check_github_auth() {
  [[ "$SKIP_AUTH" -eq 0 ]] || return 0
  # gh is the clearest signal and gives the exact command to fix it
  if command -v gh >/dev/null 2>&1; then
    gh auth status --hostname github.com >/dev/null 2>&1 && return 0
  else
    # no gh: accept a credential helper that already holds a github password
    if GIT_TERMINAL_PROMPT=0 printf 'protocol=https\nhost=github.com\n\n' \
         | git -c credential.interactive=false credential fill 2>/dev/null | grep -q '^password='; then
      return 0
    fi
  fi
  echo "error: you are not logged in to github" >&2
  echo "  upskill clones your private_skills and pushes every skill you share, so a login is" >&2
  echo "  required now rather than at the first failed share." >&2
  echo >&2
  echo "  run this, then run the installer again:" >&2
  echo "    gh auth login --hostname github.com --git-protocol https" >&2
  echo >&2
  echo "  (no gh? install it from https://cli.github.com, or configure a git credential helper)" >&2
  exit 1
}

# check every remote before a single folder is made: a bad url must leave the machine untouched
ins::preflight() {
  if ! git ls-remote --heads "$ME_REPO" >/dev/null 2>&1; then
    echo "error: cannot reach your skills repo: $ME_REPO" >&2
    echo "  create it first - see .install/guide__create_public_skills/README.md" >&2
    exit 1
  fi
  local heads
  heads="$(git ls-remote --heads "$CORE_URL" "$CORE_BRANCH" 2>/dev/null)"
  if [[ -z "$heads" ]]; then
    echo "error: branch '$CORE_BRANCH' not found in $CORE_URL" >&2
    exit 1
  fi
}

ins::pick_root() {
  [[ -n "$ROOT" ]] && return 0
  local suggested="$HOME/code/upskill__skills_lib"
  echo
  echo "Where should upskill__skills_lib live? Your skills and repos are kept there."
  echo "  1. $suggested"
  case "$(uname -r 2>/dev/null)" in
    *[Mm]icrosoft*) echo "  2. /mnt/c/code/upskill__skills_lib   (C: drive)"
                    echo "  3. /mnt/d/code/upskill__skills_lib   (D: drive)"
                    echo "  4. /mnt/e/code/upskill__skills_lib   (E: drive)" ;;
  esac
  echo "  or type a path"
  local answer
  answer="$(ins::ask 'Choice' '1')"
  case "$answer" in
    1) ROOT="$suggested" ;;
    2) ROOT="/mnt/c/code/upskill__skills_lib" ;;
    3) ROOT="/mnt/d/code/upskill__skills_lib" ;;
    4) ROOT="/mnt/e/code/upskill__skills_lib" ;;
    *) ROOT="${answer/#\~/$HOME}" ;;
  esac
  [[ -n "$ROOT" ]] || { echo "error: no root chosen" >&2; exit 1; }
}

ins::make_tree() {
  mkdir -p "$ROOT/private_files" "$ROOT/upskill__address_book" "$ROOT/upskill__sandbox/.claude/skills"
  # keys live here and must never reach a repo, even if someone runs git init at the root
  if ! grep -qs '^private_files/' "$ROOT/.gitignore" 2>/dev/null; then
    echo 'private_files/' >> "$ROOT/.gitignore"
  fi
}

# clone <dir> <url> <label> - keep what is already there; a re-run must never discard work
ins::clone() {
  local dir="$1" url="$2" label="$3"
  if [[ -d "$dir/.git" ]]; then
    echo "  keep   $label (already cloned)"
    return 0
  fi
  if [[ -e "$dir" ]]; then
    echo "  skip   $label - '$dir' exists but is not a git clone" >&2
    return 0
  fi
  if git ${US_CLONE_OPTS:-} clone --quiet "$url" "$dir" 2>/dev/null; then
    echo "  clone  $label"
  else
    echo "  FAILED $label ($url)" >&2
    return 1
  fi
}

ins::clone_repos() {
  echo
  echo "-- repos:"
  ins::clone "$ROOT/public_skills" "$ME_REPO" "public_skills" || exit 1
  # the guide asks for both repos at once, so try the matching private one and move on if absent.
  # private_skills is private by definition: without GIT_TERMINAL_PROMPT=0 an https clone stops and
  # waits for a username, which would hang the whole install on a repo that is optional anyway.
  local private_url="${ME_REPO%public_skills.git}private_skills.git"
  if [[ "$private_url" != "$ME_REPO" ]]; then
    # never ask anybody anything: credential.interactive=false stops a credential helper opening a
    # window (GIT_TERMINAL_PROMPT only silences the terminal), while stored credentials still work
    if ! GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never \
         US_CLONE_OPTS="-c credential.interactive=false" \
         ins::clone "$ROOT/private_skills" "$private_url" "private_skills"; then
      rm -rf "$ROOT/private_skills"
      echo "  note: private_skills was not cloned (not created yet, or it needs a login) - nothing else is affected" >&2
    fi
  fi
}


SKILL_DIR="$HOME/.claude/skills/upskill"
IS_DEV_LINK=0

# ~/.claude/skills/upskill is the install. A symlink there is someone developing upskill against
# their own checkout - never disturb it.
ins::install_skill() {
  echo
  echo "-- skill:"
  if [[ -L "$SKILL_DIR" ]]; then
    IS_DEV_LINK=1
    echo "  keep   $SKILL_DIR -> $(readlink "$SKILL_DIR") (a development link)"
    return 0
  fi
  if [[ -d "$SKILL_DIR/.git" ]]; then
    echo "  keep   $SKILL_DIR (already installed)"
    return 0
  fi
  if [[ -e "$SKILL_DIR" ]]; then
    echo "error: $SKILL_DIR exists but is not a git clone" >&2
    echo "  move it aside and re-run - it would be overwritten by every update" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$SKILL_DIR")"
  git clone --quiet -b "$CORE_BRANCH" "$CORE_URL" "$SKILL_DIR" \
    || { echo "  FAILED upskill ($CORE_URL branch $CORE_BRANCH)" >&2; exit 1; }
  echo "  clone  $SKILL_DIR ($CORE_BRANCH)"
}

ins::place_address_book() {
  cp "$AB_FILE" "$ROOT/upskill__address_book/address_book.json"
}

ins::write_config() {
  # A development link points at somebody's own checkout, and its config is their working setup.
  # Writing ours into it would silently repoint their environment at this install's root - a change
  # they never asked for and would not see until something later failed.
  if [[ "$IS_DEV_LINK" -eq 1 ]]; then
    echo
    echo "-- config: kept (the skill is a development link, so its config is left alone)"
    echo "   to use this root there, set in $(readlink "$SKILL_DIR")/upskill__user_config.json:"
    echo "     \"skills_lib_root\": \"$ROOT\""
    return 0
  fi
  python3 -c 'import json,sys
cfg = {"skills_lib_root": sys.argv[1], "address_book": "./upskill__address_book/address_book.json"}
with open(sys.argv[2], "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")' "$ROOT" "$SKILL_DIR/upskill__user_config.json"
}

# Other agents read from their own folder, so each gets a link to the one real copy. Claude is the
# setup folder whether or not Claude is installed: a link costs nothing and works the day it is.
ins::link_agents() {
  local root link
  [[ "$SKIP_LINK" -eq 0 ]] || { echo; echo "-- agents: skipped (--skip-link)"; return 0; }
  echo
  echo "-- other agents:"
  for root in "$HOME/.codex/skills" "$HOME/.agent/skills"; do
    link="$root/upskill"
    if [[ -e "$link" && ! -L "$link" ]]; then
      echo "  skip   $link is a real folder, not a link - move it and re-run" >&2
      continue
    fi
    mkdir -p "$root"
    ln -sfn "$SKILL_DIR" "$link"
    echo "  link   $link"
  done
}

ins::report() {
  echo
  echo "== done =="
  echo "  you       $ME_NAME  ($ME_KEY)"
  echo "  root      $ROOT"
  echo "  skill     $SKILL_DIR"
  echo "  share to  $ME_REPO"
  echo
  echo "say: use upskill to share a skill, or get one from someone"
}

ins::parse_args "$@"
ins::require
ins::check_github_auth
ins::fetch_address_book
ins::pick_user
ins::preflight
ins::pick_root
ins::make_tree
ins::clone_repos
ins::install_skill
ins::place_address_book
ins::write_config
ins::link_agents
ins::report
