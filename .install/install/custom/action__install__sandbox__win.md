---
name: action__install__sandbox__win.md
---

```bash
powershell -ExecutionPolicy Bypass -c "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/mingzilla/upskill/main/upskill__install.ps1))) -AddressBook 'https://github.com/mingzilla/upskill__address_book__sandbox.git'"
```
