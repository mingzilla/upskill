# upskill__add.ps1 - copy a member's shared skill to a target: global, the current project, or a
# selected project. PowerShell mirror of upskill__add.sh.
# usage:
#   upskill__add.ps1 <owner> <skill> --project current    -> this project's <agent>\skills
#   upskill__add.ps1 <owner> <skill> --project <path>     -> that project's <agent>\skills
# <agent> is .claude or .codex, taken from UP_SKILL_AGENT_SKILLS (set by the launcher).
# Arguments are parsed by hand, in the same form the .sh takes: two positionals then
# `--project <value>`. The docs are shell-neutral ("<upskill> add <owner> <skill> --project ..."),
# so PowerShell must accept that literal syntax - a -Project style parameter would swallow
# "--project" as a positional value and try to use it as a folder name.
param(
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$CmdArgs = @()
)

$Owner = ''
$Skill = ''
$Project = ''
$positional = @()
for ($i = 0; $i -lt $CmdArgs.Count; $i++) {
    $a = $CmdArgs[$i]
    if ($a -eq '--project' -or $a -eq '-Project') {
        $i++
        if ($i -lt $CmdArgs.Count) { $Project = $CmdArgs[$i] }
    }
    else {
        $positional += $a
    }
}
if ($positional.Count -ge 1) { $Owner = $positional[0] }
if ($positional.Count -ge 2) { $Skill = $positional[1] }

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '../../../scripts/upskill__lib.ps1')

$start = $PWD.Path
if ($env:UP_SKILL_WORKSPACE) { $start = $env:UP_SKILL_WORKSPACE }
us_init -StartDir $start

if ([string]::IsNullOrWhiteSpace($Owner) -or [string]::IsNullOrWhiteSpace($Skill)) {
    [Console]::Error.WriteLine('usage: upskill__add.ps1 <owner> <skill> --project <current|<path>>')
    exit 1
}
if (-not (us_safe_name $Skill)) { exit 1 }

# which agent is asking: the launcher exports its own skills folder (~\.claude\skills or
# ~\.codex\skills). Everything below installs into THAT agent's layout - a Codex user must not have
# skills copied into .claude, where Codex will never look for them.
$agentSkills = $env:UP_SKILL_AGENT_SKILLS
if (-not $agentSkills) { $agentSkills = Join-Path $HOME '.claude\skills' }
$agentDir = Split-Path -Leaf (Split-Path -Parent $agentSkills)   # .claude or .codex

if ([string]::IsNullOrWhiteSpace($Project)) {
    # no target given: print a numbered "where to add" menu and signal the caller to ask (exit 2)
    Write-Output "Where to add '$Skill' (from $Owner)?"
    Write-Output "1. current project     - this project's $agentDir/skills"
    Write-Output "2. another project     - you'll be asked for its path"
    Write-Output ''
    Write-Output 'Reply with a number (e.g. "1"), or say the target directly.'
    exit 2
}

# Skills always go into a project: agents sandbox their own user-level skills folder against
# writes (Codex refuses outright), and a project copy is the one both agents can install and read.
# Only upskill itself lives user-level, put there by the installer.
switch ($Project) {
    { $_ -in @('global', 'user') } {
        [Console]::Error.WriteLine('error: skills are added to a project, not user-level')
        [Console]::Error.WriteLine('  use --project current, or --project <path-to-a-project>')
        exit 1
    }
    'current' { $destRoot = Join-Path $PWD.Path (Join-Path $agentDir 'skills') }
    default {
        if (-not (Test-Path -LiteralPath $Project -PathType Container)) {
            [Console]::Error.WriteLine("error: target project not found: $Project")
            exit 1
        }
        $destRoot = Join-Path $Project (Join-Path $agentDir 'skills')
    }
}

$folder = us_folder_of $Owner
if ([string]::IsNullOrWhiteSpace($folder)) {
    [Console]::Error.WriteLine("error: '$Owner' is not in the address book")
    exit 1
}
$clone = Join-Path $script:US_TEAM_DIR $folder
if (-not (Test-Path -LiteralPath (Join-Path $clone '.git'))) {
    [Console]::Error.WriteLine("error: no local clone for '$Owner' at $clone (run the installer first)")
    exit 1
}
if ($folder -ne $script:US_ME_FOLDER) {
    us_git_try @('-C', $clone, 'pull', '--ff-only', '--quiet')
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("note: could not pull '$Owner' - reading the local clone as-is")
    }
}

$srcskill = Join-Path $clone $Skill
if (-not (Test-Path -LiteralPath (Join-Path $srcskill 'SKILL.md'))) {
    [Console]::Error.WriteLine("error: '$Owner' has no shared skill '$Skill'. Available from ${Owner}:")
    foreach ($s in @(us_skill_names $clone)) { [Console]::Error.WriteLine('  ' + $s) }
    exit 1
}

$dest = Join-Path $destRoot $Skill
New-Item -ItemType Directory -Force -Path $destRoot | Out-Null
us_copy_tree $srcskill $dest

Write-Output "added '$Skill' (from $Owner) to $dest"
switch ($Project) {
    'current' { Write-Output "  open your agent in '$($PWD.Path)' and the skill will be available." }
    default   { Write-Output "  open your agent in '$Project' and the skill will be available." }
}
