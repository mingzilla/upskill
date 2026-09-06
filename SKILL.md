---
name: upskill
description: Share your skills, receive skills from members in an address book, manage address book with team members.
---

# upskill

An on-demand menu. When the user invokes upskill (they say "use upskill ...", "/upskill", or ask what
upskill can do):

0. **Pick the shell once, from the OS you are already on. Do not probe for it.** Every script below
   ships as a `.sh` and a `.ps1` doing the same job - run only the one for your OS:

   | You are on | Run scripts as |
      |---|---|
   | native Windows | `powershell -NoProfile -ExecutionPolicy Bypass -File <script>.ps1 <args>` |
   | mac / linux / WSL | `bash <script>.sh <args>` |

   Below, `<run>` means that command form and `<this-skill>` is the folder holding this SKILL.md.
   Every action goes through the launcher, which fetches the current version before running:

   `<run> <this-skill>/scripts/upskill__run <action> [args]`

   written `<upskill> <action>` from here on.
   Do not check whether bash, python or git exists. Do not run the other variant "to see" - on
   Windows the `.sh` fails, and that is expected, not a problem to solve. If a script fails: print
   its error and stop. Never edit a script in this skill, and never copy the skill elsewhere to
   work around a failure.

1. Run the menu:

   `<upskill> menu`

2. Print the script's stdout **verbatim as the whole reply**. Add nothing: no bullet point, no
   heading, no "Here is", no re-stating the address book, no "Which option?". Do not wrap it in a
   markdown table, code fence, or reformat it - the printed text IS the reply.

3. Stop and wait. The user's next message is their selection. Route it exactly (do not re-run git
   yourself; do not guess a script path - use these):

   | Pick / phrase | Do |
      |---|---|
   | menu, help, repeat | run the show-menu script again and print it verbatim (step 1-2) |
   | 1 / "show <member>'s skills" | run `<upskill> list <member>` (ask which member if none named) and print its stdout verbatim |
   | 2 / "add <member>'s <skill>" | read `<this-skill>/actions/action__receive_skills/action__receive_skills.md` and follow its add flow (`--project`) |
   | 3 / "share my <skill>" | read `<this-skill>/actions/action__provide_skills/action__provide_skills.md` and follow it |
   | 4 / "remove my <skill>" | read `<this-skill>/actions/action__provide_skills/action__provide_skills.md` and follow its remove flow (only your own) |
   | 5 / "add or change address book" | read `<this-skill>/actions/action__manage_address_book/actions.md` and follow it |
   | "install <github-url>" | read `<this-skill>/actions/action__receive_skills/action__receive_skills.md` and follow its install flow |
   | a number from a shown list (e.g. "Add 1 ...") | resolve the number to the skill name by re-running the list script, then follow the add flow |

4. Print every action's script output **verbatim** the same way - no extra commentary, no tables.
