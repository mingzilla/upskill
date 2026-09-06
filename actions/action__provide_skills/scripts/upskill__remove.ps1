# upskill__remove.ps1 - take one of MY shared skills back out of public_skills.
# usage: upskill__remove.ps1 [<skill|number>]   (no argument lists them, numbered)
param([Parameter(Position = 0)][string]$Skill = '')

. (Join-Path $PSScriptRoot '..\..\..\scripts\upskill__lib.ps1')

us_init

if (-not (Test-Path -LiteralPath (Join-Path $script:US_ME_DIR '.git'))) {
    us_exit "error: your skills repo is missing: $($script:US_ME_DIR)"
}

$names = @(us_skill_names $script:US_ME_DIR)

# no argument: show what can be removed, numbered, and stop - the user picks
if ([string]::IsNullOrWhiteSpace($Skill)) {
    if ($names.Count -eq 0) { 'you have not shared any skills yet'; exit 0 }
    'Your shared skills - say which to remove'
    for ($i = 0; $i -lt $names.Count; $i++) { "$($i + 1). $($names[$i])" }
    exit 0
}

if ($Skill -match '^\d+$') {
    $idx = [int]$Skill
    if ($idx -lt 1 -or $idx -gt $names.Count) { us_exit "error: there is no shared skill $Skill" }
    $name = $names[$idx - 1]
} else {
    $name = $Skill
}
if (-not (us_safe_name $name)) { exit 1 }
$target = Join-Path $script:US_ME_DIR $name
if (-not (Test-Path -LiteralPath $target)) { us_exit "error: you have not shared a skill called '$name'" }

Remove-Item -LiteralPath $target -Recurse -Force
& git -c safe.directory='*' -C $script:US_ME_DIR add -A
if ($LASTEXITCODE -ne 0) { us_exit 'error: git add failed' }
& git -c safe.directory='*' -C $script:US_ME_DIR diff --cached --quiet
if ($LASTEXITCODE -eq 0) { "no change - ``$name`` was not shared"; exit 0 }
& git -c safe.directory='*' -C $script:US_ME_DIR commit -q -m "remove $name"
if ($LASTEXITCODE -ne 0) { us_exit 'error: commit failed' }
& git -c safe.directory='*' -C $script:US_ME_DIR push -q
if ($LASTEXITCODE -ne 0) { us_exit 'error: push failed - check your github access' }

# without this the pool copy still lists the skill I just removed
$mine = us_my_key
if ($mine) {
    $pool = us_pool_dir $mine
    if (Test-Path -LiteralPath (Join-Path $pool '.git')) {
        & git -c safe.directory='*' -C $pool pull --ff-only --quiet 2>$null
    }
}

$origin = & git -c safe.directory='*' -C $script:US_ME_DIR remote get-url origin 2>$null
"``$name`` has been removed from ``$origin``"
