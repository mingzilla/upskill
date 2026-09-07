# upskill__create_address_book.ps1 - make an address book from name+repo pairs, as a sandbox draft.
# usage: powershell -File upskill__create_address_book.ps1 <name> <repo-url> [<name> <repo-url> ...]
#
# The draft lives at <sandbox>\address_book.json and never touches the active book. If a draft is
# already there the user is told up front and the new entries are merged in - on a matching key the
# new entry replaces the existing one.
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Pairs)

. (Join-Path $PSScriptRoot '..\..\..\scripts\upskill__lib.ps1')

us_load_config
if (-not (Test-Path -LiteralPath $script:US_ROOT)) {
    us_exit "error: skills_lib_root does not exist: $($script:US_ROOT)"
}
# create has no existing book to copy from - the sandbox dir may not exist yet
New-Item -ItemType Directory -Force -Path $script:US_SANDBOX | Out-Null
$target = Join-Path $script:US_SANDBOX 'address_book.json'

if ($Pairs.Count -lt 2) { us_exit 'usage: upskill__create_address_book.ps1 <name> <repo-url> [<name> <repo-url> ...]' }
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

# validate every pair up front - a doomed run must never write or warn
for ($i = 0; $i -lt $Pairs.Count; $i += 2) {
    $name = $Pairs[$i]
    $url  = $Pairs[$i + 1]
    if (-not (us_safe_name $name)) { exit 1 }
    if ($url -notmatch '^https?://' -or -not (KeyOf $url)) { us_exit "error: not a valid repo url: $url" }
}

$users = [ordered]@{}
$existed = Test-Path -LiteralPath $target
$lines = @()
if ($existed) {
    try { $raw = Get-Content -LiteralPath $target -Raw | ConvertFrom-Json }
    catch { us_exit "error: the existing address book is not valid json: $target" }
    if ($raw.users) {
        foreach ($p in $raw.users.PSObject.Properties) {
            $users[$p.Name] = @{ name = $p.Value.name; folder = $p.Value.folder; repo = $p.Value.repo }
        }
    }
    $lines += "An address book already exists: $target"
    $lines += 'New entries are merged in - on a matching key the new entry replaces the existing one.'
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
($out | ConvertTo-Json -Depth 20) + "`n" | Set-Content -LiteralPath $target -NoNewline -Encoding UTF8

if ($added.Count -gt 0)   { $lines += 'Added: ' + (($added   | Sort-Object) -join ', ') }
if ($updated.Count -gt 0) { $lines += 'Updated: ' + (($updated | Sort-Object) -join ', ') }
$lines += "Address book: $target ($($users.Count) members)"

$lines
