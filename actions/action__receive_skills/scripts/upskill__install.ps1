# upskill__install.ps1 - bring skills from a github repo into a project.
# PowerShell equivalent of upskill__install.sh.
# usage: upskill__install.ps1 <repo-url|owner/repo> [target-project-dir]
#
# Clones the repo, copies every skill under its .claude/skills/ (and any top-level folder that
# carries a SKILL.md) into <target>/.claude/skills/. Standalone - does not need an address book.
param(
    [string]$Url = '',
    [string]$TargetDir = ''
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine('error: git is required')
    exit 1
}
if ([string]::IsNullOrWhiteSpace($Url)) {
    [Console]::Error.WriteLine('usage: upskill__install.ps1 <repo-url|owner/repo> [target-project-dir]')
    [Console]::Error.WriteLine('  e.g. upskill__install.ps1 https://github.com/mingzilla/upskill')
    exit 1
}
if ([string]::IsNullOrWhiteSpace($TargetDir)) { $TargetDir = $PWD.Path }
if (-not (Test-Path -LiteralPath $TargetDir -PathType Container)) {
    [Console]::Error.WriteLine("error: target dir not found: $TargetDir")
    exit 1
}

# clone_url <raw-url> - accept the common github forms, normalise to an https clone URL.
function ConvertTo-HttpsCloneUrl {
    param([string]$u)
    if ($u -like 'git@github.com:*') { return 'https://github.com/' + $u.Substring('git@github.com:'.Length) }
    if ($u -like 'http://*')          { return 'https://' + $u.Substring('http://'.Length) }
    if ($u -like 'https://*')         { return $u }
    if ($u -like 'github.com/*')      { return 'https://' + $u }
    return 'https://github.com/' + $u    # owner/repo or bare name
}

# copy_skill <src-dir> - copy one SKILL.md folder into <target>/.claude/skills; $true when copied.
function Copy-SkillFolder {
    param([string]$SrcDir)
    $name = Split-Path -Leaf $SrcDir
    if ([string]::IsNullOrWhiteSpace($name) -or $name.Contains('/') -or $name.Contains('\') -or $name.Contains('..')) {
        return $false
    }
    $dest = Join-Path $TargetDir (Join-Path '.claude/skills' $name)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
    us_copy_tree $SrcDir $dest
    Write-Output "installed '$name' -> $dest"
    return $true
}

$urlHttps = ConvertTo-HttpsCloneUrl $Url

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('upskill-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    Write-Output "fetching $urlHttps"
    & git clone --quiet --depth 1 $urlHttps (Join-Path $tmp 'repo')
    if ($LASTEXITCODE -ne 0) { throw "git clone failed for $urlHttps" }

    $installed = 0
    $repo = Join-Path $tmp 'repo'

    # 1. skills bundled as a Claude project: <repo>/.claude/skills/*
    $cs = Join-Path $repo '.claude/skills'
    if (Test-Path -LiteralPath $cs -PathType Container) {
        foreach ($d in @(Get-ChildItem -LiteralPath $cs -Directory)) {
            if (Copy-SkillFolder $d.FullName) { $installed++ }
        }
    }

    # 2. skills at the repo root: any top-level folder carrying its own SKILL.md
    foreach ($d in @(Get-ChildItem -LiteralPath $repo -Directory)) {
        if ($d.Name -eq '.claude') { continue }
        if (Test-Path -LiteralPath (Join-Path $d.FullName 'SKILL.md')) {
            if (Copy-SkillFolder $d.FullName) { $installed++ }
        }
    }

    if ($installed -eq 0) {
        throw "no skills found in $urlHttps (looked in .claude/skills/ and top-level SKILL.md folders)"
    }
    Write-Output 'done - open Claude in the target to use the installed skill(s).'
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
