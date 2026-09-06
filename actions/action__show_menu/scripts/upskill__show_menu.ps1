# upskill__show_menu.ps1 - print the upskill home screen. Read-only, and deliberately offline:
# the menu is the most-used command, so it never fetches a repo. Skill counts would mean pulling
# every member - on a large address book that is a long wait before anything is shown.
. (Join-Path $PSScriptRoot '..\..\..\scripts\upskill__lib.ps1')

us_init

# address_book__sandbox.json -> sandbox; address_book.json -> default
$base = [IO.Path]::GetFileNameWithoutExtension($script:US_AB_JSON)
$bookName = if ($base -like 'address_book__*') { $base.Substring('address_book__'.Length) } else { 'default' }

$members = @(us_members)
$memberLine = ($members | ForEach-Object { $_.Name }) -join ', '

# "active" only means something when there is another book to switch to
$books = @(Get-ChildItem -LiteralPath $script:US_POOL -Filter 'address_book*.json' -File -ErrorAction SilentlyContinue)
$activeMark = if ($books.Count -gt 1) { ' - active' } else { '' }

@"
You can share or receive skills with members from the active address book:

Address Book: $bookName ($($members.Count) members)$activeMark
- $memberLine

---

What would you like to do?
1. Show a member's skills        - e.g. "show Andy's skills"
2. Add a member's skill          - e.g. "add Andy's say_hello skill"
3. Share your skill              - e.g. "share my xxx skill"
4. Remove a shared skill         - e.g. "remove my xxx skill"

Manage address books:
5. Import contacts
"@
