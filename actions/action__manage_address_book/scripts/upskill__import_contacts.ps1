# upskill__import_contacts.ps1 - merge people from another address book into the active one.
# usage: upskill__import_contacts.ps1 <url|path>
param([Parameter(Position = 0)][string]$Source)

. (Join-Path $PSScriptRoot '..\..\..\scripts\upskill__lib.ps1')

us_init

if ([string]::IsNullOrWhiteSpace($Source)) {
    us_exit 'usage: upskill__import_contacts.ps1 <url|path-to-address_book.json>'
}

if (Test-Path -LiteralPath $Source) {
    $raw = Get-Content -LiteralPath $Source -Raw
} else {
    # a github page url returns html; only the raw url returns the json
    $url = $Source -replace 'github\.com/([^/]+)/([^/]+)/(blob|tree)/', 'raw.githubusercontent.com/$1/$2/'
    try {
        $raw = (Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop).Content
    } catch {
        us_exit "error: cannot download $url"
    }
}

try { $incoming = $raw | ConvertFrom-Json } catch { us_exit "error: not valid json: $Source" }
if (-not $incoming.users) { us_exit "error: not an address book (no `"users`"): $Source" }

$book = Get-Content -LiteralPath $script:US_AB_JSON -Raw | ConvertFrom-Json
if (-not $book.users) { $book | Add-Member -NotePropertyName users -NotePropertyValue ([pscustomobject]@{}) }

$added = @()
$existing = @()
# merge by key. A key already present is left exactly as it is - the local entry is the user's,
# and an import must never rewrite where their skills come from.
foreach ($p in $incoming.users.PSObject.Properties) {
    $name = if ($p.Value.name) { $p.Value.name } else { $p.Name }
    if ($book.users.PSObject.Properties.Name -contains $p.Name) {
        $cur = $book.users.($p.Name)
        $existing += $(if ($cur.name) { $cur.name } else { $p.Name })
    } else {
        $book.users | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value
        $added += $name
    }
}

if ($added.Count -gt 0) {
    ($book | ConvertTo-Json -Depth 20) + "`n" | Set-Content -LiteralPath $script:US_AB_JSON -NoNewline -Encoding UTF8
}

if ($added.Count -gt 0) { 'Imported: ' + (($added | Sort-Object) -join ', ') } else { 'Imported: nothing new' }
if ($existing.Count -gt 0) { 'Already in your address book: ' + (($existing | Sort-Object) -join ', ') }

# two keys may carry one display name - legal, but the menu would show it twice
$seen = @{}
foreach ($p in $book.users.PSObject.Properties) {
    $n = if ($p.Value.name) { $p.Value.name } else { $p.Name }
    if (-not $seen.ContainsKey($n)) { $seen[$n] = @() }
    $seen[$n] += $p.Name
}
foreach ($n in ($seen.Keys | Sort-Object)) {
    if ($seen[$n].Count -gt 1) { "Name clash - `"$n`" is used by: " + (($seen[$n] | Sort-Object) -join ', ') }
}
