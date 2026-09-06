# upskill__lib.ps1 - shared helpers for the upskill client scripts (PowerShell).
# Dot-sourced (never run): `. <path>/upskill__lib.ps1`, then call `us_init`.
#
# Resolves the .upskill__workspace (nearest ancestor holding upskill__user-config.json,
# or $env:UP_SKILL_WORKSPACE) and loads the user config + team address book into US_* variables.
#
# PowerShell equivalent of upskill__lib.sh. No python needed here: JSON is read with
# the built-in .NET/JSON support, so the ps1 path only requires git.

# the installed copy this run is executing from: <agent skills dir>\upskill\scripts -> its parent.
# Captured at dot-source time, because that is when $PSScriptRoot points at this file.
$script:US_LIB_DIR = $PSScriptRoot

$ErrorActionPreference = 'Stop'

# US_* state lives in the script scope of whichever command script dot-sources this file.
$script:US_WORKSPACE = ''       # root of this machine's upskill__workspace
$script:US_USER = ''            # this member's name (matches the address book)
$script:US_TEAM = ''            # e.g. team__sandbox
$script:US_ADDRESS_BOOK = ''    # dir of the cloned address-book repo
$script:US_AB_JSON = ''         # path to address_book.json
$script:US_TEAM_DIR = ''        # dir holding the address book + every member's sharing clone
$script:US_ME_FOLDER = ''       # my skills-repo clone folder name, e.g. upskill__skills_repo__leah
$script:US_ME_DIR = ''          # absolute path of my sharing clone

# us_err <message> - write a line to stderr (mirrors bash `>&2`).
function us_err {
    param([string]$Message)
    [Console]::Error.WriteLine($Message)
}

# us_exit <message> <code> - print an error to stderr and exit.
function us_exit {
    param([string]$Message, [int]$Code = 1)
    us_err $Message
    exit $Code
}

# us_require <tool> - abort when a required tool is not on PATH.
function us_require {
    param([string]$Tool)
    if (-not (Get-Command $Tool -ErrorAction SilentlyContinue)) {
        us_exit "error: required tool not found: $Tool"
    }
}

# Read-UpSkillJson <path> - parse a JSON file (.NET auto-detects the encoding/BOM).
function Read-UpSkillJson {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path) | ConvertFrom-Json
}

# us_locate_workspace <start-dir> - nearest ancestor holding upskill__user-config.json; $null if none.
function us_locate_workspace {
    param([string]$Dir)
    $d = $Dir
    if (-not (Test-Path -LiteralPath $d -PathType Container)) { $d = Split-Path -Parent $d }
    while ($d) {
        if (Test-Path -LiteralPath (Join-Path $d 'upskill__user-config.json')) { return $d }
        $parent = Split-Path -Parent $d
        if (-not $parent -or $parent -eq $d) { break }   # drive root reached
        $d = $parent
    }
    return $null
}

# us_load_config - fill the US_* variables from upskill__user-config.json; $true on success.
function us_load_config {
    $cfgPath = Join-Path $script:US_WORKSPACE 'upskill__user-config.json'
    if (-not (Test-Path -LiteralPath $cfgPath)) { return $false }
    $cfg = Read-UpSkillJson $cfgPath
    $script:US_USER = [string]$cfg.user
    if ($null -ne $cfg.team) { $script:US_TEAM = [string]$cfg.team } else { $script:US_TEAM = '' }
    $script:US_ADDRESS_BOOK = Join-Path $script:US_WORKSPACE ([string]$cfg.address_book)
    $script:US_AB_JSON = Join-Path $script:US_ADDRESS_BOOK 'address_book.json'
    $script:US_TEAM_DIR = Split-Path -Parent $script:US_ADDRESS_BOOK
    return $true
}

# us_members - return address-book rows as "name<TAB>folder<TAB>repo" strings.
function us_members {
    $ab = Read-UpSkillJson $script:US_AB_JSON
    $rows = @()
    if ($ab.users) {
        foreach ($p in $ab.users.PSObject.Properties) {
            $rows += [string]::Join("`t", @($p.Name, $p.Value.folder, $p.Value.repo))
        }
    }
    return $rows
}

# us_folder_of <member-name> - that member's sharing-clone folder name; '' when absent.
function us_folder_of {
    param([string]$Member)
    $ab = Read-UpSkillJson $script:US_AB_JSON
    if ($ab.users) {
        $prop = $ab.users.PSObject.Properties | Where-Object { $_.Name -eq $Member }
        if ($prop) { return [string]$prop.Value.folder }
    }
    return ''
}

# us_write_denied <path> - the message for a folder this agent may read but not write.
# Codex runs shell commands as a sandbox account and stamps an explicit Deny on the .codex folders
# it manages, so a folder that accepted the first write can refuse later ones. Nothing upskill does
# can grant that access: the way through is the one Codex's own skill-installer uses - ask the user
# to approve running the command with escalated permissions.
function us_write_denied {
    param([string]$Path)
    return @"
cannot write to $Path
  Adding a skill needs ``Full access`` permission - this agent's sandbox cannot write there.
  Set the permission to ``Full access`` (or approve the escalation prompt) and try again.
  Outside an agent, in a normal terminal window, it works without this step.
"@
}

# us_copy_tree <src> <dest> - make <dest> hold a copy of <src>.
# Never deletes <dest> itself. Two Windows behaviours make that essential: a directory stays alive
# until every handle closes, so deleting it and recreating the same name fails with "Access to the
# path is denied" while an agent watching its skills folder holds one; and Copy-Item cannot replace
# an existing directory - handed one, it copies INSIDE it (dest\name\name). So: create the folder
# only when it is really absent, clear its CONTENTS, and copy the source's contents in. Individual
# files that cannot be replaced are skipped rather than failing the action, and the result is
# checked at the end so a half-copy is reported instead of passing silently.
function us_copy_tree {
    param([string]$Src, [string]$Dest)
    if (Test-Path -LiteralPath $Dest -PathType Leaf) {
        Remove-Item -LiteralPath $Dest -Force -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path -LiteralPath $Dest -PathType Container)) {
        try { New-Item -ItemType Directory -Force -Path $Dest -ErrorAction Stop | Out-Null }
        catch { throw (us_write_denied $Dest) }
    }
    # the caller runs with $ErrorActionPreference 'Stop', under which a locked file makes these
    # terminating - so contain them here and let the check below decide whether it really failed
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $problems = 0
    try {
        foreach ($child in @(Get-ChildItem -LiteralPath $Dest -Force -ErrorAction SilentlyContinue)) {
            try { Remove-Item -LiteralPath $child.FullName -Recurse -Force -ErrorAction Stop }
            catch { $problems++ }
        }
        try { Copy-Item -Path (Join-Path $Src '*') -Destination $Dest -Recurse -Force -ErrorAction Stop }
        catch { $problems++ }
    }
    finally { $ErrorActionPreference = $prev }

    if ((Test-Path -LiteralPath (Join-Path $Src 'SKILL.md')) -and
        -not (Test-Path -LiteralPath (Join-Path $Dest 'SKILL.md'))) {
        # nothing arrived: either the folder is read-only to this process, or it is held open
        throw (us_write_denied $Dest)
    }
    if ($problems -gt 0) {
        [Console]::Error.WriteLine("note: some files in $Dest were in use and kept their previous contents")
    }
}

# us_validate_skill <skill-dir> - refuse a skill that would install but never load.
# Only checks failures that are otherwise SILENT: an agent given a SKILL.md with broken frontmatter,
# or an empty description, does not complain - the skill is simply never triggered, and the user
# concludes upskill is broken. Everything else about a skill is its author's business.
# Prints what is wrong and returns $false; $true when the skill is loadable.
function us_validate_skill {
    param([string]$Dir)
    $md = Join-Path $Dir 'SKILL.md'
    if (-not (Test-Path -LiteralPath $md -PathType Leaf)) {
        [Console]::Error.WriteLine("error: not a skill folder (no SKILL.md): $Dir")
        return $false
    }
    $lines = @(Get-Content -LiteralPath $md)
    $problems = @()
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') {
        $problems += 'the file must start with a --- frontmatter block'
    }
    else {
        $close = -1
        for ($i = 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Trim() -eq '---') { $close = $i; break }
        }
        if ($close -lt 0) {
            $problems += 'the frontmatter block is never closed with ---'
        }
        else {
            $block = $lines[1..($close - 1)]
            if (-not ($block | Where-Object { $_ -match '^name:\s*\S' })) {
                $problems += "frontmatter has no 'name:'"
            }
            if (-not ($block | Where-Object { $_ -match '^description:\s*\S' })) {
                $problems += "frontmatter has no 'description:' - without it an agent never triggers the skill"
            }
        }
    }
    if ($problems.Count -gt 0) {
        [Console]::Error.WriteLine("error: '$(Split-Path -Leaf $Dir)' cannot be shared - it would install but never load:")
        foreach ($p in $problems) { [Console]::Error.WriteLine("  - $p") }
        [Console]::Error.WriteLine("  fix $md and try again.")
        return $false
    }
    return $true
}

# us_skill_names <sharing-clone-dir> - immediate child names that contain SKILL.md, sorted by name.
# The sort is required, not cosmetic: the user picks a skill by the number shown, so bash and
# PowerShell must number the same list identically.
function us_skill_names {
    param([string]$Root)
    $names = @()
    if (Test-Path -LiteralPath $Root -PathType Container) {
        foreach ($d in @(Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue | Sort-Object Name)) {
            if (Test-Path -LiteralPath (Join-Path $d.FullName 'SKILL.md')) { $names += $d.Name }
        }
    }
    return $names
}

# us_safe_name <name> - reject empty / pathy / dot-dot names before they reach a filesystem path.
function us_safe_name {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name.Contains('/') -or $Name.Contains('\') -or $Name.Contains('..')) {
        us_err "error: not a valid name: '$Name'"
        return $false
    }
    return $true
}

# us_init [start-dir] - resolve the workspace, load config, validate address book + membership.
function us_init {
    param([string]$StartDir = $PWD.Path)
    us_require 'git'
    if ($env:UP_SKILL_WORKSPACE -and (Test-Path -LiteralPath $env:UP_SKILL_WORKSPACE -PathType Container)) {
        $script:US_WORKSPACE = $env:UP_SKILL_WORKSPACE
    }
    else {
        $found = us_locate_workspace $StartDir
        if ($found) {
            $script:US_WORKSPACE = $found
        }
        elseif (Test-Path -LiteralPath (Join-Path $HOME '.upskill__workspace') -PathType Container) {
            $script:US_WORKSPACE = Join-Path $HOME '.upskill__workspace'   # global default under the user profile
        }
        else {
            us_exit "error: no .upskill__workspace found from '$StartDir' (looked upward for upskill__user-config.json)`n  run inside your .upskill__workspace, or set UP_SKILL_WORKSPACE=<path>"
        }
    }
    if (-not (us_load_config)) { us_exit "error: cannot read config in $script:US_WORKSPACE" }
    if (-not (Test-Path -LiteralPath $script:US_AB_JSON)) {
        us_exit "error: address book not found at $script:US_AB_JSON (run the installer first)"
    }
    $script:US_ME_FOLDER = us_folder_of $script:US_USER
    if ([string]::IsNullOrWhiteSpace($script:US_ME_FOLDER)) {
        us_exit "error: '$script:US_USER' is not in the address book ($script:US_AB_JSON)"
    }
    $script:US_ME_DIR = Join-Path $script:US_TEAM_DIR $script:US_ME_FOLDER

    # self-update: pull the workspace solution (prod) and refresh the global skills - quiet, best-effort
    us_self_update
}

# us_git_try <args-array> - run git purely best-effort, the PowerShell equivalent of `git ... || true`.
# Windows PowerShell turns a native command's redirected stderr into a terminating error while
# $ErrorActionPreference is 'Stop', so an ordinary git warning (or a pull that cannot fast-forward)
# would otherwise abort the whole action. $LASTEXITCODE is left as git set it.
function us_git_try {
    param([string[]]$GitArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & git @GitArgs 2>&1 | Out-Null } finally { $ErrorActionPreference = $prev }
}

# us_self_update - the user never reruns the installer, so take the newest prod on every use.
# Copying it into the agents' folders is the launcher's job (upskill__run.ps1): it knows which
# installed copy invoked it, and it must not be attempted from inside the workspace clone - whose
# own layout contains a .claude\skills path that looks exactly like an agent's.
function us_self_update {
    $sol = Join-Path $script:US_WORKSPACE 'upskill'
    if (-not (Test-Path -LiteralPath (Join-Path $sol '.git'))) { return }
    # a failed pull is usually transient (offline) and self-heals, but local changes in this clone
    # freeze the user on an old version for good - and they never re-run the installer. Say so.
    us_git_try @('-c', 'safe.directory=*', '-C', $sol, 'pull', '--ff-only', '--quiet')
    if ($LASTEXITCODE -ne 0) {
        $dirty = & git -c 'safe.directory=*' -C $sol status --porcelain 2>$null
        if ($dirty) {
            [Console]::Error.WriteLine("note: upskill is not updating - '$sol' has local changes; discard them there.")
        }
    }
}
