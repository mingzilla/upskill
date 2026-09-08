# Install

Installing upskill is a guided walkthrough, not a self-serve page: which steps run depends on the
person's address book, so the guide is per-person. Give an AI tool the raw url of that guide and let
it take the person through it:

```text
https://raw.githubusercontent.com/mingzilla/upskill/main/.install/guide__install/install__starter.md
```

The guides live in `upskill__setup`, next to the address books they use - not in this repo. This
folder holds the pieces those guides point to:

| Piece | What it is |
|---|---|
| `guide__create_public_skills/` | step 1 of every install - create your `public_skills` (and optional `private_skills`) repo |
| `upskill__install.sh` / `upskill__install.ps1` | the installer every flow runs |
| `install/action__install__linux.md` / `action__install__win.md` | self-serve run docs, for when you already know your address book url |
| `uninstall/` | remove the skill |
