# upskill__show_menu.ps1 - print the /upskill home screen (PowerShell mirror of upskill__show_menu.sh).
# Read-only. The upskill entry skill prints this output verbatim, then acts on the user's pick.
#
# usage: powershell -NoProfile -ExecutionPolicy Bypass -File upskill__show_menu.ps1
param()

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '../../../scripts/upskill__lib.ps1')

$start = $PWD.Path
if ($env:UP_SKILL_WORKSPACE) { $start = $env:UP_SKILL_WORKSPACE }
us_init -StartDir $start

# Layout: no column alignment anywhere. Agents render this reply as markdown, which collapses runs
# of spaces, so padded columns arrive mangled. Structure comes from line breaks and a "- " prefix,
# which markdown keeps - and which also reads correctly in a plain terminal.
$PER_ROW = 5
$rows = New-Object System.Collections.ArrayList

$base = Join-Path $script:US_WORKSPACE 'address_books'
if (Test-Path -LiteralPath $base -PathType Container) {
    foreach ($teamDir in @(Get-ChildItem -LiteralPath $base -Directory)) {
        $team = $teamDir.Name
        $ab = @(Get-ChildItem -LiteralPath $teamDir.FullName -Filter 'address_book.json' -Recurse -Depth 1 -ErrorAction SilentlyContinue)
        if ($ab.Count -eq 0) { continue }
        try { $users = ([System.IO.File]::ReadAllText($ab[0].FullName) | ConvertFrom-Json).users }
        catch { continue }
        $label = $team
        if ($label.StartsWith('team__')) { $label = $label.Substring('team__'.Length) }

        $tokens = New-Object System.Collections.ArrayList
        foreach ($p in $users.PSObject.Properties) {
            $name = $p.Name
            $m = $p.Value
            $folder = ''
            if ($null -ne $m -and $m.folder) { $folder = [string]$m.folder }
            $clone = ''
            if ($folder) { $clone = Join-Path $teamDir.FullName $folder }
            $count = 0
            $hasClone = $false
            if (Test-Path -LiteralPath $clone -PathType Container) {
                $hasClone = $true
                foreach ($d in @(Get-ChildItem -LiteralPath $clone -Directory -ErrorAction SilentlyContinue)) {
                    if (Test-Path -LiteralPath (Join-Path $d.FullName 'SKILL.md')) { $count++ }
                }
            }
            # cloned repo -> "name (count)" (0 is real); no local clone -> name only (unknown)
            $token = if ($hasClone) { "$name ($count)" } else { $name }
            [void]$tokens.Add($token)
        }
        $isCur = if ($team -eq $script:US_TEAM) { 0 } else { 1 }
        [void]$rows.Add([pscustomobject]@{ Cur = $isCur; Alpha = $label.ToLower(); Label = $label; IsCurrent = ($team -eq $script:US_TEAM); People = @($users.PSObject.Properties).Count; Tokens = $tokens.ToArray() })
    }
}

# Codex refuses a sandboxed command's writes, so adding a skill needs Full access. Mark it in the
# menu rather than letting the user find out by hitting an error. Claude Code has no such prompt,
# so the marker is only shown when Codex is the one asking (the launcher exports which agent).
$agentSkills = $env:UP_SKILL_AGENT_SKILLS
if (-not $agentSkills) { $agentSkills = Join-Path $HOME '.claude\skills' }
$agentDir = Split-Path -Leaf (Split-Path -Parent $agentSkills)
$addMark = '    '
$addNote = ''
if ($agentDir -eq '.codex') {
    $addMark = ' (F)'
    $addNote = '(F) Adding skills requires `Full access` permission'
}

Write-Output 'You can share or receive skills with members from the active address book:'
Write-Output ''
if ($rows.Count -eq 0) {
    Write-Output '(no address books installed - add one to get started)'
}
else {
    $rows = @($rows | Sort-Object Cur, Alpha)
    $n = 0
    foreach ($r in $rows) {
        if ($n -gt 0) { Write-Output '' }   # blank line between books: markdown merges them without it
        $n++
        $suffix = if ($r.IsCurrent) { ' - active' } else { '' }
        Write-Output ("Address Book: " + $r.Label + " (" + $r.People + " members)" + $suffix)
        $tokens = $r.Tokens
        for ($i = 0; $i -lt $tokens.Count; $i += $PER_ROW) {
            $chunk = @($tokens[$i..([Math]::Min($i + $PER_ROW - 1, $tokens.Count - 1))])
            Write-Output ('- ' + ($chunk -join ', '))
        }
    }
}

Write-Output ''
Write-Output '---'
Write-Output ''
Write-Output 'What would you like to do?'
Write-Output '1. Show a member''s skills        - e.g. "show Andy''s skills"'
Write-Output ("2. Add a member's skill" + $addMark + '      - e.g. "add Andy''s say_hello skill"')
Write-Output '3. Share your skill              - e.g. "share my xxx skill"'
Write-Output '4. Remove a shared skill         - e.g. "remove my xxx skill"'
if ($addNote) { Write-Output $addNote }
Write-Output ''
Write-Output 'To change address book, use option 5'
Write-Output '5. Add or change address book    - e.g. "add an address book"'

exit 0   # this script only prints - do not leak a stale $LASTEXITCODE from an earlier git call
