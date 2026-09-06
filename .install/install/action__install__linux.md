---
name: action__install__linux.md
usage: drop the url of this file to your AI harness
---

## Before you install

Create your skill repos first - see `guide__create_public_skills/README.md`. You need a public
`public_skills` repo; a private `private_skills` is optional and cloned only if it exists.

Your name must already be in the address book you install with, because your entry is what tells
upskill where to publish your skills.

## Install

Linux / WSL / macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/mingzilla/upskill/prod/.install/upskill__install.sh \
  | UP_SKILL_ADDRESS_BOOK=<raw url of your address book json> bash
```

It asks two things and does the rest:

| Prompt | Meaning |
|---|---|
| Your name | the name you are listed under in that address book - it prints the names it found |
| Where should upskill__skills_lib live | the folder holding your repos, sandbox and address book; pick an offered path or type one |

For an unattended run, pass them instead:

```bash
bash upskill__install.sh --user <name> --root <dir> --address-book <url>
```

## What you get

```text
upskill__skills_lib/
├── private_files/          your keys and anything that must never be published (git-ignored)
├── private_skills/         your private skills repo, when you have one
├── public_skills/          the repo you share from
├── upskill/                the skill itself, linked into ~/.claude/skills
├── upskill__address_book/  your address book, and a copy of each member's repo
└── upskill__sandbox/       a scratch project to try other people's skills in
```

Re-running is safe: existing folders and clones are kept, only the config and the link are rewritten.

> Requires `git`, `python3` and `curl`.

Then say `use upskill` in Claude Code or Codex.
