#!/bin/bash
# upskill__show_menu.sh - print the upskill home screen. Read-only, and deliberately offline:
# the menu is the most-used command, so it never fetches a repo. Skill counts would mean pulling
# every member - on a large address book that is a long wait before anything is shown.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/upskill__lib.sh"

BOOK_NAME=""
BOOK_COUNT=0
MEMBER_LINE=""
ACTIVE_MARK=""

# address_book__sandbox.json -> sandbox; address_book.json -> default
menu::read_book() {
  local base
  base="$(basename "$US_AB_JSON" .json)"
  case "$base" in
    address_book__*) BOOK_NAME="${base#address_book__}" ;;
    *)               BOOK_NAME="default" ;;
  esac
  MEMBER_LINE="$(us::members | cut -f2 | paste -sd, - | sed 's/,/, /g')"
  BOOK_COUNT="$(us::members | grep -c .)"
  # "active" only means something when there is another book to switch to
  local books
  books="$(find "$US_POOL" -maxdepth 1 -name 'address_book*.json' 2>/dev/null | grep -c .)"
  [[ "$books" -gt 1 ]] && ACTIVE_MARK=" - active"
}

menu::print() {
  cat <<TXT
You can share or receive skills with members from the active address book:

Address Book: $BOOK_NAME ($BOOK_COUNT members)$ACTIVE_MARK
- $MEMBER_LINE

---

What would you like to do?
1. Show a member's skills        - e.g. "show Andy's skills"
2. Add a member's skill          - e.g. "add Andy's say_hello skill"
3. Share your skill              - e.g. "share my xxx skill"
4. Remove a shared skill         - e.g. "remove my xxx skill"

Manage address books:
5. Import contacts
TXT
}

us::init
menu::read_book
menu::print
