# upskill__remove.ps1 - remove one of YOUR shared skills from your own sharing repo (pushes).
# Only your own items - it always acts on your own repo.
#   upskill__remove.ps1               -> list your shared skills, numbered
#   upskill__remove.ps1 <name|n>      -> remove that shared skill
param([string]$Skill = '')

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '../../../scripts/upskill__lib.ps1')

$start = $PWD.Path
if ($env:UP_SKILL_WORKSPACE) { $start = $env:UP_SKILL_WORKSPACE }
us_init -StartDir $start

# us::remove::skill_by <want> - resolve a name or number to a skill name ('' if not one of yours)
function Get-MySkill {
    param([string]$Want)
    $i = 0
    foreach ($s in @(us_skill_names $script:US_ME_DIR)) {
        $i++
        $isNum = $false
        $n = 0
        if ($Want -match '^\d+$') { $isNum = $true; $n = [int]$Want }
        if ($Want -eq $s -or ($isNum -and $n -eq $i)) { return $s }
    }
    return ''
}

if ([string]::IsNullOrWhiteSpace($Skill)) {
    $skills = @(us_skill_names $script:US_ME_DIR)
    if ($skills.Count -eq 0) {
        Write-Output 'You have no shared skills yet - share one first.'
        exit 0
    }
    Write-Output 'Your shared skills:'
    $n = 0
    foreach ($s in $skills) {
        $n++
        Write-Output ('{0,3}  {1}' -f $n, $s)
    }
    Write-Output ''
    Write-Output 'Example:'
    Write-Output '- remove 2'
    Write-Output '- remove <skill name>'
    exit 0
}

$name = Get-MySkill $Skill
if ([string]::IsNullOrWhiteSpace($name)) {
    [Console]::Error.WriteLine("error: '$Skill' is not one of your shared skills")
    [Console]::Error.WriteLine('  run: upskill__remove.ps1   to see your list')
    exit 1
}

$dest = Join-Path $script:US_ME_DIR $name
if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }

& git -C $script:US_ME_DIR add -A
if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine('error: git add failed'); exit 1 }
& git -C $script:US_ME_DIR diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    [Console]::Error.WriteLine("'$name' was already gone - nothing to do")
    exit 0
}
& git -C $script:US_ME_DIR commit -m "remove $name"
if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine('error: git commit failed'); exit 1 }
& git -C $script:US_ME_DIR branch -M main
& git -C $script:US_ME_DIR push -u origin main
if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine('error: git push failed'); exit 1 }

Write-Output "removed '$name' from your shared skills"
