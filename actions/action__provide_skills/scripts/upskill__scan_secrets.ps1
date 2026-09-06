# upskill__scan_secrets.ps1 - refuse to publish anything carrying a credential.
#
# Deliberately standalone: it dot-sources no library and reads no config, so the same file works
# from the share flow, from a git pre-commit hook, and before upskill is installed at all.
#
# usage: powershell -NoProfile -ExecutionPolicy Bypass -File upskill__scan_secrets.ps1 [-Quiet] <path> [<path>...]
# exit: 0 clean | 1 findings (caller must stop) | 2 usage error
[CmdletBinding()]
param(
    [switch]$Quiet,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Paths
)

$ErrorActionPreference = 'Stop'

if (-not $Paths -or $Paths.Count -eq 0) {
    [Console]::Error.WriteLine('usage: upskill__scan_secrets.ps1 [-Quiet] <path> [<path>...]')
    exit 2
}
foreach ($p in $Paths) {
    if (-not (Test-Path -LiteralPath $p)) {
        [Console]::Error.WriteLine("error: no such path: $p")
        exit 2
    }
}

# filenames that are credentials whatever is inside them
$fileRules = @(
    '.env', '.envrc', 'id_rsa', 'id_dsa', 'id_ecdsa', 'id_ed25519',
    'credentials.json', '.npmrc', '.pypirc', '.netrc', '.htpasswd'
)
$fileGlobs = @('.env.*', '*.pem', '*.key', '*.p12', '*.pfx', '*.jks', '*.keystore', '*service-account*.json')

# content patterns, most-specific first: a token matched twice keeps the first rule's label
$contentRules = @(
    @{ Label = 'Anthropic API key'; Pattern = 'sk-ant-[A-Za-z0-9_-]{16,}' },
    @{ Label = 'OpenAI API key';    Pattern = 'sk-(proj-)?[A-Za-z0-9_-]{20,}' },
    @{ Label = 'GitHub token';      Pattern = 'gh[pousr]_[A-Za-z0-9]{16,}' },
    @{ Label = 'GitHub token';      Pattern = 'github_pat_[A-Za-z0-9_]{20,}' },
    @{ Label = 'AWS access key';    Pattern = '(AKIA|ASIA)[0-9A-Z]{16}' },
    @{ Label = 'Google API key';    Pattern = 'AIza[0-9A-Za-z_-]{30,}' },
    @{ Label = 'Slack token';       Pattern = 'xox[baprs]-[0-9A-Za-z-]{10,}' },
    @{ Label = 'private key block'; Pattern = '-----BEGIN [A-Z ]*PRIVATE KEY-----' },
    @{ Label = 'hardcoded secret';  Pattern = '(?i)(api[_-]?key|secret|token|password|passwd)["'']?\s*[:=]\s*["''][^"'']{16,}["'']' }
)

# a doc that shows people what a key looks like must not block the share
function Test-Placeholder([string]$v) {
    $l = $v.ToLowerInvariant()
    foreach ($m in @('xxx', 'your_', 'your-', 'example', 'placeholder', 'dummy', 'redacted',
                     'changeme', 'sample', '<', '${', 'fake', 'notreal')) {
        if ($l.Contains($m)) { return $true }
    }
    foreach ($m in @('00000000', 'aaaaaaaa', '11111111', '****', '....')) {
        if ($l.Contains($m)) { return $true }
    }
    return $false
}

# a file with a NUL byte in its head is binary - never scanned, never reported
function Test-TextFile([string]$path) {
    try {
        $fs = [System.IO.File]::OpenRead($path)
        try {
            $buf = New-Object byte[] 8192
            $n = $fs.Read($buf, 0, $buf.Length)
            for ($i = 0; $i -lt $n; $i++) { if ($buf[$i] -eq 0) { return $false } }
        } finally { $fs.Dispose() }
        return $true
    } catch { return $false }
}

$files = @()
foreach ($p in $Paths) {
    $item = Get-Item -LiteralPath $p
    if ($item.PSIsContainer) {
        $files += Get-ChildItem -LiteralPath $p -Recurse -File -Force -ErrorAction SilentlyContinue |
                  Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }
    } else {
        $files += $item
    }
}

$findings = New-Object System.Collections.ArrayList
$seen = @{}

foreach ($f in $files) {
    $isCredFile = $fileRules -contains $f.Name
    if (-not $isCredFile) {
        foreach ($g in $fileGlobs) { if ($f.Name -like $g) { $isCredFile = $true; break } }
    }
    if ($isCredFile) {
        [void]$findings.Add([pscustomobject]@{ File = $f.FullName; Line = $null; Label = 'credential file'; Shown = $null })
        continue
    }
    if (-not (Test-TextFile $f.FullName)) { continue }

    foreach ($rule in $contentRules) {
        $hits = Select-String -LiteralPath $f.FullName -Pattern $rule.Pattern -AllMatches -ErrorAction SilentlyContinue
        foreach ($hit in $hits) {
            foreach ($m in $hit.Matches) {
                $token = $m.Value
                if (Test-Placeholder $token) { continue }
                $key = "$($f.FullName)`t$($hit.LineNumber)`t$token"
                if ($seen.ContainsKey($key)) { continue }
                $seen[$key] = $true
                # redact: never print the credential back out into a terminal scrollback
                $shown = if ($token.Length -gt 8) { $token.Substring(0, 6) + '***' } else { '***' }
                [void]$findings.Add([pscustomobject]@{
                    File = $f.FullName; Line = $hit.LineNumber; Label = $rule.Label; Shown = $shown
                })
            }
        }
    }
}

if ($findings.Count -eq 0) {
    if (-not $Quiet) { Write-Output 'no secrets found' }
    exit 0
}

[Console]::Error.WriteLine("BLOCKED: $($findings.Count) possible secret(s) found")
[Console]::Error.WriteLine('')
foreach ($f in $findings) {
    if ($null -eq $f.Line) {
        [Console]::Error.WriteLine("  $($f.File)")
        [Console]::Error.WriteLine("      $($f.Label)")
    } else {
        [Console]::Error.WriteLine("  $($f.File):$($f.Line)")
        [Console]::Error.WriteLine("      $($f.Label)  ->  $($f.Shown)")
    }
}
[Console]::Error.WriteLine('')
[Console]::Error.WriteLine('Nothing was committed or pushed.')
[Console]::Error.WriteLine('  - move the secret into your private_files folder, or replace it with a placeholder')
[Console]::Error.WriteLine('  - if this credential was ALREADY pushed, rotate it: deleting a file does not')
[Console]::Error.WriteLine('    remove it from git history')
exit 1
