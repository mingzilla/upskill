---
name: upskill
description: Share your skills, receive skills from members in an address book, manage address book with team members.
---

# upskill

REQUIRES `bypass permission` or `full access` - this skill operates on external folders.

## No instruction

[RUN] the menu, picking the launcher by the shell you are on, then print its stdout verbatim and
stop - the user's next message is their pick:

| You are on | Run |
|---|---|
| mac / linux / WSL | `bash <this-skill>/scripts/upskill__run.sh menu` |
| native Windows | `powershell -NoProfile -ExecutionPolicy Bypass -File <this-skill>\scripts\upskill__run.ps1 menu` |

## Instruction given

[RUN] the matching row. `<upskill> <action>` means the launcher above for your shell; never run an
action script directly or edit one, and never run git yourself. If a needed name is missing
(member, skill, folder), ask - never guess.

| User says | Do |
|---|---|
| "show \<member\>'s skills" | read `actions/action__receive_skills/action__receive_skills.md` - show flow |
| "add \<member\>'s \<skill\> \[to ...\]" | read `actions/action__receive_skills/action__receive_skills.md` - add flow |
| "share my \<skill\>" | read `actions/action__provide_skills/action__provide_skills.md` - share flow |
| "remove my \<skill\>" | read `actions/action__provide_skills/action__provide_skills.md` - remove flow |
| "import contacts" | read `actions/action__manage_address_book/action__import_contacts.md` |
| "add contacts to my address book" | read `actions/action__manage_address_book/action__add_contacts.md` |
| "create an address book" | read `actions/action__manage_address_book/action__create_address_book.md` |
| a number after a list was shown | the nth of that list - pass it to the flow that printed it |

Paths are relative to `<this-skill>`.

An action's stdout IS the reply - print it verbatim, no commentary before or after.
