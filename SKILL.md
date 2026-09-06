---
name: upskill
description: Share your skills, receive skills from members in an address book, manage address book with team members.
---

# upskill

Invoked when the user says "use upskill ...", "/upskill", or asks what upskill can do.

## 0. Running scripts

**Pick the shell once, from the OS you are already on. Do not probe for it.** Every script ships as
a `.sh` and a `.ps1` doing the same job - run only the one for your OS. `<this-skill>` is the folder
holding this SKILL.md:

| You are on | Run |
|---|---|
| mac / linux / WSL | `bash <this-skill>/scripts/upskill__run.sh <action> [args]` |
| native Windows | `powershell -NoProfile -ExecutionPolicy Bypass -File <this-skill>\scripts\upskill__run.ps1 <action> [args]` |

written `<upskill> <action>` below.

| Rule | |
|---|---|
| Do not probe | Never test whether bash, python or git exists - the script says so if not |
| Do not run the other variant "to see" | On Windows the `.sh` fails, and that is expected, not a problem to solve |
| Do not improvise git | Every git operation belongs to a script |
| Do not edit scripts | A failing script is reported to the user, not patched |
| On failure | Print the error and stop |

## 1. Show the menu

Run `<upskill> menu`, then print its stdout **verbatim as the whole reply**: no heading, no
"Here is", no re-stating the address book, no reformatting into a table. The printed text IS the
reply. Then stop and wait - the user's next message is their selection.

## 2. Route the selection

| Pick / phrase | Do |
|---|---|
| menu, help, repeat | `<upskill> menu` again |
| 1 / "show <member>'s skills" | `<upskill> list <member>` - ask which member if none named |
| 2 / "add <member>'s <skill>" | read `actions/action__receive_skills/action__receive_skills.md`, follow its add flow |
| 3 / "share my <skill>" | read `actions/action__provide_skills/action__provide_skills.md`, follow its share flow |
| 4 / "remove my <skill>" | read `actions/action__provide_skills/action__provide_skills.md`, follow its remove flow |
| 5 / "import contacts" | read `actions/action__manage_address_book/actions.md`, follow it |
| a number from a shown list | re-run the same list to resolve the number to a name, then continue that flow |

Paths are relative to `<this-skill>`.

## 3. Print every result verbatim

Same rule as the menu: an action's stdout is the reply. Add no commentary before or after.
