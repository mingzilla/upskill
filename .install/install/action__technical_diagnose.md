---
name: action__technical_diagnose.md
usage: drop the url of this file to your AI harness
---

# Technical diagnose - how an upskill machine is built and how to check it

This is the technical reference for a machine that has (or should have) upskill installed. Use it
when a user says upskill does not work - verify each layer below, top to bottom, and stop at the
first failed check.

## How a machine is set up

The installer builds everything in one hidden folder and copies the two skills to the global
Claude Code skills dir:

| Piece | Location (Linux/macOS/WSL) | Location (Windows) |
|---|---|---|
| Workspace root | `~/.upskill__workspace` | `%USERPROFILE%\.upskill__workspace` |
| User config | `<ws>/upskill__user-config.json` | same |
| Address book clone | `<ws>/address_books/<team>/upskill__address_book__<team>/` | same |
| Member sharing repos | `<ws>/address_books/<team>/upskill__skills_repo__<member>/` | same |
| The upskill product repo | `<ws>/upskill` | same |
| Global skill | `~/.claude/skills/upskill` (legacy `upskill__sharing__*` / `upskill__action__*` are swept) | `%USERPROFILE%\.claude\skills\upskill` |

Config contents (`upskill__user-config.json`):

```json
{ "user": "<name>", "team": "team__<team>", "address_book": "./address_books/<team>/upskill__address_book__<team>" }
```

Prerequisites by OS:

| OS | Needs |
|---|---|
| Linux / WSL | `git`, `python3` |
| macOS | `git`, `python3` (install Python from python.org; git via Xcode Command Line Tools) |
| Windows | [Git for Windows](https://git-scm.com/downloads/win) - no python needed |

## Diagnosis checklist

| # | Check | Healthy if | If not |
|---|---|---|---|
| 1 | Prerequisites | `git` (and `python3` on unix) on PATH | install the missing tool, then re-run the installer |
| 2 | Workspace exists | `~/.upskill__workspace` is a folder | machine was never installed - hand over the matching install action (`action__install__linux.md` / `action__install__win.md`) |
| 3 | Config | `upskill__user-config.json` has `user`, `team`, `address_book` | installer was interrupted - re-run it |
| 4 | Address book | `<address_book>/address_book.json` exists and lists the user | re-run the installer (it clones the address book) |
| 5 | Global skill | `~/.claude/skills/upskill` exists | re-run the installer (it installs the global skill unless run with `--skip-global`) |
| 6 | Functional | run `bash ~/.claude/skills/upskill/actions/action__receive_skills/scripts/upskill__list.sh` inside the workspace | it prints the team's shared skills - good |

## Error messages and what they mean

| Error | Meaning / fix |
|---|---|
| `required tool not found: git` (or `python3`) | prereq missing - install it (see table above) |
| `no .upskill__workspace found from ...` | not run inside the workspace and no workspace under the profile - run inside `~/.upskill__workspace` or set `UP_SKILL_WORKSPACE` |
| `address book not found at ... (run the installer first)` | workspace is incomplete - re-run the installer |
| `'<user>' is not in the address book` | the user name in the config does not match the address book - re-run the installer with the correct `--user` / `-User` |
| `your skills repo is missing: ... (run the installer first)` | the member's sharing repo was not cloned - re-run the installer |

Most failures are a stale or partial workspace - the installer rebuilds it from scratch, so re-running
it is the fix for almost everything. It never touches your github repos or projects.
