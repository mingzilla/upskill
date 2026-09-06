---
name: action__install__linux.md
usage: drop the url of this file to your AI harness
---

## Install

Linux / WSL / macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/mingzilla/upskill/main/upskill__install.sh | bash
```

## Further Info

The installer asks three things and does the rest:

| Prompt                                      | Meaning                                                                                     |
|---------------------------------------------|---------------------------------------------------------------------------------------------|
| Team address book (git url or path)         | the git url of your team's address book, e.g. `https://github.com/mingzilla/upskill__address_book__design.git` - there is **no default**, you must give one |
| Your upskill user name                      | the name you are listed under in that address book (the installer lists the members it finds) |
| Where should the upskill workspace live?    | a folder on your machine; `.upskill__workspace` is created inside it (default: your home) |

For an unattended run, pass the answers instead:

```bash
curl -fsSL https://raw.githubusercontent.com/mingzilla/upskill/main/upskill__install.sh | bash -s -- --user myles --address-book https://github.com/mingzilla/upskill__address_book__design.git --home ~
```

> Requires a github login that can read the team's repos - the installer clones the address book and
> each member's sharing repo (`upskill` itself is public; those may stay private).
>
> Alternative if you keep a local copy: `git clone git@github.com:mingzilla/upskill.git && cd upskill && bash upskill__install.sh`.
