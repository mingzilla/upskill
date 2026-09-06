# action__receive_skills

Bring a member's shared skill into a machine, and see what is available.

`<upskill>` is the launcher from SKILL.md step 0 - it fetches the current version before running.
Do not run the scripts directly, and do not edit them. `<this-skill>` is the folder holding the
upskill SKILL.md; scripts live under `<this-skill>/actions/action__receive_skills/scripts/`.

## Verbs

| Verb | User says | Run |
|---|---|---|
| show skills | "show Andy's skills" | `<upskill> list "<owner>"` |
| add | "add Andy's say_hello skill" | `<upskill> add "<owner>" "<skill>" --project <scope>` |
| install | "install `<github-url>` into ..." | `<upskill> install "<url>" ["<target-dir>"]` |

### show a member's skills (menu option 2 - the wizard)

Run `<upskill> list "<owner>"` (ask which member if the user only says "show skills"). It prints
their skills numbered, then shows the pick examples - print it verbatim:

```text
ming's skills:
  1. daily_summary
  2. my_nice_skill

Example:
- Add 1 to the current project
- Add 1 - (you will be asked where to add it to)
```

The user can then reply "Add <n> ...". Resolve `<n>` to the skill name by re-running the same list,
then do the **add** flow below.

### add a skill (menu option 3 - direct)

`<upskill> add "<owner>" "<skill>" --project <scope>` where `<scope>` is one of:

| `--project` | Copies the skill to |
|---|---|
| `current` | this project's `<agent>/skills/<skill>` |
| `<path>` | that project's `<agent>/skills/<skill>` |

`<agent>` is `.claude` or `.codex`, whichever agent is asking. Skills always go into a project -
there is no user-level target. A user-level skill would load in every project whether it is wanted
or not; only upskill itself belongs there, and the installer puts it there.

**If the script reports it cannot write to the folder**, the agent is sandboxed out of it. In Codex
that is the normal state: a sandboxed command cannot write to the project's `.codex` folder. Do not
retry the same way and do not fall back to a different folder - tell the user:

> Adding a skill needs `Full access` permission. Set the permission to `Full access` (or approve the
> escalation prompt), then I will run it again.

Then run the same command again. In a normal terminal window, outside any agent, it works without
this step.

**If the user did not give a target**, run `<upskill> add "<owner>" "<skill>"` with NO `--project`.
It exits with code **2** and prints a numbered "Where to add" menu - show that verbatim and ask the
user to pick a number (1 current project / 2 another project). For 2, ask which project.
Then call again with `--project <current|<path>>`. Never guess a path.
`<owner>` must be a member the show/list output printed.

### install (no address book needed)

`<upskill> install "<url>" ["<target-dir>"]` - clones any github repo and copies its
`.claude/skills/*` (and top-level `SKILL.md` folders) into the target.

Do not improvise git. Report the result in one or two lines.
