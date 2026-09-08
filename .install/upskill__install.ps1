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
#          [-AddressBook <url|path>] [-Root <dir>] [-User <name>] [-Repo <url>]
#          [-Branch <name>] [-SkipLink]
#   -AddressBook    when omitted the starter book on github main is used, so one command always works
#   -Root           where upskill__skills_lib lives; prompted when omitted
#   -User           your display name; prompted when omitted
#   -Repo           your public_skills repo url; prompted when omitted
param(
    [string]$AddressBook = $env:UP_SKILL_ADDRESS_BOOK,
    [string]$Root = '',
    [string]$User = $env:UP_SKILL_USER,
    [string]$Repo = '',
    [string]$Core = 'https://github.com/mingzilla/upskill.git',
    [string]$Branch = 'prod',
    [switch]$SkipLink,
    [switch]$SkipAuthCheck
)

$ErrorActionPreference = 'Stop'
$script:SKILL_DIR = Join-Path $env:USERPROFILE '.claude\skills\upskill'
$script:AB_SRC    = $AddressBook
$script:USER_IN   = $User
$script:ROOT_IN   = $Root
$script:AB_DEFAULT = 'https://raw.githubusercontent.com/mingzilla/upskill/main/.install/guide__install/address_book__starter.json'
$script:AB_RAW = ''
$script:ME_REPO = $Repo
$script:IS_DEV_LINK = $false

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
    # no address book given: start everyone from the same starter book, so one command always works
    if (-not $script:AB_SRC) { $script:AB_SRC = $script:AB_DEFAULT }
    if (Test-Path -LiteralPath $script:AB_SRC) {
        $script:AB_RAW = Get-Content -LiteralPath $script:AB_SRC -Raw
    } else {
        # a github page url returns html; only the raw url returns the json
        $url = $script:AB_SRC -replace 'github\.com/([^/]+)/([^/]+)/(blob|tree)/', 'raw.githubusercontent.com/$1/$2/'
        try { $script:AB_RAW = (Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop).Content }
        catch { ins_exit "error: cannot download the address book: $url" }
    }
    try { $d = $script:AB_RAW | ConvertFrom-Json } catch { ins_exit "error: not valid json: $($script:AB_SRC)" }
    if (-not $d.users) { ins_exit "error: not an address book (no `"users`"): $($script:AB_SRC)" }
}

# who you are is asked for, never read from the book. The address book names the people you can
# receive from - it says nothing about you, and you are not required to be in it. You always say
# your display name and your public_skills repo; private_skills is derived from the repo below.
function ins_ask_identity {
    if (-not $script:USER_IN) { $script:USER_IN = ins_ask 'Your name (as shown to people you share with)' }
    if (-not $script:ME_REPO) { $script:ME_REPO = ins_ask 'Your public_skills repo (https://github.com/<you>/public_skills.git)' }
    if (-not $script:USER_IN) {
        ins_err 'error: no name given - pass -User <name> or answer the prompt'
        exit 1
    }
    if (-not $script:ME_REPO) {
        ins_err 'error: no public_skills repo given - pass -Repo <url> or answer the prompt'
        ins_exit '  create it first - see .install\guide__create_public_skills\README.md'
    }
}

# normalise git@host:owner/repo.git and https://host/owner/repo.git to host/owner/repo
function ins_norm_repo([string]$url) {
    if (-not $url) { return '' }
    $u = $url.Trim().TrimEnd('/')
    if ($u.EndsWith('.git')) { $u = $u.Substring(0, $u.Length - 4) }
    $u = $u.Replace('git@', '')
    foreach ($p in @('https://', 'http://', 'ssh://')) { $u = $u.Replace($p, '') }
    $u.Replace(':', '/')
}

# your own repo is yours alone. If the loaded book also lists it (the starter book lists ming's),
# that entry would present you as someone to receive from, under a name that is not yours - the
# config now carries the truth. Drop any book entry whose repo is your repo before it is written.
function ins_drop_self {
    $mine = ins_norm_repo $script:ME_REPO
    if (-not $mine) { return }
    $d = $script:AB_RAW | ConvertFrom-Json
    $keep = [ordered]@{}
    $dropped = 0
    if ($d.users) {
        foreach ($p in $d.users.PSObject.Properties) {
            if ((ins_norm_repo $p.Value.repo) -eq $mine) { $dropped++ } else { $keep[$p.Name] = $p.Value }
        }
    }
    if ($dropped -gt 0) {
        $text = ([ordered]@{ users = $keep } | ConvertTo-Json -Depth 20) + "`n"
        $script:AB_RAW = $text
    }
}

# Being logged in is not optional. Cloning private_skills needs it, and sharing - the whole point -
# pushes to github. Without it the install "succeeds" and every later share fails at the push, which
# is a far worse place to discover it. Checked before anything is created.
function ins_check_github_auth {
    if ($SkipAuthCheck) { return }
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        & gh auth status --hostname github.com 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { return }
    } else {
        # no gh: accept a credential helper that already holds a github password
        $old = $env:GIT_TERMINAL_PROMPT
        $env:GIT_TERMINAL_PROMPT = '0'
        $out = "protocol=https`nhost=github.com`n`n" | & git -c credential.interactive=false credential fill 2>$null
        $env:GIT_TERMINAL_PROMPT = $old
        if ($out -match '^password=') { return }
    }
    ins_err 'error: you are not logged in to github'
    ins_err '  upskill clones your private_skills and pushes every skill you share, so a login is'
    ins_err '  required now rather than at the first failed share.'
    ins_err ''
    ins_err '  run this, then run the installer again:'
    ins_err '    gh auth login --hostname github.com --git-protocol https'
    ins_err ''
    ins_exit '  (no gh? install it from https://cli.github.com, or configure a git credential helper)'
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
    if ($script:ROOT_IN) { return }
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
    $script:ROOT_IN = if ($map.ContainsKey($answer)) { $map[$answer] } else { $answer }
    if (-not $script:ROOT_IN) { ins_exit 'error: no root chosen' }
}

function ins_make_tree {
    foreach ($d in @('private_files', 'upskill__address_book', 'upskill__sandbox\.claude\skills')) {
        New-Item -ItemType Directory -Force -Path (Join-Path $script:ROOT_IN $d) | Out-Null
    }
    # keys live here and must never reach a repo, even if someone runs git init at the root
    $gi = Join-Path $script:ROOT_IN '.gitignore'
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
    if (-not (ins_clone (Join-Path $script:ROOT_IN 'public_skills') $script:ME_REPO 'public_skills')) { exit 1 }
    # public_skills.git is asked for, so the matching private one is derived from it and cloned only
    # if it exists. private_skills is private by definition: without GIT_TERMINAL_PROMPT=0 an https
    # clone stops and waits for a username, which would hang the whole install on an optional repo.
    $privateUrl = $script:ME_REPO -replace 'public_skills\.git$', 'private_skills.git'
    if ($privateUrl -ne $script:ME_REPO) {
        $oldT = $env:GIT_TERMINAL_PROMPT; $oldG = $env:GCM_INTERACTIVE
        $env:GIT_TERMINAL_PROMPT = '0'; $env:GCM_INTERACTIVE = 'never'
        if (-not (ins_clone (Join-Path $script:ROOT_IN 'private_skills') $privateUrl 'private_skills' -Optional)) {
            Remove-Item -LiteralPath (Join-Path $script:ROOT_IN 'private_skills') -Recurse -Force -ErrorAction SilentlyContinue
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
        $script:IS_DEV_LINK = $true
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
    ins_drop_self
    # write UTF-8 without a BOM - the book is read by the bash/python side (WSL), which rejects a BOM
    [System.IO.File]::WriteAllText((Join-Path $script:ROOT_IN 'upskill__address_book\address_book.json'), $script:AB_RAW, (New-Object System.Text.UTF8Encoding($false)))
}

function ins_write_config {
    # A development link points at somebody's own checkout, and its config is their working setup.
    # Writing ours into it would silently repoint their environment at this install's root - a
    # change they never asked for and would not see until something later failed.
    if ($script:IS_DEV_LINK) {
        ''
        '-- config: kept (the skill is a development link, so its config is left alone)'
        $t = (Get-Item -LiteralPath $script:SKILL_DIR -Force).Target
        "   to use this root there, set in $t\upskill__user_config.json:"
        "     `"my_name`": `"$($script:USER_IN)`", `"my_public_skills_repo`": `"$($script:ME_REPO)`","
        "     `"skills_lib_root`": `"$($script:ROOT_IN)`""
        return
    }
    $cfg = [ordered]@{
        my_name               = $script:USER_IN
        my_public_skills_repo = $script:ME_REPO
        skills_lib_root       = $script:ROOT_IN
        address_book          = './upskill__address_book/address_book.json'
    }
    $cfgText = ($cfg | ConvertTo-Json) + "`n"
    [System.IO.File]::WriteAllText((Join-Path $script:SKILL_DIR 'upskill__user_config.json'), $cfgText, (New-Object System.Text.UTF8Encoding($false)))
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
    "  you       $($script:USER_IN)"
    "  root      $($script:ROOT_IN)"
    "  skill     $($script:SKILL_DIR)"
    "  share to  $($script:ME_REPO)"
    ''
    'say: use upskill to share a skill, or get one from someone'
}

ins_require
ins_check_github_auth
ins_fetch_address_book
ins_ask_identity
ins_preflight
ins_pick_root
ins_make_tree
ins_clone_repos
ins_install_skill
ins_place_address_book
ins_write_config
ins_link_agents
ins_report
