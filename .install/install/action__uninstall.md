---
name: action__uninstall.md
usage: drop the url of this file to your AI harness
---

## Uninstall

Removes upskill from this machine's agents. **Your skills_lib is never touched** - repos, sandbox,
private files and projects all stay exactly where they are.

Nothing is deleted on the strength of a path. A link must be a link that points at the install; the
install must be a git clone of the upskill repo. Anything failing a check is left alone and named
in the output.

Linux / WSL / macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/mingzilla/upskill/prod/.install/uninstall/upskill__uninstall.sh | bash
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -c "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/mingzilla/upskill/prod/.install/uninstall/upskill__uninstall.ps1)))"
```

| Removed | Kept |
|---|---|
| `.claude\skills\upskill` - the install, once proved to be a clone of `mingzilla/upskill` | everything in `upskill__skills_lib` |
| `.codex\skills\upskill`, `.agent\skills\upskill` - once proved to be links to that install | anything else found at those paths |

It prints where your skills still are. To remove those too, delete that folder yourself - and push
anything you want to keep first.

Re-install by running the installer again.
