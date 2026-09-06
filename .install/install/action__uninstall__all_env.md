---
name: action__uninstall__all_env.md
usage: drop the url of this file to your AI harness
---

## Uninstall

Scans the places an upskill install can live - the Linux/WSL profile and the Windows profile (when
reachable) - lists every one it finds, and asks before deleting anything. Your github repos and your
projects are never touched.

Linux / WSL / macOS (bash):

```bash
curl -fsSL https://raw.githubusercontent.com/mingzilla/upskill/main/upskill__uninstall.sh | bash
```

(add `--yes` to skip the "Ok to delete these?" question)

Windows (PowerShell):

```powershell
powershell -ExecutionPolicy Bypass -c "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/mingzilla/upskill/main/upskill__uninstall.ps1))) -Yes"
```

What it removes (whatever it finds; shows the exact list before deleting):

| Removed | Where it looks |
|---|---|
| Global skill folders `upskill`, `upskill__sharing__*`, `upskill__action__*` | `~/.claude/skills/` and `C:\Users\<you>\.claude\skills\` |
| Workspace | `~/.upskill__workspace` and `C:\Users\<you>\.upskill__workspace` |

If it reports nothing found, there is no install to remove on this machine.
