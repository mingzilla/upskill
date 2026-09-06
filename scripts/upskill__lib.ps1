# upskill__lib.ps1 - shared helpers. Dot-sourced, never executed:
#   . "$PSScriptRoot\upskill__lib.ps1" ; us_init
#
# The skill folder IS the git repo, and the config sits inside it - so nothing is searched for.
# Unlike the bash twin this needs no python: PowerShell reads json natively.

$script:US_SKILL_DIR = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$script:US_ROOT      = ''   # skills_lib_root from the config
$script:US_AB_JSON   = ''   # active address book
$script:US_POOL      = ''   # <root>\upskill__address_book - one clone per member repo
$script:US_ME_DIR    = ''   # <root>\public_skills - the only repo I write to
$script:US_SANDBOX   = ''   # <root>\upskill__sandbox

function us_err([string]$m) { [Console]::Error.WriteLine($m) }
function us_exit([string]$m) { us_err $m; exit 1 }

# being on PATH is not proof: Windows ships stubs that resolve and then fail to run
function us_require([string]$tool) {
    $cmd = Get-Command $tool -ErrorAction SilentlyContinue
    if (-not $cmd) { us_exit "error: '$tool' is not installed, and upskill needs it" }
}

function us_load_config {
    $cfg = Join-Path $script:US_SKILL_DIR 'upskill__user_config.json'
    if (-not (Test-Path -LiteralPath $cfg)) {
        us_err "error: not configured - $cfg is missing"
        us_exit "  run the installer: .install\upskill__install.ps1"
    }
    $d = Get-Content -LiteralPath $cfg -Raw | ConvertFrom-Json
    $script:US_ROOT = $d.skills_lib_root
    $rel = ($d.address_book -replace '^\./', '') -replace '/', '\'
    $script:US_AB_JSON = Join-Path $script:US_ROOT $rel
    $script:US_POOL    = Join-Path $script:US_ROOT 'upskill__address_book'
    $script:US_ME_DIR  = Join-Path $script:US_ROOT 'public_skills'
    $script:US_SANDBOX = Join-Path $script:US_ROOT 'upskill__sandbox'
}

function us_init {
    us_require git
    us_load_config
    if (-not (Test-Path -LiteralPath $script:US_ROOT)) {
        us_exit "error: skills_lib_root does not exist: $($script:US_ROOT)"
    }
    if (-not (Test-Path -LiteralPath $script:US_AB_JSON)) {
        us_exit "error: address book not found: $($script:US_AB_JSON)"
    }
}

# us_members - one row per member, ordered by display name.
# The order is not cosmetic: the user picks by the number shown, so every listing must agree with
# the bash twin - hence an ordinal sort, not a culture-dependent one.
function us_members {
    $ab = Get-Content -LiteralPath $script:US_AB_JSON -Raw | ConvertFrom-Json
    $rows = @()
    foreach ($p in $ab.users.PSObject.Properties) {
        $name = if ($p.Value.name) { $p.Value.name } else { $p.Name }
        $rows += [pscustomobject]@{ Key = $p.Name; Name = $name; Repo = $p.Value.repo }
    }
    $rows | Sort-Object @{ Expression = { $_.Name.ToLowerInvariant() } }, @{ Expression = { $_.Key } }
}

# us_key_of <name-or-key> - the address book key for a member.
# Two members may share a display name (the key is the repo, the name is only an alias), so an
# ambiguous name is reported rather than guessed.
function us_key_of([string]$want) {
    $w = $want.Trim().ToLowerInvariant()
    $hits = @(us_members | Where-Object { $_.Name.ToLowerInvariant() -eq $w -or $_.Key.ToLowerInvariant() -eq $w })
    if ($hits.Count -eq 0) {
        us_err "error: '$want' is not in the address book"
        us_err ("  members: " + ((us_members | ForEach-Object { $_.Name }) -join ', '))
        return $null
    }
    if ($hits.Count -gt 1) {
        us_err ("error: '$want' matches more than one member: " + (($hits | ForEach-Object { $_.Key }) -join ', '))
        us_err '  say which one by its full key'
        return $null
    }
    $hits[0].Key
}

function us_repo_of([string]$key) { (us_members | Where-Object { $_.Key -eq $key }).Repo }
function us_name_of([string]$key) {
    $m = us_members | Where-Object { $_.Key -eq $key }
    if ($m) { $m.Name } else { $key }
}

# us_pool_dir <key> - where that member's repo is cloned
function us_pool_dir([string]$key) { Join-Path $script:US_POOL $key }

# us_sync_repo <key> - clone it if missing, otherwise pull. Never re-clones: an existing local copy
# is the user's, and re-cloning would throw away anything they did to it.
function us_sync_repo([string]$key) {
    $dir = us_pool_dir $key
    if (Test-Path -LiteralPath (Join-Path $dir '.git')) {
        & git -c safe.directory='*' -C $dir pull --ff-only --quiet 2>$null
        if ($LASTEXITCODE -ne 0) { us_err "note: could not update $(us_name_of $key) - showing the local copy" }
        return $true
    }
    $url = us_repo_of $key
    if (-not $url) { us_err "error: no repo url for '$key'"; return $false }
    & git clone --quiet $url $dir 2>$null
    if ($LASTEXITCODE -ne 0) { us_err "error: cannot clone $url"; return $false }
    return $true
}

# us_my_key - my own address book key, matched by the origin url of public_skills.
# Identity comes from the repo I can push to, not from a name in the config: nothing to keep in sync.
function us_my_key {
    $origin = & git -c safe.directory='*' -C $script:US_ME_DIR remote get-url origin 2>$null
    if (-not $origin) { return $null }
    $norm = { param($u)
        # ssh (git@host:owner/repo.git) and https (https://host/owner/repo.git) name the same repo
        $u = $u.Trim().TrimEnd('/')
        if ($u.EndsWith('.git')) { $u = $u.Substring(0, $u.Length - 4) }
        foreach ($p in @('git@', 'https://', 'http://', 'ssh://')) { $u = $u.Replace($p, '') }
        $parts = ($u -replace ':', '/') -split '/' | Where-Object { $_ }
        (($parts | Select-Object -Last 2) -join '/').ToLowerInvariant()
    }
    $want = & $norm $origin
    foreach ($m in us_members) { if ((& $norm $m.Repo) -eq $want) { return $m.Key } }
    return $null
}

# us_validate_skill <skill-dir> - refuse a skill that would install but never load.
# Only checks failures that are otherwise SILENT: broken frontmatter or a missing description means
# the skill is simply never triggered, and the user concludes upskill is broken.
function us_validate_skill([string]$dir) {
    $md = Join-Path $dir 'SKILL.md'
    if (-not (Test-Path -LiteralPath $md)) {
        us_err "error: not a skill folder (no SKILL.md): $dir"
        return $false
    }
    $lines = @(Get-Content -LiteralPath $md)
    $problems = @()
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') {
        $problems += 'the file must start with a --- frontmatter block'
    } else {
        $close = -1
        for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq '---') { $close = $i; break } }
        if ($close -lt 0) {
            $problems += 'the frontmatter block is never closed with ---'
        } else {
            $block = $lines[1..($close - 1)]
            if (-not ($block | Where-Object { $_ -match '^name:\s*\S' })) { $problems += "frontmatter has no 'name:'" }
            if (-not ($block | Where-Object { $_ -match '^description:\s*\S' })) {
                $problems += "frontmatter has no 'description:' - without it an agent never triggers the skill"
            }
        }
    }
    if ($problems.Count -gt 0) {
        us_err "error: '$(Split-Path -Leaf $dir)' cannot be shared - it would install but never load:"
        foreach ($p in $problems) { us_err "  - $p" }
        us_err "  fix $md and try again."
        return $false
    }
    return $true
}

# us_skill_names <dir> - immediate child folders holding a SKILL.md, ordinally sorted so bash and
# PowerShell number the same list identically - the user picks by number.
function us_skill_names([string]$dir) {
    if (-not (Test-Path -LiteralPath $dir)) { return @() }
    $names = @(Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue |
               Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } |
               ForEach-Object { $_.Name })
    if ($names.Count -eq 0) { return @() }
    [Array]::Sort($names, [StringComparer]::Ordinal)
    return $names
}

# us_safe_name <name> - reject empty / pathy / dot-dot names before they reach a filesystem path
function us_safe_name([string]$n) {
    if ([string]::IsNullOrWhiteSpace($n) -or $n -match '[\\/]' -or $n -match '\.\.') {
        us_err "error: not a valid name: '$n'"
        return $false
    }
    return $true
}
