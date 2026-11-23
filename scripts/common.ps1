# Shared helpers for the Unity AI Studio kit scripts.
# Windows PowerShell 5.1 compatible. Keep this file ASCII-only: PS 5.1 reads a
# BOM-less script as the ANSI code page, so non-ASCII text would be garbled.


$script:KitRoot = Split-Path -Parent $PSScriptRoot
$script:PayloadRoot = Join-Path $script:KitRoot 'payload'
$script:TemplateRoot = Join-Path $script:KitRoot 'templates'
$script:KitStampRel = '.claude/studio-kit.json'

# Agents that get plugin skills preloaded through `skills:` frontmatter.
$script:BridgedAgents = @(
    'unity-specialist', 'gameplay-programmer', 'ai-programmer', 'ui-programmer',
    'unity-ui-specialist', 'unity-shader-specialist', 'technical-artist',
    'performance-analyst', 'prototyper'
)

# Plugins the kit depends on: id -> GitHub marketplace repo.
$script:RequiredPlugins = [ordered]@{
    'gamedev@awesome-gamedev-agent-skills' = 'gamedev-skills/awesome-gamedev-agent-skills'
    'unity@unity-agent-plugin'             = 'Unity-Technologies/unity-agent-plugin'
    'studio@unity-ai-studio'                  = 'sefamehmetyildiz/unity-ai-studio'
}

<#
.SYNOPSIS
Returns the kit version from the VERSION file at the kit root.
#>
function Get-KitVersion {
    $f = Join-Path $script:KitRoot 'VERSION'
    if (Test-Path $f) { return (Get-Content $f -TotalCount 1).Trim() }
    return '0.0.0'
}

<#
.SYNOPSIS
Prints a status line: OK / WARN / MISSING / FAIL / INFO / DO.
#>
function Write-Status {
    param([string]$Status, [string]$Message)
    $color = 'Gray'
    switch ($Status) {
        'OK'      { $color = 'Green' }
        'WARN'    { $color = 'Yellow' }
        'MISSING' { $color = 'Yellow' }
        'FAIL'    { $color = 'Red' }
        'DO'      { $color = 'Cyan' }
    }
    Write-Host ('  [{0,-7}] {1}' -f $Status, $Message) -ForegroundColor $color
}

function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host "== $Title ==" -ForegroundColor White
}

<#
.SYNOPSIS
Finds the Claude Code CLI. Returns the full path or $null.
#>
function Find-ClaudeExe {
    $c = Get-Command claude -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $p = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
    if (Test-Path $p) { return $p }
    return $null
}

<#
.SYNOPSIS
Finds the Unity CLI. Returns the full path or $null.
#>
function Find-UnityExe {
    $p = Join-Path $env:LOCALAPPDATA 'Unity\bin\unity.exe'
    if (Test-Path $p) { return $p }
    $c = Get-Command unity -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    return $null
}

<#
.SYNOPSIS
Finds bash (Git for Windows). CCGS hooks run through bash.
#>
function Find-Bash {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Git\bin\bash.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe')
    )
    foreach ($p in $candidates) { if (Test-Path $p) { return $p } }
    $c = Get-Command bash -ErrorAction SilentlyContinue
    if ($c -and $c.Source -notmatch 'System32') { return $c.Source }
    return $null
}

<#
.SYNOPSIS
Reads a JSON file into an object, or $null when missing/invalid.
#>
function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try { return (Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}

<#
.SYNOPSIS
Reads a JSON file into nested case-sensitive dictionaries, or $null.
Use for Claude Code's own files: PS 5.1 ConvertFrom-Json rejects keys that
differ only by case, which ~/.claude.json can contain (project paths).
#>
function Read-JsonDict {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        Add-Type -AssemblyName System.Web.Extensions
        $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $ser.MaxJsonLength = [int]::MaxValue
        return $ser.DeserializeObject([System.IO.File]::ReadAllText($Path))
    } catch { return $null }
}

<#
.SYNOPSIS
Walks nested dictionaries from Read-JsonDict. Returns the value or $null.
#>
function Get-JsonPath {
    param($Dict, [string[]]$Keys)
    $d = $Dict
    foreach ($k in $Keys) {
        if ($null -eq $d -or -not ($d -is [System.Collections.IDictionary]) -or -not $d.ContainsKey($k)) { return $null }
        $d = $d[$k]
    }
    return $d
}

<#
.SYNOPSIS
Writes text as UTF-8 without BOM, creating the parent folder.
#>
function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

<#
.SYNOPSIS
True when two files have the same content, ignoring CRLF vs LF.
#>
function Test-SameContent {
    param([string]$A, [string]$B)
    $ta = [System.IO.File]::ReadAllText($A) -replace "`r`n", "`n"
    $tb = [System.IO.File]::ReadAllText($B) -replace "`r`n", "`n"
    return ($ta -ceq $tb)
}

<#
.SYNOPSIS
True for kit "framework" files: overwritten on update. Everything else in the
payload is a seed file: copied only when missing, never overwritten, because
the project owns it after install (CLAUDE.md, project.yaml, design/, production/...).
#>
function Test-FrameworkFile {
    param([string]$Rel)
    $r = $Rel -replace '\\', '/'
    if ($r -eq '.claude/docs/technical-preferences.md') { return $false }
    if ($r -like '.claude/agent-memory/*') { return $false }
    if ($r -eq $script:KitStampRel) { return $false }
    if ($r -like '.claude/*') { return $true }
    if ($r -like 'docs/engine-reference/*') { return ($r -notlike '*/VERSION.md') }
    $fixed = @('docs/CLAUDE.md', 'docs/COLLABORATIVE-DESIGN-PRINCIPLE.md', 'design/CLAUDE.md', '.worktreeinclude')
    return ($fixed -contains $r)
}

<#
.SYNOPSIS
Lists payload files as forward-slash paths relative to the payload root.
#>
function Get-PayloadFiles {
    $root = (Resolve-Path $script:PayloadRoot).Path
    # Finder metadata (.DS_Store, ._*) is never part of the payload.
    Get-ChildItem -LiteralPath $root -Recurse -File -Force |
        Where-Object { $_.Name -ne '.DS_Store' -and -not $_.Name.StartsWith('._') } |
        ForEach-Object { $_.FullName.Substring($root.Length).TrimStart('\', '/') -replace '\\', '/' } |
        Sort-Object
}

<#
.SYNOPSIS
Inserts or replaces the kit's managed block (between >>> / <<< marker lines)
in a text file such as .gitignore. Returns 'created', 'updated', 'unchanged' or 'appended'.
#>
function Set-ManagedBlock {
    param([string]$Path, [string]$BlockText, [string]$BaseTextIfMissing = '', [switch]$DryRun)
    $block = ($BlockText -replace "`r`n", "`n").TrimEnd("`n")
    if (-not (Test-Path $Path)) {
        $text = ''
        if ($BaseTextIfMissing) { $text = ($BaseTextIfMissing -replace "`r`n", "`n").TrimEnd("`n") + "`n`n" }
        if (-not $DryRun) { Write-Utf8NoBom $Path ($text + $block + "`n") }
        return 'created'
    }
    $cur = [System.IO.File]::ReadAllText($Path) -replace "`r`n", "`n"
    $pattern = '(?s)# >>> unity-ai-studio >>>.*?# <<< unity-ai-studio <<<'
    if ($cur -match $pattern) {
        $new = [regex]::Replace($cur, $pattern, [System.Text.RegularExpressions.MatchEvaluator] { param($m) $block })
        if ($new -ceq $cur) { return 'unchanged' }
        if (-not $DryRun) { Write-Utf8NoBom $Path $new }
        return 'updated'
    }
    $new = $cur.TrimEnd("`n") + "`n`n" + $block + "`n"
    if (-not $DryRun) { Write-Utf8NoBom $Path $new }
    return 'appended'
}

<#
.SYNOPSIS
True when the folder looks like a Unity project.
#>
function Test-UnityProject {
    param([string]$Path)
    return ((Test-Path (Join-Path $Path 'ProjectSettings\ProjectVersion.txt')) -and (Test-Path (Join-Path $Path 'Assets')))
}

<#
.SYNOPSIS
Reads the Unity editor version from ProjectSettings/ProjectVersion.txt.
#>
function Get-ProjectUnityVersion {
    param([string]$Path)
    $f = Join-Path $Path 'ProjectSettings\ProjectVersion.txt'
    if (-not (Test-Path $f)) { return $null }
    $line = Select-String -Path $f -Pattern '^m_EditorVersion:\s*(\S+)' | Select-Object -First 1
    if ($line) { return $line.Matches[0].Groups[1].Value }
    return $null
}
