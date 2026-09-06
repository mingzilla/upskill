# upskill__run.ps1 - the launcher every action goes through.
#
# ~/.claude/skills/upskill is a git clone (or a junction to one), so updating is a git operation,
# not a reinstall. On prod it mirrors the remote exactly before running; on any other branch it
# leaves the working tree alone, so development is never interrupted.
#
# usage: powershell -NoProfile -ExecutionPolicy Bypass -File upskill__run.ps1 <action> [args...]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Action,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$SKILL_DIR = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

$MAP = @{
    'menu'   = 'actions\action__show_menu\scripts\upskill__show_menu'
    'list'   = 'actions\action__receive_skills\scripts\upskill__list'
    'add'    = 'actions\action__receive_skills\scripts\upskill__add'
    'find'   = 'actions\action__provide_skills\scripts\upskill__find_skill'
    'share'  = 'actions\action__provide_skills\scripts\upskill__share'
    'remove' = 'actions\action__provide_skills\scripts\upskill__remove'
    'scan'   = 'actions\action__provide_skills\scripts\upskill__scan_secrets'
    'import' = 'actions\action__manage_address_book\scripts\upskill__import_contacts'
}

# an unknown name is treated as a path, so an action added later works with an older launcher
$rel = if ($MAP.ContainsKey($Action)) { $MAP[$Action] } else { $Action }

# git refuses a repo owned by another user ("dubious ownership"), which happens routinely when a
# tree is written by one environment and read by another. Trust it per command rather than
# editing the user's global config.
function run_self_update {
    if (-not (Test-Path -LiteralPath (Join-Path $SKILL_DIR '.git'))) { return }
    $branch = & git -c safe.directory='*' -C $SKILL_DIR rev-parse --abbrev-ref HEAD 2>$null
    # only prod is a mirror of the remote; any other branch is someone's working copy
    if ($branch -ne 'prod') { return }
    & git -c safe.directory='*' -C $SKILL_DIR fetch --quiet origin prod 2>$null
    if ($LASTEXITCODE -ne 0) { return }
    & git -c safe.directory='*' -C $SKILL_DIR reset --hard --quiet origin/prod 2>$null
    & git -c safe.directory='*' -C $SKILL_DIR clean -fdq 2>$null
}

run_self_update

$target = Join-Path $SKILL_DIR "$rel.ps1"
if (-not (Test-Path -LiteralPath $target)) {
    [Console]::Error.WriteLine("error: no such upskill action: $Action")
    exit 1
}

# Splatting an ARRAY passes every element positionally, so "-Project sandbox" would arrive as two
# positional values and fail to bind. Split the tail into positional args and a named hashtable.
# Both -Project and --project are accepted, so the two shells take the same command line.
$pos = @()
$named = @{}
for ($i = 0; $i -lt $Rest.Count; $i++) {
    if ($Rest[$i] -match '^--?([A-Za-z][\w-]*)$') {
        $key = $Matches[1]
        if ($i + 1 -lt $Rest.Count -and $Rest[$i + 1] -notmatch '^--?[A-Za-z]') {
            $named[$key] = $Rest[$i + 1]
            $i++
        } else {
            $named[$key] = $true      # a switch, e.g. -Quiet
        }
    } else {
        $pos += $Rest[$i]
    }
}

& $target @pos @named
exit $LASTEXITCODE
