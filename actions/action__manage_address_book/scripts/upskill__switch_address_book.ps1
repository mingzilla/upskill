# upskill__switch_address_book.ps1 - point the config at another installed address book.
# usage: powershell ... -File upskill__switch_address_book.ps1 <team-or-address-book-name>
param([string]$Name = '')

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '../../../scripts/upskill__lib.ps1')

$start = $PWD.Path
if ($env:UP_SKILL_WORKSPACE) { $start = $env:UP_SKILL_WORKSPACE }
us_init -StartDir $start

if ([string]::IsNullOrWhiteSpace($Name)) {
    [Console]::Error.WriteLine('usage: upskill__switch_address_book.ps1 <team-or-address-book-name>')
    exit 1
}

$teamWant = $Name
if ($teamWant.StartsWith('upskill__address_book__')) { $teamWant = 'team__' + $teamWant.Substring('upskill__address_book__'.Length) }
elseif (-not $teamWant.StartsWith('team__')) { $teamWant = 'team__' + $teamWant }

$abDir = $null
$base = Join-Path $script:US_WORKSPACE ("address_books\" + $teamWant)
if (Test-Path -LiteralPath $base -PathType Container) {
    foreach ($d in @(Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue)) {
        if (Test-Path -LiteralPath (Join-Path $d.FullName 'address_book.json')) { $abDir = $d.FullName; break }
    }
}
if (-not $abDir) {
    $installed = @(Get-ChildItem -LiteralPath (Join-Path $script:US_WORKSPACE 'address_books') -Directory -ErrorAction SilentlyContinue | ForEach-Object Name) -join ' '
    [Console]::Error.WriteLine("error: no installed address book for '$teamWant'")
    [Console]::Error.WriteLine("  installed: $installed")
    [Console]::Error.WriteLine('  add one first with: upskill__create_address_book.ps1 <repo-url>')
    exit 1
}
$abName = Split-Path -Leaf $abDir

$cfg = Join-Path $script:US_WORKSPACE 'upskill__user-config.json'
$d = ([System.IO.File]::ReadAllText($cfg) | ConvertFrom-Json)
$d.team = $teamWant
$d.address_book = ".\address_books\$teamWant\$abName"
@{ user = $d.user; team = $d.team; address_book = $d.address_book } | ConvertTo-Json | Set-Content -Path $cfg -Encoding UTF8

Write-Output "switched to address book '$teamWant' (user '$($d.user)')"
Write-Output '  run upskill again to see its members.'
