# change-report census: groups the source files of one change set and counts them
# Usage: census.ps1 [current | <commit>]; output records are documented in SKILL.md
# Mirrors census.sh in Windows PowerShell 5.1 syntax; see census.sh for the parity check
param([string]$Target = '')
Set-StrictMode -Version 2.0
$utf8 = New-Object System.Text.UTF8Encoding $false
try { [Console]::OutputEncoding = $utf8 } catch { }
$OutputEncoding = $utf8
$rulesPath = Join-Path $PSScriptRoot '..\rules.tsv'
function Stop-Census([string]$Message) { [Console]::Error.WriteLine("error: $Message"); exit 2 }
function Invoke-Git { & git -c core.quotePath=false @args 2>$null }

$top = Invoke-Git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) { Stop-Census 'not inside a git work tree' }
Set-Location -LiteralPath $top
$null = Invoke-Git rev-parse --verify --quiet HEAD
if ($LASTEXITCODE -ne 0) { Stop-Census 'the repository has no commits' }
$emptyFile = [IO.Path]::GetTempFileName()
$empty = Invoke-Git hash-object -t tree $emptyFile
Remove-Item -LiteralPath $emptyFile
$new = ''; $branch = ''; $base = ''
if ($Target -ceq '') {
    $scope = 'worktree'
    $old = Invoke-Git rev-parse HEAD
} elseif ($Target -ceq 'current') {
    $scope = 'current'
    $branch = Invoke-Git symbolic-ref --short -q HEAD
    if ($LASTEXITCODE -ne 0) { Stop-Census 'HEAD is detached: there is no current branch' }
    if ('main', 'master', 'develop' -ccontains $branch) { Stop-Census "the current branch $branch is itself a base candidate: name a commit instead" }
    $best = -1
    foreach ($c in 'main', 'master', 'develop') {
        foreach ($ref in "refs/heads/$c", "refs/remotes/origin/$c") {
            $null = Invoke-Git rev-parse --verify --quiet $ref
            if ($LASTEXITCODE -ne 0) { continue }
            $n = [int](Invoke-Git rev-list --count "$ref..HEAD")
            if ($best -lt 0 -or $n -lt $best) { $best = $n; $base = $ref -creplace '^refs/(heads|remotes)/', '' }
            break
        }
    }
    if ($base -ceq '') { Stop-Census 'no base branch: none of main, master, develop exists' }
    $old = Invoke-Git merge-base $base HEAD
    if ($LASTEXITCODE -ne 0) { Stop-Census "no merge base between $branch and $base (shallow clone?)" }
    $new = Invoke-Git rev-parse HEAD
} else {
    $scope = 'commit'
    $new = Invoke-Git rev-parse --verify --quiet "$Target^{commit}"
    if ($LASTEXITCODE -ne 0) { Stop-Census "not a commit: $Target" }
    $old = Invoke-Git rev-parse --verify --quiet "$new^1"
    if ($LASTEXITCODE -ne 0) { $old = $empty }
}

$revs = @($old); if ($new) { $revs += $new }
$status = @(Invoke-Git diff --no-color --no-ext-diff -M --name-status @revs)
$numstat = @(Invoke-Git diff --no-color --no-ext-diff -M --numstat @revs)
$treeSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($p in @(Invoke-Git ls-tree -r --name-only $old)) { [void]$treeSet.Add($p) }
$newTree = if ($new) { @(Invoke-Git ls-tree -r --name-only $new) } else { @(Invoke-Git ls-files) }
foreach ($p in $newTree) { [void]$treeSet.Add($p) }
[string[]]$tree = @($treeSet); [Array]::Sort($tree, [StringComparer]::Ordinal)
$R = @{}
foreach ($line in [IO.File]::ReadAllLines($rulesPath)) {
    if ($line -ceq '' -or $line.StartsWith('#')) { continue }
    $k, $v = $line.Split([char]9, 2)
    if ($R.ContainsKey($k)) { $R[$k] += "|$v" } else { $R[$k] = $v }
}
function Get-SdkProject([string]$Rev) {
    $found = if ($Rev) { Invoke-Git grep -l -E -e $R['test-sdk'] $Rev -- '*.csproj' '*.fsproj' '*.vbproj' } else { Invoke-Git grep -l -E -e $R['test-sdk'] -- '*.csproj' '*.fsproj' '*.vbproj' }
    foreach ($l in @($found)) { if ($Rev -and $l.StartsWith("${Rev}:")) { $l.Substring($Rev.Length + 1) } else { $l } }
}
$sdk = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($p in @(Get-SdkProject $old) + @(Get-SdkProject $new)) { [void]$sdk.Add($p) }
$attr = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$changed = @(foreach ($l in $status) { $l.Split([char]9)[-1] })
if ($changed.Count) {
    foreach ($l in @($changed | & git -c core.quotePath=false check-attr --stdin linguist-generated linguist-vendored 2>$null)) {
        $f = $l -split ': '
        if ($f.Count -ge 3 -and ($f[2] -ceq 'set' -or $f[2] -ceq 'true')) { [void]$attr.Add($f[0]) }
    }
}

$out = New-Object System.Collections.Generic.List[string]
$out.Add("M`tscope`t$scope"); $out.Add("M`told`t$old")
$out.Add("M`tnew`t$(if ($new) { $new } else { 'WORKTREE' })")
if ($branch) { $out.Add("M`tbranch`t$branch"); $out.Add("M`tbase`t$base") }
function Get-Base([string]$s) { $s.Substring($s.LastIndexOf('/') + 1) }
function Get-Dir([string]$s) { $i = $s.LastIndexOf('/'); if ($i -ge 0) { $s.Substring(0, $i) } else { '.' } }
function Find-Project([string]$p) {
    $d = $p
    while (($i = $d.LastIndexOf('/')) -ge 0) { $d = $d.Substring(0, $i); if ($label.ContainsKey($d)) { return $d } }
    if ($label.ContainsKey('.')) { return '.' }
    return ''
}
function Get-Common([string]$Pre, [string]$p) {
    $d = Get-Dir $p
    while ($Pre -cne '.' -and -not "$d/".StartsWith("$Pre/", [StringComparison]::Ordinal)) { $Pre = Get-Dir $Pre }
    return $Pre
}
function Test-Skip([string]$p, [string]$lp) { $attr.Contains($p) -or $lp -cmatch $R['exclude'] -or $lp -cmatch $R['generated'] }
$label = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
$dotnet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$testProj = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$projects = 0; $other = $false
foreach ($p in $tree) {
    $lp = $p.ToLowerInvariant()
    if (Test-Skip $p $lp) { continue }
    $b = Get-Base $lp; $d = Get-Dir $p
    if ($b -cmatch $R['manifest'] -or ($d -ceq '.' -and $b -cmatch $R['manifest-root'])) {
        if (-not $label.ContainsKey($d)) { $projects++; $label[$d] = $(if ($d -ceq '.') { '(root)' } else { $d }) }
        if ($b -cmatch $R['dotnet-manifest'] -and $dotnet.Add($d)) { $name = Get-Base $p; $label[$d] = $name.Substring(0, $name.LastIndexOf('.')) }
        if ($sdk.Contains($p)) { [void]$testProj.Add($d) }
    } elseif ($lp -cmatch $R['source']) { $other = $true }
}
foreach ($d in @($label.Keys)) { if ((Get-Base $label[$d]).ToLowerInvariant() -cmatch $R['test-project']) { [void]$testProj.Add($d) } }

$rows = New-Object System.Collections.Generic.List[object]
$excluded = 0; $prefix = $null
for ($i = 0; $i -lt $status.Count; $i++) {
    $a = $status[$i].Split([char]9)
    $c = if ($i -lt $numstat.Count) { $numstat[$i].Split([char]9) } else { @('-', '-') }
    $st = $a[0].Substring(0, 1); $p = $a[-1]
    if ('A', 'D', 'R' -cnotcontains $st) { $st = 'M' }
    $lp = $p.ToLowerInvariant()
    if ($c[0] -ceq '-' -or (Test-Skip $p $lp)) { $excluded++; continue }
    $script = $lp -cmatch $R['script']
    if (-not $script -and $lp -cnotmatch $R['source']) { $excluded++; continue }
    $pr = Find-Project $p
    if ($script -and ($p.IndexOf('/') -lt 0 -or $lp -cmatch $R['script-exclude'] -or ($pr -ceq '' -and $other))) { $excluded++; continue }
    if ($projects -ge 2 -and $pr -cne '' -and $testProj.Contains($pr)) { $g = $label[$pr]; $k = 2 }
    elseif ($lp -cmatch $R['test-path'] -or $p -cmatch $R['test-name']) { $g = 'Tests'; $k = 3 }
    elseif ($projects -ge 2) { $g = $(if ($pr -ceq '') { '(no project)' } else { $label[$pr] }); $k = 1 }
    else { $g = ''; $k = 1; $prefix = $(if ($null -eq $prefix) { Get-Dir $p } else { Get-Common $prefix $p }) }
    $rows.Add(@{ G = $g; K = $k; S = $st; Plus = [long]$c[0]; Minus = [long]$c[1]; P = $p })
}
# ponytail: a single project groups by the first directory below the common prefix of the touched files
foreach ($r in $rows) {
    if ($r['G'] -cne '') { continue }
    $rest = if ($prefix -ceq '.') { $r['P'] } else { $r['P'].Substring($prefix.Length + 1) }
    $j = $rest.IndexOf('/')
    if ($j -ge 0) { $r['G'] = $(if ($prefix -ceq '.') { '' } else { "$prefix/" }) + $rest.Substring(0, $j) }
    else { $r['G'] = $(if ($prefix -ceq '.') { '(root)' } else { $prefix }) }
}

$groups = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
$keys = New-Object System.Collections.Generic.List[string]
foreach ($r in $rows) {
    if (-not $groups.ContainsKey($r['G'])) { $groups[$r['G']] = @{ K = $r['K']; Files = 0; A = 0; M = 0; D = 0; R = 0; Plus = [long]0; Minus = [long]0 }; $keys.Add("$($r['K'])`t$($r['G'])") }
    $x = $groups[$r['G']]; $x['Files'] += 1; $x[$r['S']] += 1; $x['Plus'] += $r['Plus']; $x['Minus'] += $r['Minus']
}
[string[]]$sorted = $keys.ToArray(); [Array]::Sort($sorted, [StringComparer]::Ordinal)
$kinds = @{ 1 = 'source'; 2 = 'test-project'; 3 = 'tests' }
$out.Add("M`tgrouping`t$(if ($projects -ge 2) { 'project' } else { 'directory' })")
$out.Add("M`tprojects`t$projects"); $out.Add("M`texcluded`t$excluded")
$t = @{ Files = 0; A = 0; M = 0; D = 0; R = 0; Plus = [long]0; Minus = [long]0 }
foreach ($key in $sorted) {
    $g = $key.Substring(2); $x = $groups[$g]
    $out.Add((@('G', $g, $kinds[$x['K']], $x['Files'], $x['A'], $x['M'], $x['D'], $x['R'], $x['Plus'], $x['Minus']) -join "`t"))
    foreach ($f in 'Files', 'A', 'M', 'D', 'R', 'Plus', 'Minus') { $t[$f] += $x[$f] }
}
$out.Add((@('T', 'Total', '-', $t['Files'], $t['A'], $t['M'], $t['D'], $t['R'], $t['Plus'], $t['Minus']) -join "`t"))
foreach ($r in $rows) { $out.Add((@('F', $r['G'], $r['S'], $r['Plus'], $r['Minus'], $r['P']) -join "`t")) }
[Console]::Out.Write(($out -join "`n") + "`n")
