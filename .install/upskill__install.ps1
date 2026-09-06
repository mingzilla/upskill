# upskill__install.ps1 - build a machine's upskill__skills_lib tree and install the skill.
#
# The skill itself is NOT part of skills_lib: it is cloned straight into
# %USERPROFILE%\.claude\skills\upskill, the one canonical copy on any machine. Every other agent
# gets a JUNCTION to it - claude is the setup folder even for someone who does not use Claude - so
# there is never per-agent logic, only one link per agent.
#
# Junctions, not symlinks: a standard user can create a junction with no admin rights, and cannot
# create a symlink at all.
#
# usage: powershell -NoProfile -ExecutionPolicy Bypass -File upskill__install.ps1
#          [-AddressBook <url|path>] [-Root <dir>] [-User <name>] [-Branch <name>] [-SkipLink]
param(
    [string]$AddressBook = $env:UP_SKILL_ADDRESS_BOOK,
    [string]$Root = '',
    [string]$User = $env:UP_SKILL_USER,
    [string]$Core = 'https://github.com/mingzilla/upskill.git',
    [string]$Branch = 'prod',
    [switch]$SkipLink
)

$ErrorActionPreference = 'Stop'
$script:SKILL_DIR = Join-Path $env:USERPROFILE '.claude\skills\upskill'
$script:AB_RAW = ''
$script:ME_KEY = ''
$script:ME_REPO = ''

function ins_err([string]$m) { [Console]::Error.WriteLine($m) }
# a function's uncaptured output IS its return value, so any function whose result is tested must
# print through here rather than emitting bare strings
function ins_say([string]$m) { [Console]::Out.WriteLine($m) }
function ins_exit([string]$m) { ins_err $m; exit 1 }

# git writes progress and errors to stderr, and with $ErrorActionPreference='Stop' PowerShell turns
# that into a terminating error even on success. Every git call goes through here: output swallowed,
# the exit code returned, nothing thrown.
function ins_git {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & git @args 2>&1 | Out-Null
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
}

function ins_require {
    foreach ($t in @('git')) {
        if (-not (Get-Command $t -ErrorAction SilentlyContinue)) {
            ins_exit "error: '$t' is not installed, and upskill needs it"
        }
    }
}

function ins_ask([string]$question, [string]$default = '') {
    $hint = if ($default) { " [$default]" } else { '' }
    $a = Read-Host "$question$hint"
    if ([string]::IsNullOrWhiteSpace($a)) { $default } else { $a }
}

function ins_fetch_address_book {
    if (-not $AddressBook) { $script:AddressBook = ins_ask 'Address book url' }
    if (-not $AddressBook) { ins_exit 'error: an address book is required (-AddressBook or UP_SKILL_ADDRESS_BOOK)' }
    if (Test-Path -LiteralPath $AddressBook) {
        $script:AB_RAW = Get-Content -LiteralPath $AddressBook -Raw
    } else {
        # a github page url returns html; only the raw url returns the json
        $url = $AddressBook -replace 'github\.com/([^/]+)/([^/]+)/(blob|tree)/', 'raw.githubusercontent.com/$1/$2/'
        try { $script:AB_RAW = (Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop).Content }
        catch { ins_exit "error: cannot download the address book: $url" }
    }
    try { $d = $script:AB_RAW | ConvertFrom-Json } catch { ins_exit "error: not valid json: $AddressBook" }
    if (-not $d.users) { ins_exit "error: not an address book (no `"users`"): $AddressBook" }
}

# your entry names your public_skills repo - without it there is nothing to share to, so stop
function ins_pick_user {
    $d = $script:AB_RAW | ConvertFrom-Json
    $rows = @($d.users.PSObject.Properties | ForEach-Object {
        [pscustomobject]@{ Key = $_.Name
                           Name = $(if ($_.Value.name) { $_.Value.name } else { $_.Name })
                           Repo = $_.Value.repo }
    })
    $names = ($rows | ForEach-Object { $_.Name } | Sort-Object) -join ' '
    if (-not $User) { $script:User = ins_ask "Your name - this book lists: $names" }
    $w = "$User".Trim().ToLowerInvariant()
    $hits = @($rows | Where-Object { $_.Name.ToLowerInvariant() -eq $w -or $_.Key.ToLowerInvariant() -eq $w })
    if ($hits.Count -gt 1) {
        ins_err "error: '$User' matches more than one entry: $(($hits | ForEach-Object { $_.Key }) -join ', ')"
        ins_exit '  re-run with -User <one of those keys>'
    }
    if ($hits.Count -eq 0 -or -not $hits[0].Repo) {
        ins_err "error: '$User' is not in this address book, so your public_skills repo is unknown"
        ins_err "  the book lists: $names"
        ins_exit '  create your repos first - see .install\guide__create_public_skills\README.md'
    }
    $script:ME_KEY = $hits[0].Key
    $script:ME_REPO = $hits[0].Repo
}

# check every remote before a single folder is made: a bad url must leave the machine untouched
function ins_preflight {
    if ((ins_git ls-remote --heads $script:ME_REPO) -ne 0) {
        ins_err "error: cannot reach your skills repo: $($script:ME_REPO)"
        ins_exit '  create it first - see .install\guide__create_public_skills\README.md'
    }
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $heads = & git ls-remote --heads $Core $Branch 2>$null
    $ErrorActionPreference = $prev
    if (-not $heads) { ins_exit "error: branch '$Branch' not found in $Core" }
}

function ins_pick_root {
    if ($Root) { return }
    $suggested = Join-Path $env:USERPROFILE 'code\upskill__skills_lib'
    ''
    'Where should upskill__skills_lib live? Your skills and repos are kept there.'
    "  1. $suggested"
    $drives = @(Get-PSDrive -PSProvider FileSystem |
                Where-Object { $_.Name.Length -eq 1 -and $_.Name -ne 'C' } |
                ForEach-Object { $_.Name })
    $opt = 2
    $map = @{ '1' = $suggested }
    foreach ($d in $drives) {
        $p = "${d}:\code\upskill__skills_lib"
        "  $opt. $p"
        $map["$opt"] = $p
        $opt++
    }
    '  or type a path'
    $answer = ins_ask 'Choice' '1'
    $script:Root = if ($map.ContainsKey($answer)) { $map[$answer] } else { $answer }
    if (-not $script:Root) { ins_exit 'error: no root chosen' }
}

function ins_make_tree {
    foreach ($d in @('private_files', 'upskill__address_book', 'upskill__sandbox\.claude\skills')) {
        New-Item -ItemType Directory -Force -Path (Join-Path $Root $d) | Out-Null
    }
    # keys live here and must never reach a repo, even if someone runs git init at the root
    $gi = Join-Path $Root '.gitignore'
    if (-not (Test-Path -LiteralPath $gi) -or -not (Select-String -LiteralPath $gi -Pattern '^private_files/' -Quiet)) {
        Add-Content -LiteralPath $gi -Value 'private_files/'
    }
}

# keep what is already there; a re-run must never discard work.
# -Optional means "never ask anybody anything": credential.interactive=false stops Git Credential
# Manager opening a WINDOW (GIT_TERMINAL_PROMPT only silences the terminal, not the GUI), while
# stored credentials still work - so a private repo clones silently or is skipped, never hangs.
function ins_clone([string]$dir, [string]$url, [string]$label, [switch]$Optional) {
    if (Test-Path -LiteralPath (Join-Path $dir '.git')) { ins_say "  keep   $label (already cloned)"; return $true }
    if (Test-Path -LiteralPath $dir) { ins_err "  skip   $label - '$dir' exists but is not a git clone"; return $true }
    $code = if ($Optional) {
        ins_git -c credential.interactive=false clone --quiet $url $dir
    } else {
        ins_git clone --quiet $url $dir
    }
    if ($code -ne 0) { ins_err "  FAILED $label ($url)"; return $false }
    ins_say "  clone  $label"
    return $true
}

function ins_clone_repos {
    ''
    '-- repos:'
    if (-not (ins_clone (Join-Path $Root 'public_skills') $script:ME_REPO 'public_skills')) { exit 1 }
    # the guide asks for both repos at once, so try the matching private one and move on if absent.
    # private_skills is private by definition: without GIT_TERMINAL_PROMPT=0 an https clone stops
    # and waits for a username, which would hang the whole install on an optional repo.
    $privateUrl = $script:ME_REPO -replace 'public_skills\.git$', 'private_skills.git'
    if ($privateUrl -ne $script:ME_REPO) {
        $oldT = $env:GIT_TERMINAL_PROMPT; $oldG = $env:GCM_INTERACTIVE
        $env:GIT_TERMINAL_PROMPT = '0'; $env:GCM_INTERACTIVE = 'never'
        if (-not (ins_clone (Join-Path $Root 'private_skills') $privateUrl 'private_skills' -Optional)) {
            Remove-Item -LiteralPath (Join-Path $Root 'private_skills') -Recurse -Force -ErrorAction SilentlyContinue
            ins_err '  note: private_skills was not cloned (not created yet, or it needs a login) - nothing else is affected'
        }
        $env:GIT_TERMINAL_PROMPT = $oldT; $env:GCM_INTERACTIVE = $oldG
    }
}

# ~\.claude\skills\upskill is the install. A link there is someone developing upskill against
# their own checkout - never disturb it.
function ins_is_link([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return $false }
    ((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
}

function ins_install_skill {
    ''
    '-- skill:'
    if (ins_is_link $script:SKILL_DIR) {
        "  keep   $($script:SKILL_DIR) -> $((Get-Item -LiteralPath $script:SKILL_DIR -Force).Target) (a development link)"
        return
    }
    if (Test-Path -LiteralPath (Join-Path $script:SKILL_DIR '.git')) {
        "  keep   $($script:SKILL_DIR) (already installed)"
        return
    }
    if (Test-Path -LiteralPath $script:SKILL_DIR) {
        ins_err "error: $($script:SKILL_DIR) exists but is not a git clone"
        ins_exit '  move it aside and re-run - it would be overwritten by every update'
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $script:SKILL_DIR) | Out-Null
    if ((ins_git clone --quiet -b $Branch $Core $script:SKILL_DIR) -ne 0) {
        ins_exit "  FAILED upskill ($Core branch $Branch)"
    }
    "  clone  $($script:SKILL_DIR) ($Branch)"
}

function ins_place_address_book {
    $script:AB_RAW | Set-Content -LiteralPath (Join-Path $Root 'upskill__address_book\address_book.json') -NoNewline -Encoding UTF8
}

function ins_write_config {
    $cfg = [pscustomobject]@{
        skills_lib_root = $Root
        address_book    = './upskill__address_book/address_book.json'
    }
    ($cfg | ConvertTo-Json) + "`n" | Set-Content -LiteralPath (Join-Path $script:SKILL_DIR 'upskill__user_config.json') -NoNewline -Encoding UTF8
}

# Other agents read from their own folder, so each gets a junction to the one real copy. Claude is
# the setup folder whether or not Claude is installed: a link costs nothing and works the day it is.
# New-Item -Force does NOT re-point an existing junction, so an existing one is removed first -
# safe, because deleting a junction never touches its target.
function ins_link_agents {
    if ($SkipLink) { ''; '-- other agents: skipped (-SkipLink)'; return }
    ''
    '-- other agents:'
    foreach ($rel in @('.codex\skills', '.agent\skills')) {
        $root = Join-Path $env:USERPROFILE $rel
        $link = Join-Path $root 'upskill'
        if ((Test-Path -LiteralPath $link) -and -not (ins_is_link $link)) {
            ins_err "  skip   $link is a real folder, not a link - move it and re-run"
            continue
        }
        New-Item -ItemType Directory -Force -Path $root | Out-Null
        if (Test-Path -LiteralPath $link) { [IO.Directory]::Delete($link, $false) }
        try {
            New-Item -ItemType Junction -Path $link -Target $script:SKILL_DIR -ErrorAction Stop | Out-Null
            "  link   $link"
        } catch {
            # a filesystem with no reparse points - copy instead, and say what that costs
            Copy-Item -LiteralPath $script:SKILL_DIR -Destination $link -Recurse -Force
            ins_err "  copied $link (junctions unavailable here - re-run the installer to update it)"
        }
    }
}

function ins_report {
    ''
    '== done =='
    "  you       $User  ($($script:ME_KEY))"
    "  root      $Root"
    "  skill     $($script:SKILL_DIR)"
    "  share to  $($script:ME_REPO)"
    ''
    'say: use upskill to share a skill, or get one from someone'
}

ins_require
ins_fetch_address_book
ins_pick_user
ins_preflight
ins_pick_root
ins_make_tree
ins_clone_repos
ins_install_skill
ins_place_address_book
ins_write_config
ins_link_agents
ins_report
