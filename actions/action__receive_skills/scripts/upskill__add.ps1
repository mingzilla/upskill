# upskill__add.ps1 - copy a member's shared skill into a project.
# usage: upskill__add.ps1 <member> <skill|number> [-Project <sandbox|current|<path>>] [-Agent <claude|codex>]
# exit: 0 added | 1 error | 2 no target given (the target menu was printed)
param(
    [Parameter(Position = 0)][string]$Who,
    [Parameter(Position = 1)][string]$Want,
    [string]$Project = '',
    [string]$Agent = $(if ($env:UP_SKILL_AGENT) { $env:UP_SKILL_AGENT } else { 'claude' })
)

. (Join-Path $PSScriptRoot '..\..\..\scripts\upskill__lib.ps1')

us_init

if ([string]::IsNullOrWhiteSpace($Who) -or [string]::IsNullOrWhiteSpace($Want)) {
    us_exit 'usage: upskill__add.ps1 <member> <skill|number> [-Project <sandbox|current|<path>>]'
}
if ($Agent -notin @('claude', 'codex')) { us_exit 'error: -Agent must be claude or codex' }

$key = us_key_of $Who
if (-not $key) { exit 1 }
if (-not (us_sync_repo $key)) { exit 1 }
$srcDir = us_pool_dir $key

# a bare number means "the nth of the list just shown", so it is resolved against the same order
if ($Want -match '^\d+$') {
    $names = @(us_skill_names $srcDir)
    $idx = [int]$Want
    if ($idx -lt 1 -or $idx -gt $names.Count) {
        us_exit "error: there is no skill $Want in $(us_name_of $key)'s list"
    }
    $skill = $names[$idx - 1]
} else {
    $skill = $Want
}
if (-not (us_safe_name $skill)) { exit 1 }
if (-not (Test-Path -LiteralPath (Join-Path $srcDir $skill))) {
    us_exit "error: $(us_name_of $key) has no skill called '$skill'"
}

# no target given: print the menu and stop with 2, so the caller asks rather than guessing a path
if ([string]::IsNullOrWhiteSpace($Project)) {
    @"
Where would you like to add this?
1. upskill__sandbox (Recommended)
2. your current project
3. specify a project path
"@
    exit 2
}

switch -Regex ($Project) {
    '^(1|sandbox)$' { $base = $script:US_SANDBOX; $where = '`upskill__sandbox`' }
    '^(2|current)$' { $base = (Get-Location).Path; $where = 'this project' }
    '^3$'           { us_exit 'error: say which path - re-run with -Project <path>' }
    default         { $base = $Project; $where = "``$Project``" }
}
if (-not (Test-Path -LiteralPath $base)) { us_exit "error: no such project folder: $base" }

$dest = Join-Path $base ".$Agent\skills\$skill"
$prep = if (Test-Path -LiteralPath $dest) { 'updated in' } else { 'added to' }

# the agent may be sandboxed out of the project folder; say so rather than failing obscurely
try {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) -ErrorAction Stop | Out-Null
} catch {
    us_err "error: cannot write to $(Split-Path -Parent $dest)"
    us_err "  Adding a skill writes outside this project, which needs bypass permission."
    us_exit "  Allow it, then run the same command again, unchanged."
}
if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
Copy-Item -LiteralPath (Join-Path $srcDir $skill) -Destination $dest -Recurse -Force

# a broken SKILL.md installs silently and then never loads - the receiver should hear it now
if (-not (us_validate_skill $dest)) {
    us_err "note: '$skill' has a malformed SKILL.md and may never load - tell $(us_name_of $key)"
}
"``$skill`` from ``$(us_name_of $key)`` has been $prep $where"
