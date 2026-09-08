---
name: upskill
description: Share your skills, receive skills from members in an address book, manage address book with team members.
---

# upskill

Invoked when the user says "use upskill ...", "/upskill", or asks what upskill can do.

## Run it

Every action goes through one launcher, which resolves short names and self-updates on prod. Pick
the shell once, from the OS you are on - never probe, never run the other variant:

| You are on | Run |
|---|---|
| mac / linux / WSL | `bash <this-skill>/scripts/upskill__run.sh <action> [args]` |
| native Windows | `powershell -NoProfile -ExecutionPolicy Bypass -File <this-skill>\scripts\upskill__run.ps1 <action> [args]` |

Written `<upskill> <action>` below. Never run an action script directly, never edit one, never run
git yourself - a failing script is reported and you stop. If a needed name is missing (member,
skill, folder), ask for it - never guess.

## Route

Match the user's intent to a row - they speak naturally ("share my xxx skill", "add ming's
say_hello skill") or pick a number from the menu just shown; both land on the same row.

| They say | Do |
|---|---|
| `/upskill`, "menu", "help", or an intent too vague to route | `<upskill> menu` - print its stdout verbatim, then stop and wait for their pick |
| "show \<member\>'s skills" | read `actions/action__receive_skills/action__receive_skills.md` - show flow |
| "add \<member\>'s \<skill\> \[to ...\]" | read `actions/action__receive_skills/action__receive_skills.md` - add flow |
| "share my \<skill\>" | read `actions/action__provide_skills/action__provide_skills.md` - share flow |
| "remove my \<skill\>" | read `actions/action__provide_skills/action__provide_skills.md` - remove flow |
| "import contacts" | read `actions/action__manage_address_book/action__import_contacts.md` |
| "add contacts to my address book" | read `actions/action__manage_address_book/action__add_contacts.md` |
| "create an address book" | read `actions/action__manage_address_book/action__create_address_book.md` |
| a number after a list was shown | the nth of that list - pass the number to the flow that printed it |

Paths are relative to `<this-skill>`.

## Output

An action's stdout IS the reply. Print it verbatim - no heading, no "here is", no reformatting, no
commentary before or after. After the menu, stop and wait for the user's selection.

> REQUIRES `bypass permission` or `full access` - this skill operates on external folders
