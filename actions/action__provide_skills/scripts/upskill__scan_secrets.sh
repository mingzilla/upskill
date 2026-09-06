#!/usr/bin/env bash
# upskill__scan_secrets.sh - refuse to publish anything carrying a credential.
#
# Deliberately standalone: it sources no library and reads no config, so the same file works from
# the share flow, from a git pre-commit hook, and before upskill is installed at all.
#
# usage: upskill__scan_secrets.sh [--quiet] <path> [<path>...]
# exit: 0 clean | 1 findings (caller must stop) | 2 usage error
set -uo pipefail   # not -e: grep exits 1 on "no match", which is the good case

quiet=0
paths=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet) quiet=1; shift ;;
    -h|--help) echo "usage: upskill__scan_secrets.sh [--quiet] <path> [<path>...]"; exit 0 ;;
    *) paths+=("$1"); shift ;;
  esac
done
if [[ "${#paths[@]}" -eq 0 ]]; then
  echo "usage: upskill__scan_secrets.sh [--quiet] <path> [<path>...]" >&2
  exit 2
fi
for p in "${paths[@]}"; do
  [[ -e "$p" ]] || { echo "error: no such path: $p" >&2; exit 2; }
done

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# --- 1. filenames that are credentials whatever is inside them ---------------------------------
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  printf '%s\t-\t%s\t%s\n' "$f" "$(basename "$f")" "credential file"
done < <(find "${paths[@]}" -type f \
  \( -name '.env' -o -name '.env.*' -o -name '.envrc' \
  -o -name 'id_rsa' -o -name 'id_dsa' -o -name 'id_ecdsa' -o -name 'id_ed25519' \
  -o -name '*.pem' -o -name '*.key' -o -name '*.p12' -o -name '*.pfx' -o -name '*.jks' \
  -o -name '*.keystore' -o -name 'credentials.json' -o -name '*service-account*.json' \
  -o -name '.npmrc' -o -name '.pypirc' -o -name '.netrc' -o -name '.htpasswd' \) \
  -not -path '*/.git/*' 2>/dev/null) >> "$tmp"

# --- 2. content patterns -------------------------------------------------------------------------
# Ordered most-specific first: a token reported by two rules keeps the first rule's label.
# -I skips binaries (portable; --binary-files=without-match is GNU-only).
scan() {
  local label="$1" pat="$2" ci="${3:-}"
  local -a opts=(-rInoE --exclude-dir=.git)
  [[ -n "$ci" ]] && opts+=(-i)
  grep "${opts[@]}" -e "$pat" "${paths[@]}" 2>/dev/null | while IFS= read -r hit; do
    local file line token
    file="${hit%%:*}"; hit="${hit#*:}"
    line="${hit%%:*}"; token="${hit#*:}"
    printf '%s\t%s\t%s\t%s\n' "$file" "$line" "$token" "$label"
  done
}

{
  scan "Anthropic API key"   'sk-ant-[A-Za-z0-9_-]{16,}'
  scan "OpenAI API key"      'sk-(proj-)?[A-Za-z0-9_-]{20,}'
  scan "GitHub token"        'gh[pousr]_[A-Za-z0-9]{16,}'
  scan "GitHub token"        'github_pat_[A-Za-z0-9_]{20,}'
  scan "AWS access key"      '(AKIA|ASIA)[0-9A-Z]{16}'
  scan "Google API key"      'AIza[0-9A-Za-z_-]{30,}'
  scan "Slack token"         'xox[baprs]-[0-9A-Za-z-]{10,}'
  scan "private key block"   '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  scan "hardcoded secret"    '(api[_-]?key|secret|token|password|passwd)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{16,}["'"'"']' ci
} >> "$tmp"

# --- 3. drop obvious placeholders ---------------------------------------------------------------
# A doc that shows people what a key looks like must not block the share.
is_placeholder() {
  local v="$1"
  case "${v,,}" in
    *xxx*|*your_*|*your-*|*example*|*placeholder*|*dummy*|*redacted*|*changeme*|*sample*|*'<'*|*'${'*|*fake*|*notreal*) return 0 ;;
  esac
  case "$v" in
    *00000000*|*aaaaaaaa*|*AAAAAAAA*|*11111111*|*'****'*|*'....'*) return 0 ;;
  esac
  return 1
}

findings=0
report=""
while IFS=$'\t' read -r file line token label; do
  [[ -n "${file:-}" ]] || continue
  is_placeholder "$token" && continue
  # redact: never print the credential back out into a log or a terminal scrollback
  if [[ "${#token}" -gt 8 ]]; then shown="${token:0:6}***"; else shown="***"; fi
  if [[ "$line" == "-" ]]; then
    report+="  $file"$'\n'"      $label"$'\n'
  else
    report+="  $file:$line"$'\n'"      $label  ->  $shown"$'\n'
  fi
  findings=$((findings + 1))
done < <(awk -F'\t' '!seen[$1"\t"$2"\t"$3]++' "$tmp")

if [[ "$findings" -eq 0 ]]; then
  [[ "$quiet" -eq 1 ]] || echo "no secrets found"
  exit 0
fi

echo "BLOCKED: $findings possible secret(s) found" >&2
echo >&2
printf '%s' "$report" >&2
echo >&2
echo "Nothing was committed or pushed." >&2
echo "  - move the secret into your private_files folder, or replace it with a placeholder" >&2
echo "  - if this credential was ALREADY pushed, rotate it: deleting a file does not" >&2
echo "    remove it from git history" >&2
exit 1
