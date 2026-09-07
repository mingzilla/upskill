# upskill__share.ps1 - copy one of my skills into public_skills and push it.
# usage: upskill__share.ps1 <skill-folder> [message]
param(
    [Parameter(Position = 0)][string]$Skill,
    [Parameter(Position = 1)][string]$Message = ''
)

. (Join-Path $PSScriptRoot '..\..\..\scripts\upskill__lib.ps1')

us_init

if ([string]::IsNullOrWhiteSpace($Skill)) { us_exit 'usage: upskill__share.ps1 <skill-folder|skill-name> [message]' }

# a skill can be named rather than pathed, so look where a person actually keeps them
if (Test-Path -LiteralPath $Skill -PathType Container) {
    $src = (Resolve-Path -LiteralPath $Skill).Path
} else {
    if (-not (us_safe_name $Skill)) { exit 1 }
    $found = @()
    $here = Join-Path (Get-Location).Path ".claude\skills\$Skill"
    if (Test-Path -LiteralPath $here) { $found += $here }
    $priv = Join-Path $script:US_ROOT 'private_skills'
    foreach ($c in @((Join-Path $priv $Skill))) { if (Test-Path -LiteralPath $c) { $found += $c } }
    if (Test-Path -LiteralPath $priv) {
        $found += @(Get-ChildItem -LiteralPath $priv -Directory -ErrorAction SilentlyContinue |
                    ForEach-Object { Join-Path $_.FullName ".claude\skills\$Skill" } |
                    Where-Object { Test-Path -LiteralPath $_ })
    }
    $found = @($found | Select-Object -Unique)
    if ($found.Count -eq 0) {
        us_err "error: skill not found: '$Skill'"
        us_exit '  give a folder path, or a skill name in this project or in private_skills'
    }
    if ($found.Count -gt 1) {
        us_err "error: '$Skill' matches more than one folder - share it by path:"
        foreach ($f in $found) { us_err "  $f" }
        exit 1
    }
    $src = $found[0]
}

$name = Split-Path -Leaf $src
if (-not (us_safe_name $name)) { exit 1 }
# a skill only reaches the team if it will actually load for them
if (-not (us_validate_skill $src)) { exit 1 }

# a credential that reaches a public repo is public forever, even after the next commit deletes it
$scanner = Join-Path $PSScriptRoot 'upskill__scan_secrets.ps1'
& $scanner -Quiet $src
if ($LASTEXITCODE -ne 0) { exit 1 }

if (-not (Test-Path -LiteralPath (Join-Path $script:US_ME_DIR '.git'))) {
    us_err "error: your skills repo is missing: $($script:US_ME_DIR)"
    us_exit '  run the installer, or see .install\guide__create_public_skills\README.md'
}

$dest = Join-Path $script:US_ME_DIR $name
if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force

# `add -A` stages the whole repo, not just what was copied, so anything an earlier direct edit left
# behind would ride along. Roll the copy back rather than commit it.
& $scanner -Quiet $script:US_ME_DIR
if ($LASTEXITCODE -ne 0) {
    Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# how many commits exist here but not on the remote. A run can commit and then fail to push - no
# auth yet, offline, a rejected push - and that commit is invisible to `diff --cached`. Without this
# the next share reports "already shared" and the work never reaches anybody.
function share_unpushed {
    $up = & git -c safe.directory='*' -C $script:US_ME_DIR rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
    if (-not $up) { return 1 }   # no upstream yet - treat as pending
    $n = & git -c safe.directory='*' -C $script:US_ME_DIR rev-list --count "$up..HEAD" 2>$null
    if ($n) { return [int]$n } else { return 1 }
}

function share_do_push {
    $up = & git -c safe.directory='*' -C $script:US_ME_DIR rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
    if (-not $up) {
        & git -c safe.directory='*' -C $script:US_ME_DIR push -q -u origin HEAD
    } else {
        & git -c safe.directory='*' -C $script:US_ME_DIR push -q
    }
    return ($LASTEXITCODE -eq 0)
}

$pendingOnly = $false

& git -c safe.directory='*' -C $script:US_ME_DIR add -A
if ($LASTEXITCODE -ne 0) { us_exit 'error: git add failed' }

& git -c safe.directory='*' -C $script:US_ME_DIR diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    # nothing new to commit - but an earlier run may have left a commit stranded
    if ((share_unpushed) -eq 0) {
        "no change - ``$name`` is already shared"
        exit 0
    }
    $pendingOnly = $true
} else {
    $commit = if ($Message) { "share $name`: $Message" } else { "share $name" }
    & git -c safe.directory='*' -C $script:US_ME_DIR commit -q -m $commit
    if ($LASTEXITCODE -ne 0) {
        us_err 'error: commit failed'
        $who = & git -C $script:US_ME_DIR config user.email 2>$null
        if (-not $who) {
            us_err '  git does not know who you are. Set it once:'
            us_err '    git config --global user.name "Your Name"'
            us_err '    git config --global user.email "you@example.com"'
        }
        exit 1
    }
}

if (-not (share_do_push)) {
    us_err "error: push failed - $(share_unpushed) commit(s) are waiting to be uploaded"
    us_exit '  fix your github access, then run the same share again - it will retry the push'
}

# my own listing is read from the pool clone, not from public_skills - without this refresh the
# skill I just shared is missing from "show my skills"
$mine = us_my_key
if ($mine) {
    $pool = us_pool_dir $mine
    if (Test-Path -LiteralPath (Join-Path $pool '.git')) {
        & git -c safe.directory='*' -C $pool pull --ff-only --quiet 2>$null
    }
}

$origin = & git -c safe.directory='*' -C $script:US_ME_DIR remote get-url origin 2>$null
if ($pendingOnly) {
    "``$name`` was already committed but had never been uploaded - it is now on ``$origin``"
} else {
    "``$name`` has been uploaded to ``$origin``"
}
