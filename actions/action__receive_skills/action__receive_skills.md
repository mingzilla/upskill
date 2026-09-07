# action__receive_skills

Show what a member shares, and bring one of their skills into a project.

`<upskill>` is the launcher from SKILL.md. Do not run the scripts directly, and do not edit them.

## Verbs

| User says | Run |
|---|---|
| "show ming's skills" | `<upskill> list "<member>"` |
| "add ming's say_hello skill" | `<upskill> add "<member>" "<skill>" --project <target>` |

## Show (option 1)

`<upskill> list "<member>"` prints their skills numbered. Print it verbatim, then stop.

The user's next message may be a bare number - it means the nth skill of that list. Pass the number
straight to `add`; it resolves against the same order.

## Add (option 2)

`<upskill> add "<member>" "<skill|number>" --project <target>`

| `--project` | Copies to |
|---|---|
| `sandbox` | `<skills_lib_root>/upskill__sandbox/.claude/skills/` - the default, for trying a skill out |
| `current` | this project's `.claude/skills/` |
| `<path>` | that project's `.claude/skills/` |

Add `--agent codex` when Codex is asking, so the skill lands in `.codex/skills/`.

**No target given:** run it without `--project`. It exits **2** and prints the numbered "Where would
you like to add this?" menu - show that verbatim and ask. Never guess a path.

> Adding a skill writes into another project, so it needs **bypass permission**. If it is blocked,
> say so and stop - do not retry a different folder.
