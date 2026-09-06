---
name: action__technical_diagnose.md
usage: drop the url of this file to your AI harness
---

# Technical diagnose - how an upskill machine is built, and how to check it

Use this when someone says upskill does not work. Verify each layer top to bottom and stop at the
first failed check.

## How a machine is set up

Two separate places. The skill is **not** inside the user's folder.

| Piece | Linux / macOS / WSL | Windows |
|---|---|---|
| The install (a git clone) | `~/.claude/skills/upskill` | `%USERPROFILE%\.claude\skills\upskill` |
| Other agents | `~/.codex/skills/upskill`, `~/.agent/skills/upskill` - symlinks to the above | same paths - **junctions** to the above |
| Config (git-ignored) | `<install>/upskill__user_config.json` | same |
| The user's folder | `<skills_lib_root>` - named in the config | same |
| Address book + member clones | `<root>/upskill__address_book/` | same |
| The repo they publish to | `<root>/public_skills` | same |

Config contents:

```json
{ "skills_lib_root": "<abs path>", "address_book": "./upskill__address_book/address_book.json" }
```

Prerequisites:

| OS | Needs |
|---|---|
| Linux / WSL / macOS | `git`, `python3`, `curl` |
| Windows | Git for Windows only - **no python** |

## Checklist

| # | Check | Command | Expected |
|---|---|---|---|
| 1 | The skill is installed | `ls -l ~/.claude/skills/upskill` | a folder with `SKILL.md`, or a symlink to a checkout |
| 2 | It is a clone that can update itself | `git -C ~/.claude/skills/upskill remote get-url origin` | ends in `mingzilla/upskill` |
| 3 | Which branch | `git -C ~/.claude/skills/upskill rev-parse --abbrev-ref HEAD` | `prod` for a customer. Any other branch **disables auto-update by design** |
| 4 | Config exists | `cat ~/.claude/skills/upskill/upskill__user_config.json` | the two keys above |
| 5 | The root exists | `ls <skills_lib_root>` | `private_files public_skills upskill__address_book upskill__sandbox` |
| 6 | The address book is there | `ls <root>/upskill__address_book/*.json` | at least one book |
| 7 | Sharing works | `git -C <root>/public_skills remote get-url origin` | their own repo - this is their identity, there is no name in the config |
| 8 | Agent links resolve | `readlink ~/.codex/skills/upskill` | the `.claude` path |
| 9 | End to end | `<upskill> menu` | the home screen, instantly and with no network |

## Symptoms

| Symptom | Cause | Fix |
|---|---|---|
| "not configured - ... is missing" | installed but never configured | run the installer |
| "skills_lib_root does not exist" | the folder was moved or deleted | re-run the installer, or edit the path in the config |
| Menu is slow | should be impossible - it reads only local json | check for a network mount on the root |
| Updates never arrive | not on `prod` (check 3), or the working tree is dirty | `git -C <install> status`; on prod the launcher does `reset --hard origin/prod && clean -fd` |
| Share fails on push | no github write access to `public_skills` | check credentials; the receive side needs none |
| `private_skills` missing after install | it is optional, and never cloned interactively | clone it by hand, or ignore it |
| Windows: agent link missing | the filesystem has no reparse points | the installer falls back to a copy and says so; re-run it to update that copy |
| Windows: "cannot create symlink" | something used `mklink /D` | must be `mklink /J` - a junction needs no admin rights |
