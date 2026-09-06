---
name: action__install__sandbox__win.md
---

```bash
powershell -ExecutionPolicy Bypass -c "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/mingzilla/upskill/main/upskill__install.ps1))) -AddressBook 'https://github.com/mingzilla/upskill/blob/prod/.install/guide__import_address_book/address_book.json'"
```
