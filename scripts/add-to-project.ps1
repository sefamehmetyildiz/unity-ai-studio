<#
.SYNOPSIS
Installs (or updates) the Unity AI Studio kit into a Unity project.

.DESCRIPTION
Copies the kit payload (Claude Code Game Studios + the gamedev/Unity integration
layer) into the project root, merges the kit's .gitignore / .gitattributes
blocks, adds the com.unity.pipeline package and stamps .claude/studio-kit.json.

Install mode copies files that are missing and never overwrites existing ones.
Update mode (-Update) also overwrites the kit's *framework* files (.claude/...,
engine reference docs) after backing up the old copies to .studio-backup/<time>/.
Project-owned files are never overwritten: CLAUDE.md, project.yaml, design/,
production/, docs/architecture/, .claude/docs/technical-preferences.md.

.PARAMETER ProjectPath
Unity project root. Defaults to the current folder.

.PARAMETER Update
Overwrite framework files with the kit's current version.

.PARAMETER Force
Install even if the folder does not look like a Unity project.

.PARAMETER SkipPackage
Do not add the com.unity.pipeline package.

.PARAMETER DryRun
Report what would change without writing anything.

.EXAMPLE
.\scripts\add-to-project.ps1 -ProjectPath C:\Games\MyGame
.EXAMPLE
.\scripts\add-to-project.ps1 -ProjectPath C:\Games\MyGame -Update
#>
[CmdletBinding()]
param(
    [string]$ProjectPath = (Get-Location).Path,
    [switch]$Update,
    [switch]$Force,
    [switch]$SkipPackage,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$ProjectPath = (Resolve-Path $ProjectPath).Path
$kitVersion = Get-KitVersion
$mode = 'Install'
if ($Update) { $mode = 'Update' }
$tag = ''
if ($DryRun) { $tag = ' (dry run: nothing is written)' }

Write-Host "Unity AI Studio kit v$kitVersion -> $ProjectPath  [$mode]$tag" -ForegroundColor White

# --- 1. Target checks --------------------------------------------------------
if (-not (Test-UnityProject $ProjectPath)) {
    if (-not $Force) {
        Write-Status 'FAIL' 'Not a Unity project (needs Assets/ and ProjectSettings/ProjectVersion.txt). Use -Force to install anyway.'
        exit 2
    }
    Write-Status 'WARN' 'Not a Unity project; continuing because of -Force.'
}

$stampPath = Join-Path $ProjectPath $script:KitStampRel
$stamp = Read-JsonFile $stampPath
$hasCcgs = Test-Path (Join-Path $ProjectPath '.claude\agents')

if (-not $Update -and ($stamp -or $hasCcgs)) {
    if ($stamp) { $v = $stamp.version } else { $v = 'unknown (installed by hand)' }
    Write-Status 'FAIL' "The studio is already in this project (version $v). Run again with -Update to refresh it."
    exit 3
}

# --- 2. Payload files --------------------------------------------------------
Write-Section 'Files'
$files = @(Get-PayloadFiles)
$timeTag = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $ProjectPath ".studio-backup\$timeTag"
$added = 0; $updated = 0; $same = 0; $kept = @(); $removed = 0

function Backup-File([string]$rel) {
    $src = Join-Path $ProjectPath $rel
    $dst = Join-Path $backupRoot $rel
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force (Split-Path -Parent $dst) | Out-Null
        Copy-Item -LiteralPath $src -Destination $dst -Force
    }
}

foreach ($rel in $files) {
    $src = Join-Path $script:PayloadRoot $rel
    $dst = Join-Path $ProjectPath $rel
    if (-not (Test-Path -LiteralPath $dst)) {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Force (Split-Path -Parent $dst) | Out-Null
            Copy-Item -LiteralPath $src -Destination $dst
        }
        $added++
        continue
    }
    if (Test-SameContent $src $dst) { $same++; continue }
    if ($Update -and (Test-FrameworkFile $rel)) {
        Backup-File $rel
        if (-not $DryRun) { Copy-Item -LiteralPath $src -Destination $dst -Force }
        $updated++
    } else {
        $kept += $rel
    }
}

# Framework files the previous kit version shipped and this one no longer does.
if ($Update -and $stamp -and ($stamp.PSObject.Properties.Name -contains 'files')) {
    $now = @{}
    foreach ($f in $files) { $now[$f] = $true }
    foreach ($old in $stamp.files) {
        if ($now.ContainsKey($old) -or -not (Test-FrameworkFile $old)) { continue }
        $p = Join-Path $ProjectPath $old
        if (Test-Path -LiteralPath $p) {
            Backup-File $old
            if (-not $DryRun) { Remove-Item -LiteralPath $p -Force }
            $removed++
        }
    }
}

Write-Status 'OK' "$added added, $updated updated, $same already current, $removed removed (obsolete)"
if ($updated -or $removed) {
    if ($DryRun) { Write-Status 'INFO' "Previous copies would be backed up to .studio-backup\$timeTag" }
    else { Write-Status 'INFO' "Previous copies backed up to .studio-backup\$timeTag" }
}
if ($kept.Count) {
    Write-Status 'INFO' ("{0} file(s) differ from the kit and were kept as the project's own:" -f $kept.Count)
    $kept | Select-Object -First 15 | ForEach-Object { Write-Host "            $_" -ForegroundColor DarkGray }
    if ($kept.Count -gt 15) { Write-Host ('            ... and {0} more' -f ($kept.Count - 15)) -ForegroundColor DarkGray }
}

# --- 3. .gitignore / .gitattributes blocks ------------------------------------
Write-Section 'Git config'
$base = Get-Content (Join-Path $script:TemplateRoot 'unity.gitignore') -Raw
$r = Set-ManagedBlock -Path (Join-Path $ProjectPath '.gitignore') -BlockText (Get-Content (Join-Path $script:TemplateRoot 'studio.gitignore') -Raw) -BaseTextIfMissing $base -DryRun:$DryRun
Write-Status 'OK' ".gitignore: $r"
$r = Set-ManagedBlock -Path (Join-Path $ProjectPath '.gitattributes') -BlockText (Get-Content (Join-Path $script:TemplateRoot 'studio.gitattributes') -Raw) -DryRun:$DryRun
Write-Status 'OK' ".gitattributes: $r"

# --- 4. Unity package --------------------------------------------------------
Write-Section 'Unity package'
$manifest = Join-Path $ProjectPath 'Packages\manifest.json'
if ($SkipPackage) {
    Write-Status 'INFO' 'Skipped (-SkipPackage).'
} elseif (-not (Test-Path $manifest)) {
    Write-Status 'WARN' 'Packages/manifest.json not found; com.unity.pipeline not added.'
} elseif (Select-String -Path $manifest -Pattern '"com\.unity\.pipeline"' -Quiet) {
    Write-Status 'OK' 'com.unity.pipeline already in Packages/manifest.json'
} else {
    $unity = Find-UnityExe
    if (-not $unity) {
        Write-Status 'WARN' 'Unity CLI not found. Run setup-machine.ps1, then: unity pipeline install --project-path <project>'
    } elseif ($DryRun) {
        Write-Status 'DO' 'Would run: unity pipeline install'
    } else {
        & $unity --no-banner pipeline install --project-path $ProjectPath
        if ($LASTEXITCODE -eq 0) { Write-Status 'OK' 'com.unity.pipeline added' }
        else { Write-Status 'WARN' "unity pipeline install exited $LASTEXITCODE; add it later with the same command." }
    }
}

# --- 5. Stamp ----------------------------------------------------------------
if (-not $DryRun) {
    $installedAt = (Get-Date).ToUniversalTime().ToString('o')
    if ($stamp -and ($stamp.PSObject.Properties.Name -contains 'installedAt')) { $installedAt = $stamp.installedAt }
    $obj = [ordered]@{
        kit         = 'unity-ai-studio'
        version     = $kitVersion
        installedAt = $installedAt
        updatedAt   = (Get-Date).ToUniversalTime().ToString('o')
        files       = $files
    }
    Write-Utf8NoBom $stampPath (($obj | ConvertTo-Json -Depth 4) + "`n")
}

# --- 6. Next steps -----------------------------------------------------------
Write-Section 'Next'
if ($mode -eq 'Install') {
    Write-Status 'DO' 'Open the project in Unity (it downloads com.unity.pipeline on first load).'
    Write-Status 'DO' 'Start Claude Code in the project folder and run: /setup-engine unity'
    Write-Status 'DO' 'Then: /studio:doctor   (checks everything)   and   /start or "make me a game ..."'
} else {
    Write-Status 'DO' 'Restart Claude Code in this project so the updated agents, skills and hooks load.'
    Write-Status 'DO' 'Then run /studio:doctor'
}
exit 0
