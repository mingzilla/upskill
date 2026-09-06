#!/usr/bin/env bash
# upskill__install.sh - bring skills from a github repo into a project.
# usage: upskill__install.sh <repo-url|owner/repo> [target-project-dir]
#
# Clones the repo, copies every skill under its .claude/skills/ (and any top-level folder that
# carries a SKILL.md) into <target>/.claude/skills/. Standalone - does not need an address book.
set -euo pipefail

url="${1:-}"
target="${2:-$PWD}"

if [[ -z "$url" ]]; then
  echo "usage: upskill__install.sh <repo-url|owner/repo> [target-project-dir]" >&2
  echo "  e.g. upskill__install.sh https://github.com/mingzilla/upskill" >&2
  exit 1
fi
command -v git >/dev/null 2>&1 || { echo "error: git is required" >&2; exit 1; }

# safe_name <name> - reject empty / pathy / dot-dot names
safe_name() {
  local n="$1"
  if [[ -z "$n" || "$n" == */* || "$n" == *".."* ]]; then
    echo "error: not a valid skill name: '$n'" >&2
    return 1
  fi
}

# clone_url <raw-url> - accept the common github forms, normalise to an https clone URL
clone_url() {
  local u="$1"
  case "$u" in
    git@github.com:*) echo "https://github.com/${u#git@github.com:}" ;;
    http://*) echo "https://${u#http://}" ;;
    https://*) echo "$u" ;;
    github.com/*) echo "https://$u" ;;
    */*) echo "https://github.com/$u" ;;
    *) echo "https://github.com/$u" ;;
  esac
}

url_https="$(clone_url "$url")"
repo_name="$(basename "${url_https%%/}")"
repo_name="${repo_name%.git}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo "fetching $url_https"
git clone --quiet --depth 1 "$url_https" "$tmp/repo"

installed=0
copy_skill() {  # copy_skill <src-dir>
  local src="$1" name
  name="$(basename "$src")"
  safe_name "$name" || return 1
  local dest="$target/.claude/skills/$name"
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  cp -R "$src" "$dest"
  echo "installed '$name' -> $dest"
  installed=1
}

# 1. skills bundled as a Claude project: <repo>/.claude/skills/*
if [[ -d "$tmp/repo/.claude/skills" ]]; then
  for d in "$tmp/repo/.claude/skills"/*/; do
    [[ -e "$d" ]] || continue
    copy_skill "$d"
  done
fi

# 2. skills at the repo root: any top-level folder carrying its own SKILL.md
for d in "$tmp/repo"/*/; do
  [[ -e "$d" ]] || continue
  [[ -f "$d/SKILL.md" ]] || continue
  [[ "$(basename "$d")" == ".claude" ]] && continue
  copy_skill "$d"
done

if [[ "$installed" -eq 0 ]]; then
  echo "error: no skills found in $url_https (looked in .claude/skills/ and top-level SKILL.md folders)" >&2
  exit 1
fi
echo "done - open Claude in '$target' to use the installed skill(s)."
