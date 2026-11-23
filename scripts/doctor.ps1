<#
.SYNOPSIS
Checks that the Unity AI Studio environment is set up: machine, project, Editor.

.DESCRIPTION
Prints one line per check with OK / WARN / MISSING / FAIL and, where something is
missing, the command that fixes it. Changes nothing (it does trigger a script
recompile in a connected Editor, which is what Unity does on focus anyway).

.PARAMETER ProjectPath
Unity project root. Defaults to the current folder. Pass -MachineOnly to skip.

.PARAMETER MachineOnly
Only check machine-level setup (CLIs, plugins, MCP).

.PARAMETER NoEditor
Skip the live Editor checks.

.EXAMPLE
.\scripts\doctor.ps1 -ProjectPath C:\Games\MyGame
#>
[CmdletBinding()]
param(
    [string]$ProjectPath = (Get-Location).Path,
    [switch]$MachineOnly,
    [switch]$NoEditor
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'common.ps1')

$fails = 0; $warns = 0
function Report([string]$s, [string]$m) {
    Write-Status $s $m
    if ($s -eq 'FAIL') { $script:fails++ }
    if ($s -eq 'WARN' -or $s -eq 'MISSING') { $script:warns++ }
}

$kitVersion = Get-KitVersion
Write-Host "Unity AI Studio doctor (kit v$kitVersion)" -ForegroundColor White

# --- Machine -----------------------------------------------------------------
Write-Section 'Machine'

$claude = Find-ClaudeExe
if ($claude) {
    $v = (& $claude --version 2>$null | Select-Object -First 1)
    Report 'OK' "Claude Code CLI $v"
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $bin = Join-Path $env:USERPROFILE '.local\bin'
    if ($claude -like "$bin*" -and ($userPath -split ';') -notcontains $bin) {
        Report 'WARN' "$bin is not on your user PATH (typing 'claude' in a new terminal fails). setup-machine.ps1 adds it."
    }
} else { Report 'FAIL' 'Claude Code CLI not found -> run setup-machine.ps1' }

$bash = Find-Bash
if ($bash) { Report 'OK' "Git Bash ($bash) - Game Studios hooks run through it" }
else { Report 'FAIL' 'Git for Windows (bash) not found - Game Studios hooks need it -> winget install Git.Git' }

$unity = Find-UnityExe
if ($unity) {
    $v = (& $unity --version 2>$null | Select-Object -First 1)
    Report 'OK' "Unity CLI $v"
} else { Report 'FAIL' 'Unity CLI not found -> run setup-machine.ps1' }

$installed = Read-JsonDict (Join-Path $env:USERPROFILE '.claude\plugins\installed_plugins.json')
$settings = Read-JsonDict (Join-Path $env:USERPROFILE '.claude\settings.json')
foreach ($id in $script:RequiredPlugins.Keys) {
    $isInstalled = ($null -ne (Get-JsonPath $installed @('plugins', $id)))
    $isDisabled = ((Get-JsonPath $settings @('enabledPlugins', $id)) -eq $false)
    if (-not $isInstalled) { Report 'MISSING' "Plugin $id not installed -> run setup-machine.ps1" }
    elseif ($isDisabled) { Report 'WARN' "Plugin $id is installed but disabled -> claude plugin enable $id" }
    else { Report 'OK' "Plugin $id" }
}

$skillDir = Join-Path $env:USERPROFILE '.claude\skills'
$unitySkills = @('unity-pipeline', 'craft-game-floors', 'create-2d-physics', 'project-auditor-fixes')
$missingSkills = @($unitySkills | Where-Object { -not (Test-Path (Join-Path $skillDir "$_\SKILL.md")) })
if ($missingSkills.Count -eq 0) { Report 'OK' 'Unity CLI skills (unity-pipeline, craft-game-floors, ...)' }
else { Report 'MISSING' ("Unity CLI skills missing: {0} -> unity setup claude -y" -f ($missingSkills -join ', ')) }

$cfg = Read-JsonDict (Join-Path $env:USERPROFILE '.claude.json')
if ($null -eq $cfg) { Report 'WARN' 'Could not read ~/.claude.json (the MCP check below may be wrong)' }
if ($null -ne (Get-JsonPath $cfg @('mcpServers', 'unity-editor-mcp'))) { Report 'OK' 'MCP server unity-editor-mcp' }
else { Report 'MISSING' 'MCP server unity-editor-mcp not configured -> unity mcp configure claude -y' }
if ($null -ne (Get-JsonPath $cfg @('mcpServers', 'unity-mcp'))) {
    Report 'WARN' 'Legacy MCP server unity-mcp (old AI Assistant relay) still configured -> claude mcp remove unity-mcp -s user'
}

if ($MachineOnly) {
    Write-Host ''
    Write-Host ("Result: {0} fail, {1} warning" -f $fails, $warns)
    if ($fails) { exit 1 } else { exit 0 }
}

# --- Project -----------------------------------------------------------------
$ProjectPath = (Resolve-Path $ProjectPath).Path
Write-Section "Project  $ProjectPath"

if (-not (Test-UnityProject $ProjectPath)) {
    Report 'FAIL' 'Not a Unity project (no Assets/ + ProjectSettings/ProjectVersion.txt). Pass -ProjectPath or -MachineOnly.'
    Write-Host ''
    Write-Host ("Result: {0} fail, {1} warning" -f $fails, $warns)
    exit 1
}

$uv = Get-ProjectUnityVersion $ProjectPath
if ($uv -match '^6000\.(\d+)\.' -and [int]$Matches[1] -ge 3) { Report 'OK' "Unity $uv" }
else { Report 'WARN' "Unity $uv - the gamedev skills and Game Studios engine docs target Unity 6.3 LTS; check suggested APIs against your version or upgrade via Unity Hub." }

$stamp = Read-JsonFile (Join-Path $ProjectPath $script:KitStampRel)
if ($stamp) {
    if ($stamp.version -eq $kitVersion) { Report 'OK' "Studio kit v$($stamp.version)" }
    else { Report 'WARN' "Studio kit v$($stamp.version) installed, v$kitVersion available -> /studio:update" }
} elseif (Test-Path (Join-Path $ProjectPath '.claude\agents')) {
    Report 'WARN' 'Game Studios present but not installed by the kit (no .claude/studio-kit.json) -> /studio:update adopts it'
} else {
    Report 'MISSING' 'Studio kit not installed in this project -> /studio:add'
}

$claudeMd = Join-Path $ProjectPath 'CLAUDE.md'
if ((Test-Path $claudeMd) -and (Select-String -Path $claudeMd -Pattern 'Game Studio' -Quiet)) { Report 'OK' 'CLAUDE.md (Game Studios)' }
elseif (Test-Path $claudeMd) { Report 'WARN' 'CLAUDE.md exists but is not the Game Studios one (the kit kept your file). Merge payload/CLAUDE.md into it by hand.' }
else { Report 'MISSING' 'CLAUDE.md missing -> /studio:update' }

$rule = Join-Path $ProjectPath '.claude\rules\plugin-integration.md'
if (Test-Path $rule) { Report 'OK' 'Routing rules (.claude/rules/plugin-integration.md)' }
else { Report 'MISSING' 'Routing rules missing -> /studio:update' }

$noBridge = @()
foreach ($a in $script:BridgedAgents) {
    $f = Join-Path $ProjectPath ".claude\agents\$a.md"
    if (-not (Test-Path $f) -or -not (Select-String -Path $f -Pattern '^skills:' -Quiet)) { $noBridge += $a }
}
if ($noBridge.Count -eq 0) { Report 'OK' ("Agent skill bridge ({0} agents)" -f $script:BridgedAgents.Count) }
else { Report 'MISSING' ("Agents without preloaded skills: {0} -> /studio:update" -f ($noBridge -join ', ')) }

$py = Join-Path $ProjectPath 'project.yaml'
$engine = $null
if (Test-Path $py) {
    $inEngine = $false
    foreach ($line in Get-Content $py) {
        if ($line -match '^engine:\s*$') { $inEngine = $true; continue }
        if ($inEngine -and $line -match '^\S') { break }
        if ($inEngine -and $line -match '^\s+name:\s*"?([^"#]+?)"?\s*(#.*)?$') { $engine = $Matches[1].Trim(); break }
    }
}
if ($engine -eq 'Unity') { Report 'OK' 'Game Studios engine: Unity (project.yaml)' }
elseif ($engine) { Report 'WARN' "Game Studios engine is '$engine', not Unity -> /setup-engine unity" }
else { Report 'MISSING' 'Game Studios engine not set -> run /setup-engine unity in Claude Code' }

$manifest = Join-Path $ProjectPath 'Packages\manifest.json'
if ((Test-Path $manifest) -and (Select-String -Path $manifest -Pattern '"com\.unity\.pipeline"' -Quiet)) { Report 'OK' 'Package com.unity.pipeline (manifest)' }
else { Report 'MISSING' 'Package com.unity.pipeline not in manifest -> unity pipeline install' }

$gi = Join-Path $ProjectPath '.gitignore'
if ((Test-Path $gi) -and (Select-String -Path $gi -Pattern 'ibrary/' -Quiet)) {
    if (Select-String -Path $gi -Pattern '>>> unity-ai-studio >>>|production/session-logs' -Quiet) { Report 'OK' '.gitignore (Unity + studio entries)' }
    else { Report 'WARN' '.gitignore lacks the studio block (session logs, local config would be committed) -> /studio:update' }
} else { Report 'WARN' '.gitignore missing or does not ignore Library/ -> /studio:update' }

# --- Editor ------------------------------------------------------------------
if (-not $NoEditor -and $unity) {
    Write-Section 'Editor'
    $st = $null
    try { $st = (& $unity --no-banner --json status 2>$null | Out-String | ConvertFrom-Json) } catch { $st = $null }
    $inst = $null
    if ($st -and $st.data -and $st.data.instances) {
        $inst = $st.data.instances | Where-Object { $_.projectPath -and ((Resolve-Path $_.projectPath -ErrorAction SilentlyContinue).Path -eq $ProjectPath) } | Select-Object -First 1
    }
    if (-not $inst) {
        Report 'WARN' 'No connected Editor for this project. Open it in Unity (a first open downloads com.unity.pipeline), then re-run.'
    } else {
        Report 'OK' ("Editor connected: Unity {0}, port {1}, state {2}" -f $inst.version, $inst.port, $inst.state)
        & $unity --no-banner recompile --project-path $ProjectPath --timeout 180 *> $null
        $con = $null
        try { $con = (& $unity --no-banner --json command console status --project-path $ProjectPath 2>$null | Out-String | ConvertFrom-Json) } catch { $con = $null }
        if ($con -and $con.PSObject.Properties.Name -contains 'groundTruth') {
            $g = $con.groundTruth
            if ($g.compilationFailed) { Report 'FAIL' 'Scripts do not compile - fix errors first (compile errors put the Editor in Safe Mode and cut the connection)' }
            else { Report 'OK' 'Scripts compile' }
            if ($g.consoleErrors -gt 0) { Report 'WARN' ("Console: {0} error(s), {1} warning(s)" -f $g.consoleErrors, $g.consoleWarnings) }
            else { Report 'OK' ("Console: 0 errors, {0} warning(s)" -f $g.consoleWarnings) }
        } else {
            Report 'WARN' 'Could not read the Editor console.'
        }
    }
}

Write-Host ''
Write-Host ("Result: {0} fail, {1} warning" -f $fails, $warns)
if ($fails) { exit 1 } else { exit 0 }
