#!/usr/bin/env bash
# upskill__share.sh - copy a local skill folder into my skills repo and push it.
# usage: upskill__share.sh <skill-folder|skill-name> [message]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/upskill__lib.sh
source "$SCRIPT_DIR/../../../scripts/upskill__lib.sh"

us::init "${UP_SKILL_WORKSPACE:-$PWD}"

src="${1:-}"
msg="${2:-}"
if [[ -z "$src" ]]; then
  echo "usage: upskill__share.sh <skill-folder|skill-name> [message]" >&2
  exit 1
fi

# accept a folder path, or a bare name inside $PWD/.claude/skills
if [[ ! -d "$src" ]]; then
  if [[ -d "$PWD/.claude/skills/$src" ]]; then
    src="$PWD/.claude/skills/$src"
  else
    echo "error: skill not found: '$src'" >&2
    echo "  give a folder path, or a skill name inside $PWD/.claude/skills" >&2
    exit 1
  fi
fi
# a skill only reaches the team if it will actually load for them
us::validate_skill "$src" || exit 1

name="$(basename "$src")"
us::safe_name "$name"

if [[ ! -d "$US_ME_DIR/.git" ]]; then
  echo "error: your skills repo is missing: $US_ME_DIR (run install.sh first)" >&2
  exit 1
fi

dest="$US_ME_DIR/$name"
rm -rf "$dest"
cp -R "$src" "$dest"

git -C "$US_ME_DIR" add -A
if git -C "$US_ME_DIR" diff --cached --quiet; then
  echo "no change - '$name' is already shared" >&2
  exit 0
fi

commit="share $name${msg:+: $msg}"
git -C "$US_ME_DIR" commit -m "$commit"
git -C "$US_ME_DIR" branch -M main
git -C "$US_ME_DIR" push -u origin main

echo "shared '$name' to $(git -C "$US_ME_DIR" remote get-url origin)"
