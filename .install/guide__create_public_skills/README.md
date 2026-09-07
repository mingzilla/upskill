# Creating Skill Repositories

## GitHub CLI and log in

Your AI tool uses the GitHub CLI to push your skills, so it must be installed and logged in before
anything else.

Install the GitHub CLI if it is not already there:

| OS | Install command |
|---|---|
| Windows | `winget install --id GitHub.cli` |
| macOS | `brew install gh` |
| Debian / Ubuntu | `sudo apt update && sudo apt install gh` |
| Fedora | `sudo dnf install gh` |

If your package manager does not offer it, follow https://cli.github.com

Close and reopen the terminal after installing so `gh` is on your PATH, then log in:

```commandline
gh auth login --hostname github.com --git-protocol https
```

Verify it worked with `gh auth status`.

## Create the repositories

1. Create two GitHub repositories:
    - `public_skills` (public)
    - `private_skills` (private)

2. Share the public repository URL with the admin:
    - `https://github.com/<username>/public_skills.git`
