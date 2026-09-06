# upskill__list.ps1 - show one member's shared skills, numbered.
# usage: upskill__list.ps1 <member>
param([Parameter(Position = 0)][string]$Who)

. (Join-Path $PSScriptRoot '..\..\..\scripts\upskill__lib.ps1')

us_init

if ([string]::IsNullOrWhiteSpace($Who)) {
    us_err 'usage: upskill__list.ps1 <member>'
    us_err ('  members: ' + ((us_members | ForEach-Object { $_.Name }) -join ', '))
    exit 1
}

# only this one member's repo is fetched - listing must never cost a whole address book
$key = us_key_of $Who
if (-not $key) { exit 1 }
if (-not (us_sync_repo $key)) { exit 1 }

$names = @(us_skill_names (us_pool_dir $key))
if ($names.Count -eq 0) {
    "$(us_name_of $key) has not shared any skills yet"
    exit 0
}

"Choose what to add to your projects"
for ($i = 0; $i -lt $names.Count; $i++) { "$($i + 1). $($names[$i])" }
