# upskill__find_skill.ps1 - locate a skill folder by name, wherever the person keeps it.
#
# People lay their repos out differently, so nothing is assumed beyond "a skill is a folder holding
# SKILL.md". Names are matched loosely: the user is speaking, not typing a path, so typos, missing
# prefixes and wrong separators all still find it.
#
# usage: upskill__find_skill.ps1 <query> [-Root <dir>]...
# exit: 0 matches printed | 1 nothing matched
param(
    [Parameter(Position = 0)][string]$Query,
    [string[]]$Root = @()
)

. (Join-Path $PSScriptRoot '..\..\..\scripts\upskill__lib.ps1')

us_init

if ([string]::IsNullOrWhiteSpace($Query)) { us_exit 'usage: upskill__find_skill.ps1 <query> [-Root <dir>]...' }

# where a person's own skills actually live: this project, and their two repos.
# $PWD counts only when it IS a project - from a folder OF projects it would offer a neighbour's
# skill as if it were mine, and sharing publishes it under my name.
$roots = @($Root | Where-Object { $_ })
$pwdSkipped = $false
if ($roots.Count -eq 0) {
    $here = (Get-Location).Path
    $isProject = @('.git', '.claude', '.codex') | Where-Object { Test-Path -LiteralPath (Join-Path $here $_) }
    if ($isProject) { $roots += $here } else { $pwdSkipped = $true }
    foreach ($d in @((Join-Path $script:US_ROOT 'private_skills'), $script:US_ME_DIR)) {
        if (Test-Path -LiteralPath $d) { $roots += $d }
    }
}

$SKIP = @('node_modules', '__pycache__', 'venv', 'dist', 'build', 'target', 'vendor')
$MAX_DEPTH = 6      # a skill lives at <project>\.claude\skills\<name> - deeper is someone else's tree
$script:budget = 20000   # a root like C:\code can be enormous; stop rather than hang

# the pool holds OTHER people's repos - sharing from there would re-publish someone else's skill
$exclude = try { (Resolve-Path $script:US_POOL -ErrorAction Stop).Path.TrimEnd('\') } catch { $null }

function fs_norm([string]$s) { -join ($s.ToLowerInvariant().ToCharArray() | Where-Object { [char]::IsLetterOrDigit($_) }) }

# a Levenshtein similarity stands in for difflib: only the ranking matters here
function fs_ratio([string]$a, [string]$b) {
    if ($a.Length -eq 0 -or $b.Length -eq 0) { return 0.0 }
    $prev = 0..$b.Length
    for ($i = 1; $i -le $a.Length; $i++) {
        $cur = @($i) + (1..$b.Length | ForEach-Object { 0 })
        for ($j = 1; $j -le $b.Length; $j++) {
            $cost = if ($a[$i - 1] -eq $b[$j - 1]) { 0 } else { 1 }
            $cur[$j] = [Math]::Min([Math]::Min($cur[$j - 1] + 1, $prev[$j] + 1), $prev[$j - 1] + $cost)
        }
        $prev = $cur
    }
    1.0 - ($prev[$b.Length] / [Math]::Max($a.Length, $b.Length))
}

function fs_score([string]$name, [string]$q) {
    $n = fs_norm $name; $qn = fs_norm $q
    if ($name -ceq $q) { return 100 }
    if ($n -eq $qn) { return 95 }
    if ($n.StartsWith($qn) -or $qn.StartsWith($n)) { return 85 }
    if ($n.Contains($qn)) { return 75 }
    if ($qn.Contains($n)) { return 70 }
    [int]((fs_ratio $n $qn) * 65)
}

function fs_walk([string]$root) {
    $found = @()
    $queue = New-Object System.Collections.Queue
    $base = $root.TrimEnd('\').Split('\').Count
    $queue.Enqueue($root)
    while ($queue.Count -gt 0 -and $script:budget -gt 0) {
        $dir = $queue.Dequeue()
        $script:budget--
        if (Test-Path -LiteralPath (Join-Path $dir 'SKILL.md')) {
            $found += $dir      # a skill never contains another skill
            continue
        }
        if ($dir.TrimEnd('\').Split('\').Count - $base -ge $MAX_DEPTH) { continue }
        foreach ($sub in (Get-ChildItem -LiteralPath $dir -Directory -Force -ErrorAction SilentlyContinue)) {
            # hidden folders hold no skills, except the two the agents read from
            if ($SKIP -contains $sub.Name) { continue }
            if ($sub.Name.StartsWith('.') -and $sub.Name -notin @('.claude', '.codex')) { continue }
            $queue.Enqueue($sub.FullName)
        }
    }
    $found
}

$seen = @{}
$hits = @()
foreach ($r in $roots) {
    foreach ($path in (fs_walk $r)) {
        $real = (Resolve-Path -LiteralPath $path).Path.TrimEnd('\')
        if ($seen.ContainsKey($real)) { continue }
        $seen[$real] = $true
        if ($exclude -and ($real -eq $exclude -or $real.StartsWith($exclude + '\'))) { continue }
        $name = Split-Path -Leaf $path
        $hits += [pscustomobject]@{ Score = (fs_score $name $Query); Name = $name; Path = $path }
    }
}

# a weak best match is still worth showing when it is the only thing close
$hits = @($hits | Where-Object { $_.Score -ge 45 } | Sort-Object -Property @{Expression='Score';Descending=$true}, Name | Select-Object -First 10)

if ($hits.Count -eq 0) {
    us_err "no skill found matching '$Query'"
    us_err ("  looked in: " + ($roots -join ', '))
    if ($pwdSkipped) {
        us_err "  not in $((Get-Location).Path) - it is not a project (no .git, .claude or .codex); pass -Root to search it"
    }
    exit 1
}

# nothing to choose between is not a question
if ($hits[0].Score -ge 95 -and ($hits.Count -eq 1 -or $hits[1].Score -lt $hits[0].Score)) {
    $hits = @($hits[0]); 'Found:'
} elseif ($hits.Count -eq 1) {
    if ($hits[0].Score -ge 70) { 'Found:' } else { 'Closest match - is this the one?' }
} else {
    'Which skill did you mean?'
}
for ($i = 0; $i -lt $hits.Count; $i++) {
    "$($i + 1). $($hits[$i].Name)"
    "   $($hits[$i].Path)"
}
