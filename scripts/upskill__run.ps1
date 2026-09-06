# upskill__run.ps1 - the launcher every action goes through. PowerShell mirror of upskill__run.sh.
#
# The installed copy of this skill must never need replacing: it pulls the workspace clone to the
# latest prod and then runs the real script FROM THERE. So a push to prod takes effect on the very
# next run, and a user is never asked to install again - even if the copy in ~\.claude\skills or
# ~\.codex\skills is old, because nothing but this launcher is read from it.
#
# usage: upskill__run.ps1 <action|relative-script-path> [args...]
#   <action> is a short name (menu, list, add, install, share, remove, create-address-book,
#   switch-address-book); an unknown name is treated as a path under the skill folder, so actions
#   added to prod later still work with an old launcher.
param(
    [Parameter(Mandatory = $true)][string]$Action,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest
)

# deliberately NOT 'Stop': a failed pull, or git writing to stderr, must never stop the action
$ErrorActionPreference = 'Continue'

$map = @{
    'menu'                = 'actions\action__show_menu\scripts\upskill__show_menu'
    'list'                = 'actions\action__receive_skills\scripts\upskill__list'
    'add'                 = 'actions\action__receive_skills\scripts\upskill__add'
    'install'             = 'actions\action__receive_skills\scripts\upskill__install'
    'share'               = 'actions\action__provide_skills\scripts\upskill__share'
    'remove'              = 'actions\action__provide_skills\scripts\upskill__remove'
    'scan'                = 'actions\action__provide_skills\scripts\upskill__scan_secrets'
    'create-address-book' = 'actions\action__manage_address_book\scripts\upskill__create_address_book'
    'switch-address-book' = 'actions\action__manage_address_book\scripts\upskill__switch_address_book'
}
$rel = if ($map.ContainsKey($Action)) { $map[$Action] } else { $Action -replace '/', '\' }

# resolve the workspace the same way the library does: env, then upward from here, then the profile
$ws = $env:UP_SKILL_WORKSPACE
if (-not $ws) {
    $d = (Get-Location).Path
    while ($d) {
        if (Test-Path -LiteralPath (Join-Path $d 'upskill__user-config.json')) { $ws = $d; break }
        $parent = Split-Path -Parent $d
        if ($parent -eq $d) { break }
        $d = $parent
    }
}
if (-not $ws) {
    $profileWs = Join-Path $HOME '.upskill__workspace'
    if (Test-Path -LiteralPath $profileWs) { $ws = $profileWs }
}

# take the newest prod before deciding what to run
# git refuses to touch a repo whose owner differs from the caller ("dubious ownership") - which
# happens routinely here: the workspace can be created by the Windows installer and then read by
# WSL, or vice versa. Trust it for the length of a single command rather than editing the user's
# global git config.
$sol = if ($ws) { Join-Path $ws 'upskill' } else { '' }
if ($sol -and (Test-Path -LiteralPath (Join-Path $sol '.git'))) {
    & git -c 'safe.directory=*' -C $sol pull --ff-only --quiet 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $dirty = & git -c 'safe.directory=*' -C $sol status --porcelain 2>$null
        if ($dirty) {
            [Console]::Error.WriteLine("note: upskill is not updating - '$sol' has local changes; discard them there.")
        }
    }
}

$here = Split-Path -Parent $PSScriptRoot     # the installed skill folder
$src = if ($sol) { Join-Path $sol '_system\l2_share_skills\.claude\skills\upskill' } else { '' }

# keep the installed copy in step with prod - it is what the agent READS (SKILL.md, the action
# docs) even though it is not what runs. Overlay rather than delete-and-replace, so the launcher
# executing right now is never removed out from under itself. Best effort: never fatal.
$hereParent = (Split-Path -Parent $here).Replace('/', '\').TrimEnd('\')
$isAgentCopy = $hereParent.EndsWith('\.claude\skills') -or $hereParent.EndsWith('\.codex\skills')
if ($isAgentCopy) {
    # tell the action which agent invoked it. The action scripts run from the workspace now, so
    # their own path no longer says whether this is Claude Code or Codex - and "add to my user
    # skills" must land in the caller's folder, not always ~\.claude\skills.
    $env:UP_SKILL_AGENT_SKILLS = $hereParent
}
if ($src -and $isAgentCopy -and (Test-Path -LiteralPath (Join-Path $src 'SKILL.md'))) {
    # file by file: the agent may hold one of these open (this launcher itself, most likely), and a
    # single locked file must not stop the rest - SKILL.md is the one that really matters.
    $failed = 0
    foreach ($f in @(Get-ChildItem -LiteralPath $src -Recurse -File -ErrorAction SilentlyContinue)) {
        $rel2 = $f.FullName.Substring($src.Length).TrimStart('\')
        $dest = Join-Path $here $rel2
        try {
            $destDir = Split-Path -Parent $dest
            if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
            Copy-Item -LiteralPath $f.FullName -Destination $dest -Force -ErrorAction Stop
        }
        catch { $failed++ }
    }
    # only worth telling the user when the instructions they are about to follow are stale
    if ($failed -gt 0 -and -not (Test-Path -LiteralPath (Join-Path $here 'SKILL.md'))) {
        [Console]::Error.WriteLine("note: could not refresh $here")
    }
}

$target = ''
if ($src) { $target = Join-Path $src ($rel + '.ps1') }
if (-not $target -or -not (Test-Path -LiteralPath $target)) {
    $target = Join-Path $here ($rel + '.ps1')  # no workspace? run what is installed
}
if (-not (Test-Path -LiteralPath $target)) {
    [Console]::Error.WriteLine("error: no such upskill action: $Action")
    exit 1
}

& $target @Rest
exit $LASTEXITCODE
