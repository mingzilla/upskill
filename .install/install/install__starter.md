# Installation Guide for Smoke Test

## Step 1: Repository Setup

Follow the instructions in the setup guide:  
https://github.com/mingzilla/upskill/blob/prod/.install/guide__create_public_skills/README.md

- Create two repositories: `public_skills` and `private_skills`
- Share the `public_skills` repository with Ming

## Step 2: GitHub CLI and log in

Your AI tool uses the GitHub CLI to push your skills, so it must be installed and logged in. Install
`gh` if it is not there:

| OS                    | Install command                          |
|-----------------------|------------------------------------------|
| Windows               | `winget install --id GitHub.cli`         |
| macOS                 | `brew install gh`                        |
| Debian / Ubuntu / WSL | `sudo apt update && sudo apt install gh` |

If your package manager lacks it, follow https://cli.github.com

Restart the terminal (close it and open a new one) after installing so `gh` is on your PATH, then log in:

```commandline
gh auth login --hostname github.com --git-protocol https
```

## Step 3: Run Installation Script

### Linux / WSL / macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/mingzilla/upskill/prod/.install/install/upskill__install.sh | bash
```

### Windows:

```powershell
powershell -ExecutionPolicy Bypass -c "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/mingzilla/upskill/prod/.install/install/upskill__install.ps1)))"
```

### Linux / WSL / macOS - Demo (loads the demo address book):

```bash
curl -fsSL https://raw.githubusercontent.com/mingzilla/upskill/prod/.install/install/upskill__install.sh \
  | UP_SKILL_ADDRESS_BOOK=https://raw.githubusercontent.com/mingzilla/upskill/main/.install/install/address_book__demo.json bash
```

### Windows - Demo (loads the demo address book):

```powershell
powershell -ExecutionPolicy Bypass -c "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/mingzilla/upskill/prod/.install/install/upskill__install.ps1))) -AddressBook 'https://raw.githubusercontent.com/mingzilla/upskill/main/.install/install/address_book__demo.json'"
```

## Step 5: Sharing and Receiving

Bypass permission is required
