---
name: action__install__win.md
usage: drop the url of this file to your AI harness
---

## Install

Windows PowerShell (no admin, no python needed):

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/mingzilla/upskill/main/upskill__install.ps1 | iex"
```

It clones the workspace to `%USERPROFILE%\.upskill__workspace` and installs the global `upskill`
skill at `%USERPROFILE%\.claude\skills` (every Claude Code session).

## Further Info

The installer asks two things and does the rest:

| Prompt                         | Meaning                                                                              |
|--------------------------------|--------------------------------------------------------------------------------------|
| Team address book (git url or path) | the git url of your team's address book, e.g. `https://github.com/mingzilla/upskill__address_book__design.git` - there is **no default**, you must give one |
| Your upskill user name         | the name you are listed under in that address book (the installer lists the members it finds) |

For an unattended run, pass the answers instead:

```powershell
powershell -ExecutionPolicy Bypass -File upskill__install.ps1 -User myles -AddressBook https://github.com/mingzilla/upskill__address_book__design.git
```

(The workspace stays under your profile; pass `-Dir <folder>` to place it elsewhere and
`-SkipGlobal` to skip the global Claude Code skill copy.)

> Requires [Git for Windows](https://git-scm.com/downloads/win) and a github login that can read
> the team's repos - the installer clones the address book and each member's sharing repo
> (`upskill` itself is public; those may stay private).

Then open Claude in `%USERPROFILE%\.upskill__workspace` and say `use upskill to ...`.
