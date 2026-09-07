---
name: action__install__zandra.md
---

```powershell
powershell -ExecutionPolicy Bypass -c "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/mingzilla/upskill/prod/.install/upskill__install.ps1))) -AddressBook 'https://raw.githubusercontent.com/mingzilla/upskill__setup/main/address_books/address_book__zandra.json'"
```

## Github log in

Ask claude desktop or codex to do the below:

```commandline
gh auth login --hostname github.com --git-protocol https
```