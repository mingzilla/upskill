# action__provide_skills

Share one of your skills so teammates can receive it (menu option 4, "share my <skill>").

Resolve the `<skill>`:
- a folder path that contains `SKILL.md`, or
- a skill name under the current project's `.claude/skills`.

Ask the user which skill if it is unclear, and for an optional short message. Then run - **do not
improvise git**:

`<upskill> share "<skill>" "<message>"`

`<upskill>` is the launcher from SKILL.md step 0 - it fetches the current version before running.
Do not run the scripts directly, and do not edit them.

`<this-skill>` is the folder holding the upskill SKILL.md. Run from the workspace, or with
`UP_SKILL_WORKSPACE` set to it.

If the script reports a missing skills repo, tell the user to run the installer first. Report the
result in one line.

### remove a shared skill (menu option 4 - only your own)

Remove one of YOUR shared skills from your sharing repo. Only your own items - the scripts always
act on your own repo.

- show your list: `<upskill> remove` (numbered; reply e.g. "remove 2")
- remove one: `<upskill> remove "<skill-name>"` (or the number from the list)

Print the script's stdout verbatim.

### secret scan (automatic - not a menu option)

Share refuses to publish a credential. The scan runs twice on every share: once on the folder
before anything is copied, and once on the whole skills repo before the commit (because `add -A`
stages everything in the working tree, not just the new skill).

Run it by hand at any time:

`<upskill> scan "<path>"`

Exit `0` clean, `1` findings. On findings, print the script's stdout verbatim and **stop** - do not
offer to remove the secret, edit the file, or retry with the scan skipped. The user decides.

A credential that reaches a public repo stays in git history after the file is deleted, so a hit
means: move it out (`private_files`), replace it with a placeholder, and rotate it if it was
already pushed.
