# upskill__add_contacts.ps1 - add name+repo pairs to your OWN (active) address book.
# usage: powershell -File upskill__add_contacts.ps1 <name> <repo-url> [<name> <repo-url> ...]
#
# Unlike create_address_book (a sandbox draft), this writes into the book you actually use. A key
# that is already there is replaced by the new entry - you are declaring the contact, so the newest
# version wins.
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Pairs)

. (Join-Path $PSScriptRoot '..\..\..\scripts\upskill__lib.ps1')

us_init   # the active address book must exist - this adds people to it

if ($Pairs.Count -lt 2) { us_exit 'usage: upskill__add_contacts.ps1 <name> <repo-url> [<name> <repo-url> ...]' }
if ($Pairs.Count % 2 -ne 0) { us_exit 'error: pairs must be <name> <repo-url> - got an odd number of arguments' }

# normalise git@host:owner/repo.git and https://host/owner/repo.git to owner/repo
function KeyOf([string]$url) {
    $u = $url.Trim().TrimEnd('/')
    if ($u.EndsWith('.git')) { $u = $u.Substring(0, $u.Length - 4) }
    $u = $u.Replace('git@', '')
    foreach ($p in @('https://', 'http://', 'ssh://')) { $u = $u.Replace($p, '') }
    $parts = @($u.Replace(':', '/') -split '/' | Where-Object { $_ })
    if ($parts.Count -lt 2) { return $null }
    ($parts[$parts.Count - 2]) + '__' + ($parts[$parts.Count - 1])
}

# validate every pair up front - a doomed run must never write
for ($i = 0; $i -lt $Pairs.Count; $i += 2) {
    $name = $Pairs[$i]
    $url  = $Pairs[$i + 1]
    if (-not (us_safe_name $name)) { exit 1 }
    if ($url -notmatch '^https?://' -or -not (KeyOf $url)) { us_exit "error: not a valid repo url: $url" }
}

try { $book = Get-Content -LiteralPath $script:US_AB_JSON -Raw | ConvertFrom-Json }
catch { us_exit "error: the address book is not valid json: $($script:US_AB_JSON)" }

$users = [ordered]@{}
if ($book.users) {
    foreach ($p in $book.users.PSObject.Properties) {
        $users[$p.Name] = @{ name = $p.Value.name; folder = $p.Value.folder; repo = $p.Value.repo }
    }
}

$added = @()
$updated = @()
for ($i = 0; $i -lt $Pairs.Count; $i += 2) {
    $name = $Pairs[$i]
    $url  = $Pairs[$i + 1]
    $key  = KeyOf $url
    if ($users.Contains($key)) { $updated += $name } else { $added += $name }
    $users[$key] = @{ name = $name; folder = $key; repo = $url }
}

$out = [ordered]@{ users = $users }
($out | ConvertTo-Json -Depth 20) + "`n" | Set-Content -LiteralPath $script:US_AB_JSON -NoNewline -Encoding UTF8

$lines = @()
if ($added.Count -gt 0)   { $lines += 'Added: ' + (($added   | Sort-Object) -join ', ') }
if ($updated.Count -gt 0) { $lines += 'Updated: ' + (($updated | Sort-Object) -join ', ') }
$lines += "Address book: $($script:US_AB_JSON) ($($users.Count) members)"

$lines
