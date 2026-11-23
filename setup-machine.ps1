<#
.SYNOPSIS
One-time machine setup for the Unity AI Studio.

.DESCRIPTION
Installs or verifies, and skips anything already in place:
  1. Git for Windows (bash runs the Game Studios hooks)
  2. Claude Code CLI (and puts it on your user PATH)
  3. Unity CLI (beta channel by default)
  4. Plugin gamedev@awesome-gamedev-agent-skills (engine-neutral game dev know-how)
  5. Plugin unity@unity-agent-plugin + Unity CLI skills  (via: unity setup claude)
  6. MCP server unity-editor-mcp (live control of the open Unity Editor)
  7. Plugin studio@unity-ai-studio (this kit: /studio:add, /studio:doctor, /studio:update)

Self-contained on purpose so it also runs as a one-liner (irm ... | iex).

.PARAMETER KitMarketplace
GitHub repo (owner/name) or local folder of this kit's marketplace.

.PARAMETER UnityCliChannel
Unity CLI release channel used when installing it.

.PARAMETER DryRun
Show what would be installed without changing anything.

.EXAMPLE
.\setup-machine.ps1
.EXAMPLE
.\setup-machine.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [string]$KitMarketplace = 'sefamehmetyildiz/unity-ai-studio',
    [string]$UnityCliChannel = 'beta',
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
$failures = 0

function Say([string]$s, [string]$m) {
    $c = @{ OK = 'Green'; DO = 'Cyan'; WARN = 'Yellow'; FAIL = 'Red'; INFO = 'Gray' }[$s]
    Write-Host ('  [{0,-4}] {1}' -f $s, $m) -ForegroundColor $c
    if ($s -eq 'FAIL') { $script:failures++ }
}
function Step([string]$t) { Write-Host ''; Write-Host "== $t ==" -ForegroundColor White }
function Add-SessionPath([string]$dir) {
    if (($env:Path -split ';') -notcontains $dir) { $env:Path = "$dir;$env:Path" }
}
function Add-UserPath([string]$dir) {
    $cur = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $cur) { $cur = '' }
    if (($cur -split ';') -contains $dir) { return $false }
    if (-not $DryRun) { [Environment]::SetEnvironmentVariable('Path', ($cur.TrimEnd(';') + ";$dir"), 'User') }
    return $true
}
# Case-sensitive JSON reader. PS 5.1 ConvertFrom-Json rejects keys that differ
# only by case, which ~/.claude.json can contain (project paths), so it is not used.
function Read-JsonDict([string]$p) {
    if (-not (Test-Path $p)) { return $null }
    try {
        Add-Type -AssemblyName System.Web.Extensions
        $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $ser.MaxJsonLength = [int]::MaxValue
        return $ser.DeserializeObject([System.IO.File]::ReadAllText($p))
    } catch { return $null }
}
function Test-JsonPath($d, [string[]]$keys) {
    foreach ($k in $keys) {
        if ($null -eq $d -or -not ($d -is [System.Collections.IDictionary]) -or -not $d.ContainsKey($k)) { return $false }
        $d = $d[$k]
    }
    return $true
}
function Test-PluginInstalled([string]$id) {
    return (Test-JsonPath (Read-JsonDict (Join-Path $env:USERPROFILE '.claude\plugins\installed_plugins.json')) @('plugins', $id))
}
function Test-McpConfigured([string]$name) {
    return (Test-JsonPath (Read-JsonDict (Join-Path $env:USERPROFILE '.claude.json')) @('mcpServers', $name))
}

$tag = ''
if ($DryRun) { $tag = '  (dry run: nothing is changed)' }
Write-Host "Unity AI Studio - machine setup$tag" -ForegroundColor White

# --- 1. Git for Windows -------------------------------------------------------
Step 'Git for Windows'
$bash = @((Join-Path $env:ProgramFiles 'Git\bin\bash.exe'), (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe')) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($bash) { Say 'OK' "Git Bash: $bash" }
elseif ($DryRun) { Say 'DO' 'Would install Git for Windows (winget install Git.Git)' }
else {
    Say 'DO' 'Installing Git for Windows...'
    winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -eq 0) { Say 'OK' 'Git installed (open a new terminal afterwards)' }
    else { Say 'FAIL' 'Git install failed. Install it from https://git-scm.com/download/win and re-run.' }
}

# --- 2. Claude Code CLI ------------------------------------------------------
Step 'Claude Code CLI'
$bin = Join-Path $env:USERPROFILE '.local\bin'
$claude = Join-Path $bin 'claude.exe'
if (-not (Test-Path $claude)) {
    $c = Get-Command claude -ErrorAction SilentlyContinue
    if ($c) { $claude = $c.Source }
}
if (Test-Path $claude) { Say 'OK' ("Claude Code " + (& $claude --version 2>$null | Select-Object -First 1)) }
elseif ($DryRun) { Say 'DO' 'Would install Claude Code (irm https://claude.ai/install.ps1 | iex)' }
else {
    Say 'DO' 'Installing Claude Code...'
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    if (Test-Path (Join-Path $bin 'claude.exe')) { $claude = Join-Path $bin 'claude.exe'; Say 'OK' 'Claude Code installed' }
    else { Say 'FAIL' 'Claude Code install failed. See https://docs.claude.com/en/docs/claude-code/setup' }
}
if (Test-Path $bin) {
    Add-SessionPath $bin
    if (Add-UserPath $bin) {
        if ($DryRun) { Say 'DO' "Would add $bin to your user PATH" }
        else { Say 'OK' "Added $bin to your user PATH (new terminals see 'claude')" }
    }
}

# --- 3. Unity CLI ------------------------------------------------------------
Step 'Unity CLI'
$unityBin = Join-Path $env:LOCALAPPDATA 'Unity\bin'
$unity = Join-Path $unityBin 'unity.exe'
if (Test-Path $unity) { Say 'OK' ("Unity CLI " + (& $unity --version 2>$null | Select-Object -First 1)) }
elseif ($DryRun) { Say 'DO' "Would install Unity CLI ($UnityCliChannel channel)" }
else {
    Say 'DO' "Installing Unity CLI ($UnityCliChannel channel)..."
    $env:UNITY_CLI_CHANNEL = $UnityCliChannel
    Invoke-RestMethod https://public-cdn.cloud.unity3d.com/hub/prod/cli/install.ps1 | Invoke-Expression
    if (Test-Path $unity) { Say 'OK' 'Unity CLI installed' } else { Say 'FAIL' 'Unity CLI install failed.' }
}
if (Test-Path $unityBin) { Add-SessionPath $unityBin; [void](Add-UserPath $unityBin) }

$haveClaude = Test-Path $claude
$haveUnity = Test-Path $unity

# --- 4. gamedev plugin -------------------------------------------------------
Step 'Plugin: gamedev'
$id = 'gamedev@awesome-gamedev-agent-skills'
if (Test-PluginInstalled $id) { Say 'OK' $id }
elseif (-not $haveClaude) { Say 'FAIL' "$id skipped: Claude Code missing" }
elseif ($DryRun) { Say 'DO' "Would install $id" }
else {
    & $claude plugin marketplace add gamedev-skills/awesome-gamedev-agent-skills
    & $claude plugin install $id --scope user
    if (Test-PluginInstalled $id) { Say 'OK' $id } else { Say 'FAIL' "$id install failed" }
}

# --- 5. Unity plugin + Unity CLI skills ----------------------------------------
Step 'Plugin: unity + Unity CLI skills'
$id = 'unity@unity-agent-plugin'
$skillsOk = Test-Path (Join-Path $env:USERPROFILE '.claude\skills\unity-pipeline\SKILL.md')
if ((Test-PluginInstalled $id) -and $skillsOk) { Say 'OK' "$id + Unity CLI skills" }
elseif (-not ($haveClaude -and $haveUnity)) { Say 'FAIL' "$id skipped: Claude Code or Unity CLI missing" }
elseif ($DryRun) { Say 'DO' "Would run: unity setup claude -y" }
else {
    & $unity --no-banner setup claude -y
    if (Test-PluginInstalled $id) { Say 'OK' $id } else { Say 'FAIL' "$id install failed (try: unity setup claude)" }
}

# --- 6. Unity Editor MCP -----------------------------------------------------
Step 'MCP: unity-editor-mcp'
if (Test-McpConfigured 'unity-editor-mcp') { Say 'OK' 'unity-editor-mcp' }
elseif (-not ($haveClaude -and $haveUnity)) { Say 'FAIL' 'MCP skipped: Claude Code or Unity CLI missing' }
elseif ($DryRun) { Say 'DO' 'Would run: unity mcp configure claude -y --replace-legacy' }
else {
    & $unity --no-banner mcp configure claude -y --replace-legacy
    if (-not (Test-McpConfigured 'unity-editor-mcp')) {
        & $claude mcp add --scope user unity-editor-mcp -- $unity mcp --tool-groups
    }
    if (Test-McpConfigured 'unity-editor-mcp') { Say 'OK' 'unity-editor-mcp' } else { Say 'FAIL' 'MCP setup failed' }
}

# --- 7. Studio kit plugin ----------------------------------------------------
Step 'Plugin: studio (this kit)'
$id = 'studio@unity-ai-studio'
if (Test-PluginInstalled $id) { Say 'OK' $id }
elseif (-not $haveClaude) { Say 'FAIL' "$id skipped: Claude Code missing" }
elseif ($DryRun) { Say 'DO' "Would add marketplace $KitMarketplace and install $id" }
else {
    & $claude plugin marketplace add $KitMarketplace
    if ($LASTEXITCODE -ne 0 -and $PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot '.claude-plugin\marketplace.json'))) {
        Say 'WARN' "Could not reach $KitMarketplace; using this local copy instead: $PSScriptRoot"
        & $claude plugin marketplace add $PSScriptRoot
    }
    & $claude plugin install $id --scope user
    if (Test-PluginInstalled $id) { Say 'OK' $id } else { Say 'FAIL' "$id install failed" }
}

# --- Done --------------------------------------------------------------------
Write-Host ''
if ($failures) {
    Write-Host "Finished with $failures problem(s) - see [FAIL] lines above." -ForegroundColor Red
    if ($PSCommandPath) { exit 1 } else { return }
}
Write-Host 'Machine ready.' -ForegroundColor Green
Write-Host '  Next: open a NEW terminal, cd into a Unity project, run "claude", then type /studio:add' -ForegroundColor Cyan
if ($PSCommandPath) { exit 0 }
