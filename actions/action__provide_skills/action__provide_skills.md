# action__provide_skills

Share one of your own skills, or take one back. Both only ever touch **your** `public_skills` repo.

`<upskill>` is the launcher from SKILL.md. Do not run the scripts directly, and do not edit them.

## Share (option 3) - two steps

The user says "share my `<skill>`". They are speaking, not typing a path: the name may be
approximate, and the skill may live in this project, in `private_skills`, or anywhere else they
keep one. So find it first, then upload it.

### Step 1 - find it

`<upskill> find "<what the user said>"`

It searches this project and your repos for folders holding a `SKILL.md`, matching loosely, and
prints what it found with full paths.

| Output | Do |
|---|---|
| `Found:` + one entry | Use that path |
| `Which skill did you mean?` + several | Print the list verbatim and ask which number |
| `Closest match - is this the one?` | Print it and confirm before using it |
| `no skill found matching ...` | Say so; ask where the skill lives, then pass `--root <dir>` |

Search another location with `<upskill> find "<name>" --root "<dir>"` (repeatable).

### Step 2 - upload it

`<upskill> share "<path from step 1>" "<optional message>"`

Pass the **path**, not the name - step 1 already resolved it. Report the result in one line.

## Remove (option 4)

| User says | Run |
|---|---|
| "remove my shared skill" | `<upskill> remove` - prints your shared skills numbered; ask which |
| "remove my `<skill>`" | `<upskill> remove "<skill>"` (a number from that list also works) |

## Secret scan - automatic

Share refuses to publish a credential. It scans twice: the folder before anything is copied, and
the whole repo before the commit, because `add -A` stages everything in the working tree.

Run it by hand at any time: `<upskill> scan "<path>"` - exit `0` clean, `1` findings.

On findings, print the output verbatim and **stop**. Do not offer to delete the secret, edit the
file, or retry with the scan skipped - the user decides. A credential that was already pushed stays
in git history after the file is deleted, so it has to be rotated, not just removed.
