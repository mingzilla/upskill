# upskill__uninstall.ps1 - remove upskill from this machine's agents.
#
# This runs on someone else's computer, so nothing is deleted on the strength of a path. Every
# removal is proved first: a link must BE a link and point where we expect; the real install must
# BE a git clone of the upskill repo. Anything that fails a check is left alone and reported.
#
# Your skills_lib tree - repos, sandbox, private files - is never touched.
param()

$CORE_REPO  = 'mingzilla/upskill'
$SKILL_DIR  = Join-Path $env:USERPROFILE '.claude\skills\upskill'
$AGENT_LINKS = @(
    (Join-Path $env:USERPROFILE '.codex\skills\upskill'),
    (Join-Path $env:USERPROFILE '.agent\skills\upskill')
)
$script:ROOT = ''

function uns_err([string]$m) { [Console]::Error.WriteLine($m) }

# read the config before anything is removed, so the report can still say where the skills are
function uns_find_root {
    $cfg = Join-Path $SKILL_DIR 'upskill__user_config.json'
    if (-not (Test-Path -LiteralPath $cfg)) { return }
    try { $script:ROOT = (Get-Content -LiteralPath $cfg -Raw | ConvertFrom-Json).skills_lib_root } catch { }
}

# owner/repo from either git@host:owner/repo.git or https://host/owner/repo.git
function uns_norm_repo([string]$u) {
    if (-not $u) { return '' }
    $u = $u.Trim().TrimEnd('/')
    if ($u.EndsWith('.git')) { $u = $u.Substring(0, $u.Length - 4) }
    foreach ($p in @('git@', 'https://', 'http://', 'ssh://')) { $u = $u.Replace($p, '') }
    $parts = ($u -replace ':', '/') -split '/' | Where-Object { $_ }
    (($parts | Select-Object -Last 2) -join '/').ToLowerInvariant()
}

function uns_is_link([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return $false }
    ((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
}

# delete it only when it is a link named upskill pointing at SKILL_DIR
function uns_remove_link([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return "  absent   $p" }
    if (-not (uns_is_link $p)) { uns_err "  REFUSED  $p is a real folder, not a link - left alone"; return }
    if ((Split-Path -Leaf $p) -ne 'upskill') { uns_err "  REFUSED  $p is not named upskill - left alone"; return }
    $target = @((Get-Item -LiteralPath $p -Force).Target)[0]
    $normT = try { [IO.Path]::GetFullPath($target).TrimEnd('\') } catch { $target }
    $normE = try { [IO.Path]::GetFullPath($SKILL_DIR).TrimEnd('\') } catch { $SKILL_DIR }
    if ($normT -ne $normE) { uns_err "  REFUSED  $p points at $normT, not $normE - left alone"; return }
    # non-recursive by construction: it removes the reparse point and cannot descend into the target
    [IO.Directory]::Delete($p, $false)
    "  removed  $p"
}

# delete the install only when it is provably our clone
function uns_remove_install {
    if (uns_is_link $SKILL_DIR) {
        # a development link to someone's own checkout - remove the link, never their work
        [IO.Directory]::Delete($SKILL_DIR, $false)
        return "  removed  $SKILL_DIR (was a development link)"
    }
    if (-not (Test-Path -LiteralPath $SKILL_DIR)) { return "  absent   $SKILL_DIR" }
    $expected = Join-Path $env:USERPROFILE '.claude\skills'
    if ((Split-Path -Leaf $SKILL_DIR) -ne 'upskill' -or (Split-Path -Parent $SKILL_DIR) -ne $expected) {
        uns_err "  REFUSED  $SKILL_DIR is not where upskill installs - left alone"; return
    }
    if (-not (Test-Path -LiteralPath (Join-Path $SKILL_DIR '.git'))) {
        uns_err "  REFUSED  $SKILL_DIR is not a git clone - left alone"
        uns_err '           delete it yourself if you are sure it is upskill'
        return
    }
    $origin = & git -c safe.directory='*' -C $SKILL_DIR remote get-url origin 2>$null
    if ((uns_norm_repo $origin) -ne (uns_norm_repo $CORE_REPO)) {
        uns_err "  REFUSED  $SKILL_DIR is a clone of '$origin', not $CORE_REPO - left alone"; return
    }
    Remove-Item -LiteralPath $SKILL_DIR -Recurse -Force
    "  removed  $SKILL_DIR"
}

uns_find_root
'-- other agents:'
foreach ($p in $AGENT_LINKS) { uns_remove_link $p }
''
'-- the skill:'
uns_remove_install
''
'== done =='
if ($script:ROOT) { "  your skills are untouched at: $($script:ROOT)" }
'  re-install by running upskill__install.ps1 again'
