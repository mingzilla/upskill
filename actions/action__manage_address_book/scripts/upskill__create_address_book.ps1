# upskill__create_address_book.ps1 - add an address book to this machine (clone into the workspace
# under the address_books/<team>/ convention). Does NOT switch to it.
# usage: powershell ... -File upskill__create_address_book.ps1 <repo-url|local-path>
param([string]$Url = '')

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '../../../scripts/upskill__lib.ps1')

$start = $PWD.Path
if ($env:UP_SKILL_WORKSPACE) { $start = $env:UP_SKILL_WORKSPACE }
us_init -StartDir $start

if ([string]::IsNullOrWhiteSpace($Url)) {
    [Console]::Error.WriteLine('usage: upskill__create_address_book.ps1 <repo-url|local-path>')
    exit 1
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { [Console]::Error.WriteLine('error: git is required'); exit 1 }

$base = $Url.TrimEnd('/')
$base = $base.Substring($base.LastIndexOfAny(@('/', '\')) + 1)
if ($base.EndsWith('.git')) { $base = $base.Substring(0, $base.Length - 4) }
if ($base -like 'upskill__address_book__*') {
    $team = 'team__' + $base.Substring('upskill__address_book__'.Length)
}
else {
    $team = $base
}
$teamDir = Join-Path $script:US_WORKSPACE ("address_books\" + $team)
$dest = Join-Path $teamDir $base
if (Test-Path -LiteralPath (Join-Path $dest '.git')) {
    [Console]::Error.WriteLine("address book already exists at $dest - nothing to do")
    exit 0
}
New-Item -ItemType Directory -Force -Path $teamDir | Out-Null
Write-Output "cloning $Url"
& git clone --quiet $Url $dest
if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine('error: git clone failed'); exit 1 }

if (-not (Test-Path -LiteralPath (Join-Path $dest 'address_book.json'))) {
    [Console]::Error.WriteLine("error: no address_book.json in the cloned repo ($dest) - not an address book")
    exit 1
}
Write-Output "created address book '$team' at $dest"
$short = $team; if ($short.StartsWith('team__')) { $short = $short.Substring('team__'.Length) }
Write-Output "  switch to it with: upskill__switch_address_book.ps1 $short"
