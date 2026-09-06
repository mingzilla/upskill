---
name: action__install__win.md
usage: drop the url of this file to your AI harness
---

## Before you install

Create your skill repos first - see `guide__create_public_skills/README.md`. You need a public
`public_skills` repo; a private `private_skills` is optional and cloned only if it exists and your
git credentials are already stored.

Your name must already be in the address book you install with, because your entry is what tells
upskill where to publish your skills.

## Install

Windows PowerShell - **no admin needed**:

```powershell
powershell -ExecutionPolicy Bypass -c "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/mingzilla/upskill/prod/.install/upskill__install.ps1))) -AddressBook '<raw url of your address book json>'"
```

It asks two things and does the rest:

| Prompt | Meaning |
|---|---|
| Your name | the name you are listed under in that address book - it prints the names it found |
| Where should upskill__skills_lib live | the folder holding your repos, sandbox and address book; pick an offered drive or type a path |

Unattended:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File upskill__install.ps1 -User <name> -Root <dir> -AddressBook <url>
```

## What you get

Your folder holds **your** things only - the skill itself is not in it:

```text
upskill__skills_lib\
├── private_files\          your keys and anything that must never be published (git-ignored)
├── private_skills\         your private skills repo, when you have one
├── public_skills\          the repo you share from
├── upskill__address_book\  your address book, and a copy of each member's repo
└── upskill__sandbox\       a scratch project to try other people's skills in
```

upskill installs itself at `%USERPROFILE%\.claude\skills\upskill` and every other agent points at
that one copy:

```text
%USERPROFILE%\.claude\skills\upskill    the install (a git clone - it updates itself, never edit it)
%USERPROFILE%\.codex\skills\upskill  ->  junction to the above
%USERPROFILE%\.agent\skills\upskill  ->  junction to the above
```

Claude's folder is used even if you do not have Claude: one copy, one link per agent, nothing to
keep in step. The links are **junctions**, which a standard Windows user can create without admin
rights - unlike symlinks, which need it.

Re-running is safe: existing folders and clones are kept, only the config and the links are
rewritten. A `%USERPROFILE%\.claude\skills\upskill` that is a junction is treated as somebody's own
checkout and left alone.

> Requires [Git for Windows](https://git-scm.com/downloads/win). Python is **not** needed.

Then say `use upskill` in Claude Code or Codex.
