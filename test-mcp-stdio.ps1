<#
.SYNOPSIS
    Manual test of the MCP stdio launcher (PovCliNet.McpStdio): initialize + tools/list.

.DESCRIPTION
    Starts the launcher the way Claude Desktop does, speaks JSON-RPC to it over stdin/stdout,
    and reports whether the handshake and the tool listing succeed. The web app must already be
    running with Mcp:Enabled.

    The key is taken from -Key, else the RAYTRACING_MCP_KEY environment variable, else
    Mcp:ApiKeys:0:Key in this user's secrets store. Only its source and length are printed unless
    -ShowKey is given.

    stdout is read line by line while the requests are written: the tool list is a few hundred
    KB, more than a pipe buffer holds, so a reader that waits for the end deadlocks the launcher.

.EXAMPLE
    .\scripts\test-mcp-stdio.ps1
.EXAMPLE
    .\scripts\test-mcp-stdio.ps1 -LauncherPath C:\Tools\raytracing-mcp\PovCliNet.McpStdio.exe -ShowTools
.EXAMPLE
    .\scripts\test-mcp-stdio.ps1 -NoKey     # expect a 401: proves the server is enforcing keys
.EXAMPLE
    .\scripts\test-mcp-stdio.ps1 -ShowKey   # also print the key in plain text
#>
[CmdletBinding()]
param(
    [string] $LauncherPath   = 'C:\Tools\raytracing-mcp\PovCliNet.McpStdio.exe',
    [string] $Url            = '',
    [string] $Key            = '',
    [string] $Toolsets       = '',
    [int]    $TimeoutSeconds = 30,
    [switch] $ShowTools,
    [switch] $NoKey,
    [switch] $ShowKey
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

function Write-Step([string] $text, [string] $color = 'Gray') { Write-Host $text -ForegroundColor $color }

# --- launcher -------------------------------------------------------------------------------
if (-not (Test-Path $LauncherPath)) {
    $built = Get-ChildItem (Join-Path $repoRoot 'PovCliNet.McpStdio\bin') -Recurse -Filter 'PovCliNet.McpStdio.exe' -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $built) {
        Write-Step "Launcher not found at '$LauncherPath' and no build output under PovCliNet.McpStdio\bin." 'Red'
        Write-Step "Publish it: dotnet publish PovCliNet.McpStdio\PovCliNet.McpStdio.csproj -c Release -o C:\Tools\raytracing-mcp" 'Yellow'
        exit 2
    }
    $LauncherPath = $built.FullName
}
Write-Step "Launcher : $LauncherPath"

# --- key ------------------------------------------------------------------------------------
$keySource = '-Key'
if ($NoKey) {
    $Key = ''; $keySource = 'none (-NoKey)'
}
elseif ([string]::IsNullOrEmpty($Key)) {
    if (-not [string]::IsNullOrEmpty($env:RAYTRACING_MCP_KEY)) {
        $Key = $env:RAYTRACING_MCP_KEY; $keySource = 'RAYTRACING_MCP_KEY'
    }
    else {
        $secrets = Join-Path $env:APPDATA 'Microsoft\UserSecrets\raytracingmanager-dwaas-visualization\secrets.json'
        if (Test-Path $secrets) {
            $json = Get-Content $secrets -Raw | ConvertFrom-Json
            $flat = $json.PSObject.Properties | Where-Object { $_.Name -eq 'Mcp:ApiKeys:0:Key' } | Select-Object -First 1
            if ($null -ne $flat) { $Key = [string]$flat.Value }
            elseif ($json.Mcp -and $json.Mcp.ApiKeys) { $Key = [string]@($json.Mcp.ApiKeys)[0].Key }
            if ($Key) { $keySource = 'user-secrets (Mcp:ApiKeys:0:Key)' }
        }
    }
}
if ([string]::IsNullOrEmpty($Key)) {
    if (-not $NoKey) { Write-Step "Key      : none found - expect a 401 unless the server allows anonymous loopback" 'Yellow' }
    else { Write-Step "Key      : none (-NoKey)" }
}
else {
    Write-Step ("Key      : from {0} ({1} chars)" -f $keySource, $Key.Length)
    if ($ShowKey) { Write-Step ("Key value: {0}" -f $Key) 'Yellow' }
}
$effectiveUrl = if ($Url) { $Url } else { 'http://localhost:5184/mcp (launcher default)' }
Write-Step "Url      : $effectiveUrl"

# --- start the launcher ---------------------------------------------------------------------
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName               = $LauncherPath
$psi.UseShellExecute        = $false
$psi.RedirectStandardInput  = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.CreateNoWindow         = $true
foreach ($name in 'RAYTRACING_MCP_URL', 'RAYTRACING_MCP_KEY', 'RAYTRACING_MCP_TOOLSETS') {
    if ($psi.EnvironmentVariables.ContainsKey($name)) { $psi.EnvironmentVariables.Remove($name) }
}
if ($Url)      { $psi.EnvironmentVariables['RAYTRACING_MCP_URL']      = $Url }
if ($Key)      { $psi.EnvironmentVariables['RAYTRACING_MCP_KEY']      = $Key }
if ($Toolsets) { $psi.EnvironmentVariables['RAYTRACING_MCP_TOOLSETS'] = $Toolsets }

$proc = [System.Diagnostics.Process]::Start($psi)
$stderrTask = $proc.StandardError.ReadToEndAsync()   # the launcher logs to stderr; drain it so it cannot block
$script:pendingLine = $null

function Send([string] $json) {
    $proc.StandardInput.WriteLine($json)
    $proc.StandardInput.Flush()
}

# Reads stdout lines until the JSON-RPC response with the given id arrives (or the deadline passes).
function Receive([int] $id) {
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ($true) {
        if ($null -eq $script:pendingLine) { $script:pendingLine = $proc.StandardOutput.ReadLineAsync() }
        $left = [int]($deadline - [DateTime]::UtcNow).TotalMilliseconds
        if ($left -le 0 -or -not $script:pendingLine.Wait($left)) { return $null }
        $line = $script:pendingLine.Result
        $script:pendingLine = $null
        if ($null -eq $line) { return $null }               # launcher exited
        if ($line.Trim().Length -eq 0) { continue }
        try { $msg = $line | ConvertFrom-Json } catch { continue }
        if ($msg.PSObject.Properties.Name -contains 'id' -and $msg.id -eq $id) { return $msg }
        # anything else (notifications, log messages) is skipped
    }
}

$exitCode = 0
try {
    # --- initialize -------------------------------------------------------------------------
    Send '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test-mcp-stdio","version":"1.0"}}}'
    $init = Receive 1
    if ($null -eq $init) {
        Write-Step "initialize : no answer within $TimeoutSeconds s" 'Red'; $exitCode = 1; exit 1
    }
    if ($init.error) {
        Write-Step "initialize : error $($init.error.code): $($init.error.message)" 'Red'; $exitCode = 1; exit 1
    }
    Write-Step ("initialize : OK - {0} {1}, protocol {2}" -f $init.result.serverInfo.name, $init.result.serverInfo.version, $init.result.protocolVersion) 'Green'
    Write-Step "             (the launcher answers this itself; the web app is first contacted by the next call)" 'DarkGray'

    Send '{"jsonrpc":"2.0","method":"notifications/initialized"}'

    # --- tools/list -------------------------------------------------------------------------
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Send '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
    $list = Receive 2
    if ($null -eq $list) {
        Write-Step "tools/list : no answer within $TimeoutSeconds s" 'Red'; $exitCode = 1; exit 1
    }
    if ($list.error) {
        Write-Step "tools/list : error $($list.error.code)" 'Red'
        Write-Step "  $($list.error.message)" 'Red'
        if ($list.error.message -match '401') {
            Write-Step "  -> the web app refused the key. Check RAYTRACING_MCP_KEY / -Key against Mcp:ApiKeys:N:Key." 'Yellow'
        }
        elseif ($list.error.message -match 'did not answer|Could not reach|refused|actively') {
            Write-Step "  -> is the web app running with Mcp:Enabled on that URL?" 'Yellow'
        }
        $exitCode = 1; exit 1
    }
    $tools = @($list.result.tools)
    Write-Step ("tools/list : OK - {0} tools in {1} ms" -f $tools.Count, $sw.ElapsedMilliseconds) 'Green'
    if ($ShowTools) { $tools | Sort-Object name | ForEach-Object { Write-Step ("  {0}" -f $_.name) } }
}
finally {
    try { $proc.StandardInput.Close() } catch { }
    if (-not $proc.WaitForExit(5000)) { try { $proc.Kill() } catch { } }
    if ($exitCode -ne 0) {
        $err = $stderrTask.Result
        if ($err -and $err.Trim()) { Write-Step "launcher stderr:"; Write-Step $err.Trim() 'DarkGray' }
    }
}
exit $exitCode
