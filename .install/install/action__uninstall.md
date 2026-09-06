---
name: action__uninstall.md
usage: drop the url of this file to your AI harness
---

## Uninstall

Removes the link that makes agents load upskill. **Nothing else is deleted** - your repos, your
sandbox, your private files and your projects all stay exactly where they are.

Linux / WSL / macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/mingzilla/upskill/prod/.install/uninstall/upskill__uninstall.sh | bash
```

| Removed | Kept |
|---|---|
| `~/.claude/skills/upskill` and `~/.codex/skills/upskill` (links only) | everything in `upskill__skills_lib/` |

It prints where your skills still are. To remove those too, delete that folder yourself - and push
anything you want to keep first.

Re-install by running `upskill__install.sh` again.
