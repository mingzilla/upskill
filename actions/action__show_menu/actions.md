# action__show_menu

Print the `/upskill` home screen (address books + the four options). Read-only - nothing else.

Run this action's script, then print its stdout **verbatim as the whole reply** - no bullet point,
no heading, no added summary before or after. The script's output already ends with the options.

`<upskill> menu`

`<upskill>` is the launcher from SKILL.md step 0 - it fetches the current version before running.
Do not run the scripts directly, and do not edit them.

`<this-skill>` is the folder holding the upskill SKILL.md. Run from the workspace, or with
`UP_SKILL_WORKSPACE` set to it.
