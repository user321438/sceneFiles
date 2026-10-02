<#
.SYNOPSIS
    Installs a machine-specific JSON into the app's user-secrets store, so appsettings.json never
    has to be edited on a deployed box.

.DESCRIPTION
    Writes the JSON you supply to
        %APPDATA%\Microsoft\UserSecrets\<UserSecretsId>\secrets.json
    which the app layers OVER appsettings.json and appsettings.<Environment>.json. Anything in it
    wins; anything absent falls back to appsettings.json. Environment variables still beat both.

    Why this store rather than a file beside the app:
      * It lives in the user profile, NOT the deployment folder, so redeploying or overwriting the
        app directory cannot clobber it.
      * It is outside the repo, so paths and credentials can never be committed.

    It is NOT encryption. The file is plain JSON readable by that user (and by anyone who can read
    that profile). Treat it as "not in source control", not as "protected at rest".

    The JSON mirrors appsettings.json exactly  -  same sections, same nesting:

        {
          "Db":        { "Server": "my-rds.amazonaws.com,1433", "Password": "..." },
          "AppConfig": { "BinaryPath": "D:\\pov\\upovconsole64.exe" }
        }

    Requires no .NET SDK: the file is written directly rather than through
    `dotnet user-secrets`, so it works on a box that has only the runtime (or a self-contained
    publish).

.PARAMETER JsonPath
    The JSON file to install. Required unless -Show or -Remove is used.

.PARAMETER Merge
    Merge into the existing secrets rather than replacing them. Keys in the new file win;
    keys only in the existing file are kept. Nested objects merge recursively.

.PARAMETER UserSecretsId
    Override the id. By default it is read from PovCliNet.Web\PovCliNet.Web.csproj, so it cannot
    drift from the app.

.PARAMETER Show
    Print the current secrets (secret-looking values masked) and exit.

.PARAMETER Remove
    Delete the secrets store and exit.

.PARAMETER DryRun
    Report what would be written without writing it.

.EXAMPLE
    .\scripts\setup-user-secrets.ps1 -JsonPath .\user-secrets.my-box.json
.EXAMPLE
    .\scripts\setup-user-secrets.ps1 -JsonPath .\user-secrets.db-only.json -Merge
.EXAMPLE
    .\scripts\setup-user-secrets.ps1 -Show
#>
[CmdletBinding(DefaultParameterSetName = 'Install')]
param(
    [Parameter(ParameterSetName = 'Install', Position = 0)]
    [string]$JsonPath,

    [Parameter(ParameterSetName = 'Install')]
    [switch]$Merge,

    [string]$UserSecretsId,

    [Parameter(ParameterSetName = 'Show')]
    [switch]$Show,

    [Parameter(ParameterSetName = 'Remove')]
    [switch]$Remove,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
# This script lives in scripts\, so the repo root is one level up. Everything below joins onto
# $RepoRoot (the csproj it reads the UserSecretsId from, and the git check-ignore call), so getting
# this wrong makes the script throw rather than misbehave quietly.
$RepoRoot = Split-Path -Parent $PSScriptRoot

function Write-Ok   ($m) { Write-Host "  [ok]   $m" -ForegroundColor Green }
function Write-Do   ($m) { Write-Host "  [do]   $m" -ForegroundColor Cyan }
function Write-Warn ($m) { Write-Host "  [warn] $m" -ForegroundColor Yellow }
function Write-Fail ($m) { Write-Host "  [fail] $m" -ForegroundColor Red }
function Write-Section ($m) { Write-Host ""; Write-Host "== $m" -ForegroundColor White }

# -- Resolve the UserSecretsId from the project, so the two cannot disagree -----
function Get-UserSecretsId {
    if ($UserSecretsId) { return $UserSecretsId }
    $csproj = Join-Path $RepoRoot 'PovCliNet.Web\PovCliNet.Web.csproj'
    if (-not (Test-Path $csproj)) {
        throw "Cannot find $csproj to read <UserSecretsId>. Pass -UserSecretsId explicitly."
    }
    $m = [regex]::Match((Get-Content $csproj -Raw), '<UserSecretsId>\s*([^<]+?)\s*</UserSecretsId>')
    if (-not $m.Success) {
        throw "No <UserSecretsId> in $csproj. Pass -UserSecretsId explicitly."
    }
    return $m.Groups[1].Value
}

# The app resolves the same path via Microsoft.Extensions.Configuration.UserSecrets.
# The runtime picks its layout from the APP PROCESS's APPDATA, not from this script's:
#   APPDATA set    -> %APPDATA%\Microsoft\UserSecrets\<id>\secrets.json
#   APPDATA unset  -> <ApplicationData>\.microsoft\usersecrets\<id>\secrets.json
# A Windows service or IIS app pool without a loaded user profile has no APPDATA, so it looks in the
# second location while an interactive run of this script would only have written the first - the
# store is then silently ignored, which is the worst possible failure for this feature. Both are
# written (same content, a few hundred bytes) so the app finds it either way.
function Get-SecretsPaths ($id) {
    $paths = @()
    if ($env:APPDATA) { $paths += (Join-Path $env:APPDATA "Microsoft\UserSecrets\$id\secrets.json") }
    $appData = [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
    if ($appData) { $paths += (Join-Path $appData ".microsoft\usersecrets\$id\secrets.json") }
    if (-not $paths) { $paths += (Join-Path $HOME ".microsoft/usersecrets/$id/secrets.json") }
    return ($paths | Select-Object -Unique)
}

# Values whose content should never be echoed to a console or a build log.
$SecretNamePattern = '(?i)(password|secret|key|token|connectionstring)'

function Format-Value ($name, $value) {
    if ($name -match $SecretNamePattern -and $value -is [string] -and $value.Length -gt 0) {
        return '***' + " ($($value.Length) chars)"
    }
    return $value
}

function Show-Tree ($obj, $prefix = '') {
    foreach ($p in $obj.PSObject.Properties) {
        $path = if ($prefix) { "$prefix`:$($p.Name)" } else { $p.Name }
        if ($p.Value -is [System.Management.Automation.PSCustomObject]) {
            Show-Tree $p.Value $path
        } else {
            Write-Host ("    {0,-46} {1}" -f $path, (Format-Value $p.Name $p.Value))
        }
    }
}

# Recursive merge: values from $over win, keys only in $base survive.
#
# Mutates $base in place and returns NOTHING, deliberately. An earlier version ended with
# `return $base`, and because the recursive call also emitted its return value the function handed
# back an ARRAY of [inner object, outer object] - which ConvertTo-Json then wrote as a JSON array,
# producing a secrets.json the configuration provider cannot bind. PSCustomObject is a reference
# type, so mutating in place is all that is needed; every statement below is non-emitting
# (`Add-Member` only emits with -PassThru).
function Merge-Object ($base, $over) {
    foreach ($p in $over.PSObject.Properties) {
        $existing = $base.PSObject.Properties[$p.Name]
        if ($existing -and
            $existing.Value -is [System.Management.Automation.PSCustomObject] -and
            $p.Value -is [System.Management.Automation.PSCustomObject]) {
            Merge-Object $existing.Value $p.Value
        } elseif ($existing) {
            $existing.Value = $p.Value
        } else {
            $base | Add-Member -MemberType NoteProperty -Name $p.Name -Value $p.Value
        }
    }
}

# -- Go ------------------------------------------------------------------------
$id      = Get-UserSecretsId
$targets = @(Get-SecretsPaths $id)
$primary = $targets[0]

Write-Section "User secrets store"
Write-Host "  id    : $id"
foreach ($t in $targets) { Write-Host "  file  : $t" }
if ($targets.Count -gt 1) {
    Write-Host "  (both layouts are written: a service with no loaded profile has no APPDATA and reads the second)" -ForegroundColor DarkGray
}

if ($Remove) {
    $present = @($targets | Where-Object { Test-Path $_ })
    if (-not $present) { Write-Ok 'Nothing to remove.'; return }
    if ($DryRun) { foreach ($t in $present) { Write-Do "[dry run] Would delete $t" }; return }
    foreach ($t in $present) { Remove-Item $t -Force; Write-Ok "Removed $t" }
    Write-Ok 'The app falls back to appsettings.json.'
    return
}

if ($Show) {
    $present = @($targets | Where-Object { Test-Path $_ })
    if (-not $present) { Write-Warn 'No secrets set on this machine.'; return }
    foreach ($t in $present) {
        Write-Section "Current secrets (secret values masked): $t"
        Show-Tree (Get-Content $t -Raw | ConvertFrom-Json)
    }
    return
}

if (-not $JsonPath) {
    Write-Fail 'Supply -JsonPath <file>, or use -Show / -Remove. See: Get-Help .\scripts\setup-user-secrets.ps1 -Detailed'
    exit 1
}
if (-not (Test-Path $JsonPath)) { Write-Fail "JSON file not found: $JsonPath"; exit 1 }

# A filled-in payload holds the SQL password and the SharePoint client secret. If it sits inside the
# repo and is not ignored, the next `git add -A` commits them - so say so here rather than trusting
# the naming convention to have been followed.
try {
    $full = (Resolve-Path $JsonPath).Path
    if ($full.StartsWith($RepoRoot, [StringComparison]::OrdinalIgnoreCase)) {
        git -C $RepoRoot check-ignore -q -- $full 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "$([System.IO.Path]::GetFileName($full)) is inside the repo and is NOT gitignored."
            Write-Warn "Rename it to user-secrets.<name>.json (covered by .gitignore) or move it outside the repo,"
            Write-Warn "or a later 'git add -A' will commit the credentials in it."
        }
    }
} catch { }   # git missing or not a repo: the warning is a nicety, never a blocker

# Parse before touching anything: a malformed file must not half-replace a working store, and the
# app treats an unparseable secrets.json as a startup error.
try {
    $raw      = Get-Content $JsonPath -Raw
    $incoming = $raw | ConvertFrom-Json
} catch {
    Write-Fail "$JsonPath is not valid JSON: $($_.Exception.Message)"
    exit 1
}
if ($null -eq $incoming) { Write-Fail "$JsonPath parsed as empty."; exit 1 }

# Catch a MISSPELLED section, which is accepted silently and then overrides nothing. Casing is not
# the risk: both this check (-notcontains) and ASP.NET Core's configuration keys are
# case-insensitive, so "db" binds exactly like "Db".
# Kestrel and Urls are included because WebApplication does read them from app configuration -
# warning about them would be a false alarm on settings that work.
$known   = @('AppConfig', 'Db', 'SharePoint', 'Mcp', 'ApiLogging', 'Logging', 'ConnectionStrings',
             'AllowedHosts', 'Kestrel', 'Urls')
$unknown = $incoming.PSObject.Properties.Name | Where-Object { $known -notcontains $_ }
if ($unknown) {
    Write-Warn "Top-level key(s) the app does not read: $($unknown -join ', ')"
    Write-Warn "Expected one of: $($known -join ', ')"
}

# ConfigService.Save() (the Settings page, and the MCP config_set tool) writes the AppConfig node of
# appsettings.json - which this store now sits on top of. Worth saying plainly, because the symptom
# is a save that appears to work and then reverts on restart.
if ($incoming.PSObject.Properties.Name -contains 'AppConfig') {
    Write-Warn 'AppConfig is in this payload: it will override the Settings page. Saves there still write'
    Write-Warn 'appsettings.json, but this store wins on restart - change AppConfig values here instead.'
}

Write-Section 'Values to install'
Show-Tree $incoming

$final    = $incoming
$existing = $null
if (Test-Path $primary) {
    try   { $existing = Get-Content $primary -Raw | ConvertFrom-Json }
    catch {
        if ($Merge) { Write-Fail "Existing $primary is not valid JSON; fix or -Remove it before merging."; exit 1 }
        Write-Warn "Existing $primary is not valid JSON; it will be replaced."
    }
}
if ($Merge -and $existing) {
    Merge-Object $existing $incoming       # mutates $existing; emits nothing
    $final = $existing
    Write-Section 'Merged result (new values win)'
    Show-Tree $final
} elseif ($existing) {
    Write-Warn 'Replacing the existing secrets. Use -Merge to keep values not present in this file.'
}

# Serialise once, then write the same bytes to every layout.
$json = $final | ConvertTo-Json -Depth 32

if ($DryRun) {
    foreach ($t in $targets) { Write-Do "[dry run] Would write $t" }
    return
}

foreach ($t in $targets) {
    $dir = Split-Path -Parent $t
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    # Temp-and-move, so an interrupted write cannot leave a truncated secrets.json that then fails
    # app startup. UTF-8 without BOM: the JSON configuration provider never needs one.
    $tmp = "$t.partial"
    [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -Path $tmp -Destination $t -Force
    Write-Ok "Wrote $t"
}

if ($Merge) { Write-Ok 'Merged into the existing secrets (new values win).' }

Write-Host ""
Write-Host "  These override appsettings.json in every environment. Environment variables still win." -ForegroundColor DarkGray
Write-Host "  The app must run as THIS user ($env:USERNAME)  -  the store is in this user's profile." -ForegroundColor DarkGray
Write-Host "  Verify with:  .\scripts\setup-user-secrets.ps1 -Show" -ForegroundColor DarkGray
Write-Host "  The app logs at startup which store it loaded - check that line if values seem ignored." -ForegroundColor DarkGray
Write-Host "  Then confirm the app agrees:  curl.exe -X POST http://localhost:5000/api/v1.0/test/database" -ForegroundColor DarkGray
