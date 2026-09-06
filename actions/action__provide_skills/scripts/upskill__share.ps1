# upskill__share.ps1 - copy a local skill folder into my skills repo and push it.
# PowerShell equivalent of upskill__share.sh.
# usage: upskill__share.ps1 <skill-folder|skill-name> [message]
param(
    [string]$Skill = '',
    [string]$Message = ''
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '../../../scripts/upskill__lib.ps1')

$start = $PWD.Path
if ($env:UP_SKILL_WORKSPACE) { $start = $env:UP_SKILL_WORKSPACE }
us_init -StartDir $start

if ([string]::IsNullOrWhiteSpace($Skill)) {
    us_err 'usage: upskill__share.ps1 <skill-folder|skill-name> [message]'
    exit 1
}
$src = $Skill

# accept a folder path, or a bare name inside $PWD/.claude/skills
if (-not (Test-Path -LiteralPath $src -PathType Container)) {
    $candidate = Join-Path $PWD.Path (Join-Path '.claude/skills' $src)
    if (Test-Path -LiteralPath $candidate -PathType Container) {
        $src = $candidate
    }
    else {
        us_err "error: skill not found: '$Skill'"
        us_err '  give a folder path, or a skill name inside <dir>/.claude/skills'
        exit 1
    }
}
# a skill only reaches the team if it will actually load for them
if (-not (us_validate_skill $src)) { exit 1 }

# a credential that reaches a public repo is public forever, even if the next commit deletes it -
# so this refuses before anything is copied, committed or pushed
$scanner = Join-Path $PSScriptRoot 'upskill__scan_secrets.ps1'
& $scanner -Quiet $src
if ($LASTEXITCODE -ne 0) { exit 1 }

$name = Split-Path -Leaf $src
if (-not (us_safe_name $name)) { exit 1 }

if (-not (Test-Path -LiteralPath (Join-Path $script:US_ME_DIR '.git'))) {
    us_err "error: your skills repo is missing: $script:US_ME_DIR (run the installer first)"
    exit 1
}

$dest = Join-Path $script:US_ME_DIR $name
us_copy_tree $src $dest

# `add -A` stages the whole repo, not just what was copied - so anything a previous direct
# edit left behind would ride along. Roll the copy back rather than commit it.
& $scanner -Quiet $script:US_ME_DIR
if ($LASTEXITCODE -ne 0) {
    Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

& git -C $script:US_ME_DIR add -A
if ($LASTEXITCODE -ne 0) { us_exit 'error: git add failed' }
& git -C $script:US_ME_DIR diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    us_err "no change - '$name' is already shared"
    exit 0
}

$commit = 'share ' + $name
if ($Message) { $commit += ': ' + $Message }
& git -C $script:US_ME_DIR commit -m $commit
if ($LASTEXITCODE -ne 0) { us_exit 'error: git commit failed' }
& git -C $script:US_ME_DIR branch -M main
& git -C $script:US_ME_DIR push -u origin main
if ($LASTEXITCODE -ne 0) { us_exit 'error: git push failed' }

$origin = [string](& git -C $script:US_ME_DIR remote get-url origin)
Write-Output "shared '$name' to $origin"
