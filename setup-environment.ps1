<#
.SYNOPSIS
    One-time environment bootstrap for raytracingManager on a fresh Windows box.

.DESCRIPTION
    Idempotent  -  safe to re-run. Every step checks current state first and only
    acts when something is actually missing.

    What it does NOT do: build the native renderer (cli\windows\vs10\bin64\*.exe
    is checked into git, so a plain clone already has it) and does not touch the
    Linux/Docker path (see Dockerfile / README.docker.md for that  -  it wires
    paths via AppConfig__* environment variables instead).

    Steps:
      1. Reports .NET SDK / git presence (informational only).
      2. Verifies SQL Server is reachable at -SqlInstanceName; with
         -InstallSqlExpress, installs SQL Server Express (Windows Auth) via
         winget when no instance is found.
      3. Creates the database and runs db\001 / 002 / 003 against it.
      4. Creates every filesystem path AppConfig expects (from
         PovCliNet.Web\appsettings.json) that doesn't already exist. Paths that
         are supposed to come from the repo or a sibling project (IncludesPath,
         TemplatesPath, PresetsPath, the two Spectral* input paths) are verified,
         not created  -  a missing one there means something else is wrong.
      5. Verifies ffmpeg; with -InstallFfmpeg, installs it via winget if missing.

.PARAMETER SqlInstanceName
    SQL Server instance to target, e.g. "SQLEXPRESS01" (default) for a local
    named instance, or "MSSQLSERVER" for the default instance. Matches the name
    baked into appsettings.Development.json  -  change both together, or pass
    -SqlInstanceName and use -UpdateAppSettings to sync the connection string.

.PARAMETER DatabaseName
    Database to create/verify. Must match Db:Database in both appsettings files.

.PARAMETER InstallSqlExpress
    If the instance isn't reachable, install SQL Server 2022 Express via winget
    (Windows Authentication mode). This is a real product install  -  expect a
    multi-minute download and setup run. Without this switch, a missing instance
    is reported with manual install instructions and the script continues to the
    path-creation steps rather than stopping.

.PARAMETER InstallFfmpeg
    Install ffmpeg via winget (Gyan.FFmpeg) if it isn't found at AppConfig's
    FfmpegPath or on PATH. Without this switch, a missing ffmpeg is a warning
    (orbital MP4 assembly and the Video page won't work; everything else still
    does).

.PARAMETER UpdateAppSettings
    Sync appsettings.Development.json's Db:Server / Db:Database to
    -SqlInstanceName / -DatabaseName. Off by default  -  this script does not edit
    tracked config files unless you opt in. Never writes a password: that belongs
    in user-secrets (dotnet user-secrets set "Db:Password" ...) or Db__Password.

.PARAMETER DryRun
    Report what would happen without installing, creating directories, or
    running SQL. Recommended for the first pass on an unfamiliar box.

.EXAMPLE
    .\setup-environment.ps1 -DryRun
    Preview only.

.EXAMPLE
    .\setup-environment.ps1 -InstallSqlExpress -InstallFfmpeg
    Full bootstrap on a box with nothing installed yet.

.EXAMPLE
    .\setup-environment.ps1
    Box already has SQLEXPRESS01 running (the common case after cloning where
    another dev machine's setup is being mirrored)  -  just create the DB/schema
    and the data folders.
#>

[CmdletBinding()]
param(
    [string]$SqlInstanceName = 'SQLEXPRESS01',
    [string]$DatabaseName = 'dwaas_visualization',
    [switch]$InstallSqlExpress,
    [switch]$InstallFfmpeg,
    [switch]$UpdateAppSettings,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
# This script lives in scripts\, so the repo root is one level up. Everything below joins onto
# $RepoRoot - db\001-005, PovCliNet.Web\appsettings.json, cli\windows\vs10\bin64 - and a wrong value
# here does not throw: the db scripts are reported "Missing" and the folder checks quietly do
# nothing, which looks like a successful run.
$RepoRoot   = Split-Path -Parent $PSScriptRoot
$WebRoot    = Join-Path $RepoRoot 'PovCliNet.Web'
$hadWarning = $false
$hadFailure = $false

# -- Output helpers ----------------------------------------------------------
function Write-Section($title) { Write-Host "`n== $title ==" -ForegroundColor Cyan }
function Write-Ok($msg)         { Write-Host "  [ok]   $msg" -ForegroundColor Green }
function Write-Skip($msg)       { Write-Host "  [skip] $msg" -ForegroundColor DarkGray }
function Write-Do($msg)         { Write-Host "  [do]   $msg" -ForegroundColor Yellow }
function Write-WarnStep($msg)   { Write-Host "  [warn] $msg" -ForegroundColor Yellow; $script:hadWarning = $true }
function Write-Fail($msg)       { Write-Host "  [fail] $msg" -ForegroundColor Red; $script:hadFailure = $true }

# -- 1. Toolchain report (informational  -  not a hard gate) -------------------
Write-Section '.NET SDK / git'

$dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
if ($dotnetCmd) {
    $sdks = & dotnet --list-sdks 2>$null
    if ($sdks -match '^10\.') { Write-Ok ".NET 10 SDK found ($(($sdks | Where-Object { $_ -match '^10\.' })[0]))" }
    else {
        Write-WarnStep 'No .NET 10 SDK found. Install with:'
        Write-Host '           winget install --id Microsoft.DotNet.SDK.10' -ForegroundColor DarkGray
    }
} else {
    Write-WarnStep 'dotnet CLI not found. Install with: winget install --id Microsoft.DotNet.SDK.10'
}

if (Get-Command git -ErrorAction SilentlyContinue) { Write-Ok 'git found' }
else { Write-WarnStep 'git not found on PATH (only matters if you plan to commit from this box).' }

if (Test-Path (Join-Path $RepoRoot 'cli\windows\vs10\bin64\upovconsole64.exe')) {
    Write-Ok 'Native renderer binary present (cli\windows\vs10\bin64\upovconsole64.exe, checked into git).'
} else {
    Write-WarnStep 'cli\windows\vs10\bin64\upovconsole64.exe is missing  -  did the clone include binary files? ' +
        '(git-lfs / sparse-checkout can exclude it.) See CLAUDE.md "Native renderer commands" to rebuild it.'
}

# -- 2. SQL Server reachability -----------------------------------------------
Write-Section "SQL Server ($SqlInstanceName)"

function Resolve-SqlCmd {
    $cmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    # Known install locations, newest first: the standalone Microsoft.Sqlcmd (go-sqlcmd)
    # package, the ODBC Client SDK that ships with the engine, and older tool layouts.
    $candidates = @(
        Get-ChildItem -Path "$env:ProgramFiles\sqlcmd\sqlcmd.exe" -ErrorAction SilentlyContinue
        Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Links\sqlcmd.exe" -ErrorAction SilentlyContinue
        Get-ChildItem -Path "$env:ProgramFiles\Microsoft SQL Server\Client SDK\ODBC\*\Tools\Binn\SQLCMD.EXE" -ErrorAction SilentlyContinue
        Get-ChildItem -Path "${env:ProgramFiles(x86)}\Microsoft SQL Server\Client SDK\ODBC\*\Tools\Binn\SQLCMD.EXE" -ErrorAction SilentlyContinue
        Get-ChildItem -Path "${env:ProgramFiles(x86)}\Microsoft SQL Server\*\Tools\Binn\SQLCMD.EXE" -ErrorAction SilentlyContinue
    ) | Sort-Object FullName -Descending
    if ($candidates) { return $candidates[0].FullName }
    return $null
}

function Test-SqlReachable([string]$SqlCmdExe, [string]$Instance) {
    try {
        & $SqlCmdExe -S ".\$Instance" -E -Q "SET NOCOUNT ON; SELECT 1;" 2>$null 1>$null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Test-SqlServiceInstalled([string]$Instance) {
    # The service exists as soon as the engine is installed, independent of sqlcmd.
    return $null -ne (Get-Service -Name "MSSQL`$$Instance" -ErrorAction SilentlyContinue)
}

$script:SseiUrl = 'https://download.microsoft.com/download/5/1/4/5145fe04-4d30-4b85-b0d1-39533663a2f1/SQL2022-SSEI-Expr.exe'

function Install-SqlExpress([string]$Instance) {
    # NOTE: do NOT install this through winget with --override. That package downloads
    # SQL2022-SSEI-Expr.exe  -  a small *bootstrapper* whose argument set is only
    # /ACTION, /MEDIAPATH, /MEDIATYPE, /QUIET, /IACCEPTSQLSERVERLICENSETERMS, ... It
    # rejects every setup.exe parameter ("The setting 'instancename' is not recognized"),
    # and it cannot set a custom instance name at all. The supported unattended path is
    # three stages: bootstrapper downloads the media, the media self-extracts, and the
    # extracted SETUP.EXE takes the real parameters.
    Write-Do "Installing SQL Server 2022 Express (instance $Instance, Windows Authentication)."
    Write-Host '           Downloads ~300 MB and can take several minutes.' -ForegroundColor DarkGray

    $work      = Join-Path $env:TEMP "sqlexpress-setup-$Instance"
    $mediaDir  = Join-Path $work 'media'
    $extractTo = Join-Path $work 'extracted'
    New-Item -ItemType Directory -Force -Path $mediaDir  | Out-Null
    New-Item -ItemType Directory -Force -Path $extractTo | Out-Null

    try {
        # 1. Fetch the bootstrapper (same binary the winget package wraps).
        $ssei = Join-Path $work 'SQL2022-SSEI-Expr.exe'
        if (-not (Test-Path $ssei)) {
            Write-Host '           [1/3] downloading the SQL Server Express installer...' -ForegroundColor DarkGray
            Invoke-WebRequest -Uri $script:SseiUrl -OutFile $ssei -UseBasicParsing
        }

        # 2. Bootstrapper in Download mode -> SQLEXPR_x64_ENU.exe (the full media package).
        Write-Host '           [2/3] downloading the installation media...' -ForegroundColor DarkGray
        & $ssei /ACTION=Download /MEDIAPATH="$mediaDir" /MEDIATYPE=Core /QUIET /HIDEPROGRESSBAR | Out-Null

        $media = Get-ChildItem -Path $mediaDir -Filter 'SQLEXPR*.exe' -ErrorAction SilentlyContinue |
                 Sort-Object Length -Descending | Select-Object -First 1
        if (-not $media) {
            Write-Fail "The installer did not produce the media package in $mediaDir. Install SQL Server Express manually and re-run."
            return
        }

        # 3. Self-extract, then run the real setup with the parameters that only it accepts.
        Write-Host '           [3/3] extracting and running SQL Server setup...' -ForegroundColor DarkGray
        & $media.FullName /Q /X:"$extractTo" | Out-Null

        $setup = Join-Path $extractTo 'SETUP.EXE'
        if (-not (Test-Path $setup)) {
            Write-Fail "SETUP.EXE not found under $extractTo after extraction. Install SQL Server Express manually and re-run."
            return
        }

        # /SECURITYMODE is omitted deliberately: its only valid value is "SQL" (mixed mode).
        # Windows-only authentication  -  which is what the app's Trusted_Connection string
        # needs  -  is what you get by leaving it out.
        $currentAccount = "$env:USERDOMAIN\$env:USERNAME"
        & $setup /ACTION=Install /QUIET /IACCEPTSQLSERVERLICENSETERMS `
                 /FEATURES=SQLEngine "/INSTANCENAME=$Instance" `
                 "/SQLSYSADMINACCOUNTS=$currentAccount" "BUILTIN\Administrators" `
                 /TCPENABLED=1 /NPENABLED=1 /UPDATEENABLED=0 /SUPPRESSPRIVACYSTATEMENTNOTICE
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) {
            Write-WarnStep "SQL Server setup returned exit code $LASTEXITCODE  -  see its log under C:\Program Files\Microsoft SQL Server\160\Setup Bootstrap\Log\."
        }
    }
    catch {
        Write-Fail "SQL Server Express install failed: $($_.Exception.Message)"
    }
    finally {
        # The extracted media is ~1 GB; keep the box tidy.
        try { Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue } catch { }
    }
}

function Install-SqlCmd {
    # SQL Server Express does NOT reliably ship sqlcmd  -  the command-line utilities are a
    # separate component. Install them explicitly rather than hoping the engine brought them.
    Write-Do 'Installing the SQL Server command-line utilities (sqlcmd)...'
    winget install --id Microsoft.Sqlcmd --silent --accept-package-agreements --accept-source-agreements

    # winget updates the machine PATH, but this already-running process keeps its old copy  - 
    # re-read it so Resolve-SqlCmd can see the new install without restarting the shell.
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

# Engine first, then the client tool. A fresh box has neither, and sqlcmd is only *needed*
# once there is a server to talk to  -  so a missing sqlcmd must never short-circuit the
# engine install (that ordering bug made this script unusable on a truly clean machine).
$engineInstalled = Test-SqlServiceInstalled $SqlInstanceName
if ($engineInstalled) {
    Write-Ok "SQL Server service MSSQL`$$SqlInstanceName is installed."
} elseif ($DryRun) {
    Write-Do "[dry run] Would install SQL Server 2022 Express as instance $SqlInstanceName."
} elseif ($InstallSqlExpress) {
    Install-SqlExpress $SqlInstanceName
    $engineInstalled = Test-SqlServiceInstalled $SqlInstanceName
    if (-not $engineInstalled) {
        Write-Fail "SQL Server Express install finished but service MSSQL`$$SqlInstanceName does not exist. Check the setup output above and the logs under 'C:\Program Files\Microsoft SQL Server\160\Setup Bootstrap\Log\'."
    }
} else {
    Write-WarnStep "No SQL Server instance named '$SqlInstanceName' on this box. Re-run with -InstallSqlExpress to install it automatically, or install manually and re-run."
    Write-Host "           Manual route: download SQL2022-SSEI-Expr.exe, run it with /ACTION=Download /MEDIAPATH=<dir> /MEDIATYPE=Core," -ForegroundColor DarkGray
    Write-Host "           extract the resulting SQLEXPR_x64_ENU.exe (/Q /X:<dir>), then run its SETUP.EXE with:" -ForegroundColor DarkGray
    Write-Host "           /ACTION=Install /QUIET /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SQLEngine /INSTANCENAME=$SqlInstanceName /SQLSYSADMINACCOUNTS=`"$env:USERDOMAIN\$env:USERNAME`" /TCPENABLED=1" -ForegroundColor DarkGray
    Write-Host "           (The winget package is only a bootstrapper  -  it rejects these parameters and cannot set an instance name.)" -ForegroundColor DarkGray
}

$sqlCmdExe = Resolve-SqlCmd
if (-not $sqlCmdExe -and -not $DryRun -and ($InstallSqlExpress -or $InstallFfmpeg -or $engineInstalled)) {
    Install-SqlCmd
    $sqlCmdExe = Resolve-SqlCmd
}

$sqlReady = $false
if ($DryRun -and -not $sqlCmdExe) {
    Write-Do '[dry run] Would install the SQL command-line utilities (winget install --id Microsoft.Sqlcmd).'
} elseif (-not $sqlCmdExe) {
    Write-Fail 'sqlcmd not found and not installed. Install it with: winget install --id Microsoft.Sqlcmd  (then re-run this script).'
} else {
    Write-Ok "sqlcmd resolved: $sqlCmdExe"

    if ($engineInstalled) {
        # The service can exist before it finishes starting, especially right after install.
        Write-Do 'Waiting for the SQL Server instance to accept connections (up to 3 minutes)...'
        $deadline = (Get-Date).AddMinutes(3)
        do {
            $sqlReady = Test-SqlReachable $sqlCmdExe $SqlInstanceName
            if (-not $sqlReady) { Start-Sleep -Seconds 5 }
        } while (-not $sqlReady -and (Get-Date) -lt $deadline)

        if ($sqlReady) {
            Write-Ok "Instance .\$SqlInstanceName is reachable."
        } else {
            Write-Fail "Instance .\$SqlInstanceName is installed but not reachable. Check that service MSSQL`$$SqlInstanceName is running, then re-run this script."
        }
    }
}

# -- 3. Database + schema -----------------------------------------------------
Write-Section "Database ($DatabaseName)"

if (-not $sqlReady) {
    Write-Skip 'SQL Server not reachable  -  skipping database/schema setup.'
} else {
    $dbScripts = @(
        @{ File = '001_create_database.sql'; Db = $null;         Label = 'CREATE DATABASE' }
        @{ File = '002_api_logging.sql';     Db = $DatabaseName; Label = 'api.* logging tables' }
        @{ File = '003_hangfire_install.sql';Db = $DatabaseName; Label = 'Hangfire schema' }
        @{ File = '004_animation_jobs.sql';  Db = $DatabaseName; Label = 'distributed animation tables' }
        @{ File = '005_mcp.sql';             Db = $DatabaseName; Label = 'MCP server tables' }
    )
    foreach ($step in $dbScripts) {
        $scriptPath = Join-Path $RepoRoot "db\$($step.File)"
        if (-not (Test-Path $scriptPath)) { Write-Fail "Missing $scriptPath"; continue }

        if ($DryRun) {
            Write-Do "[dry run] Would run db\$($step.File) ($($step.Label))"
            continue
        }

        # -I sets QUOTED_IDENTIFIER ON, which sqlcmd otherwise leaves OFF. Required:
        # both db\002 and the vendored Hangfire db\003 create indexes that SQL Server
        # refuses under QUOTED_IDENTIFIER OFF (Msg 1934). db\003 cannot carry its own
        # SET statement because it is re-exported verbatim from the Hangfire package,
        # so the flag belongs here. Only shows up on a genuinely fresh database  -  an
        # already-installed schema no-ops before reaching the CREATE INDEX.
        #
        # 001 runs against master and takes the database name as a sqlcmd variable;
        # 002-004 run inside the database via -d. Both therefore honor -DatabaseName.
        $args = @('-S', ".\$SqlInstanceName", '-E', '-b', '-I', '-v', "DbName=$DatabaseName", '-i', $scriptPath)
        if ($step.Db) { $args = @('-S', ".\$SqlInstanceName", '-E', '-b', '-I', '-d', $step.Db, '-i', $scriptPath) }

        & $sqlCmdExe @args
        if ($LASTEXITCODE -eq 0) { Write-Ok "db\$($step.File) applied ($($step.Label))." }
        else { Write-Fail "db\$($step.File) failed (sqlcmd exit $LASTEXITCODE)  -  see output above." }
    }
}

if ($UpdateAppSettings -and -not $DryRun) {
    $devSettingsPath = Join-Path $WebRoot 'appsettings.Development.json'
    if (Test-Path $devSettingsPath) {
        # Only Server/Database are written. User stays empty (Windows auth) and the
        # password is never written to a tracked file  -  it belongs in user-secrets
        # (dotnet user-secrets set "Db:Password" ...) or the Db__Password env var.
        $json = Get-Content $devSettingsPath -Raw | ConvertFrom-Json
        if (-not $json.PSObject.Properties.Match('Db').Count) {
            $json | Add-Member -MemberType NoteProperty -Name Db -Value ([pscustomobject]@{
                Server = ''; Database = ''; User = ''; Password = ''
            })
        }
        $wantServer = ".\$SqlInstanceName"
        if ($json.Db.Server -ne $wantServer -or $json.Db.Database -ne $DatabaseName) {
            $json.Db.Server   = $wantServer
            $json.Db.Database = $DatabaseName
            ($json | ConvertTo-Json -Depth 10) | Set-Content -Path $devSettingsPath -Encoding UTF8
            Write-Ok "appsettings.Development.json Db section updated (Server=$wantServer, Database=$DatabaseName)."
        } else {
            Write-Ok 'appsettings.Development.json Db section already matches.'
        }
    } else {
        Write-WarnStep "appsettings.Development.json not found at $devSettingsPath  -  nothing to update."
    }
}

# -- 4. Filesystem paths from AppConfig ---------------------------------------
Write-Section 'AppConfig data folders'

$appSettingsPath = Join-Path $WebRoot 'appsettings.json'
if (-not (Test-Path $appSettingsPath)) {
    Write-Fail "appsettings.json not found at $appSettingsPath  -  skipping."
} else {
    $config = (Get-Content $appSettingsPath -Raw | ConvertFrom-Json).AppConfig

    function Resolve-AppConfigPath([string]$Value) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
        if ([System.IO.Path]::IsPathRooted($Value)) { return $Value }
        return (Join-Path $WebRoot $Value)   # matches Program.cs's own relative-path resolution
    }

    function Ensure-Directory([string]$Label, [string]$Value) {
        $path = Resolve-AppConfigPath $Value
        if (-not $path) { Write-Skip "$Label  -  not configured, skipping."; return }
        if (Test-Path $path) { Write-Ok "$Label -> $path (already exists)"; return }
        if ($DryRun) { Write-Do "[dry run] Would create $Label -> $path"; return }
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Ok "$Label -> $path (created)"
    }

    function Ensure-ParentOfFile([string]$Label, [string]$Value) {
        $path = Resolve-AppConfigPath $Value
        if (-not $path) { Write-Skip "$Label  -  not configured, skipping."; return }
        $dir = Split-Path -Parent $path
        if (-not $dir -or (Test-Path $dir)) { Write-Ok "$Label's folder -> $dir (already exists)"; return }
        if ($DryRun) { Write-Do "[dry run] Would create $Label's folder -> $dir"; return }
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Ok "$Label's folder -> $dir (created)"
    }

    function Verify-OnlyPath([string]$Label, [string]$Value, [string]$Hint) {
        $path = Resolve-AppConfigPath $Value
        if (-not $path) { Write-Skip "$Label  -  not configured, skipping."; return }
        if (Test-Path $path) { Write-Ok "$Label -> $path" }
        else { Write-WarnStep "$Label -> $path (MISSING). $Hint" }
    }

    # Output/working directories the app writes into  -  safe to create.
    Ensure-Directory 'ImagesPath'          $config.ImagesPath
    Ensure-Directory 'AnimationsPath'      $config.AnimationsPath
    Ensure-Directory 'ScenesPath'          $config.ScenesPath
    Ensure-Directory 'ScenesBulkPath'      $config.ScenesBulkPath
    Ensure-Directory 'SourceImagesPath'    $config.SourceImagesPath
    Ensure-Directory 'WorkingPath'         $config.WorkingPath
    Ensure-Directory 'SpectralOutputPath'  $config.SpectralOutputPath
    Ensure-Directory 'ApiRenderOutputPath' $config.ApiRenderOutputPath

    # Files the app appends to at runtime  -  only the parent folder needs to exist.
    Ensure-ParentOfFile 'SceneQueuePath' $config.SceneQueuePath
    Ensure-ParentOfFile 'BatchQueuePath' $config.BatchQueuePath
    Ensure-ParentOfFile 'RenderLogPath'  $config.RenderLogPath

    # Repo-tracked content or a sibling project's output  -  a miss here means
    # something else is wrong (bad clone, sibling repo not checked out), so
    # verify and warn rather than fabricate an empty folder.
    Verify-OnlyPath 'IncludesPath'         $config.IncludesPath         'Expected to ship with the repo under cli\distribution\include.'
    Verify-OnlyPath 'TemplatesPath'        $config.TemplatesPath        'Expected to ship with the repo under PovCliNet.Web\templates.'
    Verify-OnlyPath 'PresetsPath'          $config.PresetsPath          'Expected to ship with the repo under presets\render-quality.md.'
    Verify-OnlyPath 'SpectralScenesPath'   $config.SpectralScenesPath   'Points at a sibling project (povLaser)  -  only needed for the Spectral page.'
    Verify-OnlyPath 'SpectralIncludesPath' $config.SpectralIncludesPath 'Points at a sibling project (povLaser)  -  only needed for the Spectral page.'
}

# -- 5. ffmpeg -----------------------------------------------------------------
Write-Section 'ffmpeg'

$ffmpegConfigPath = $null
if (Test-Path $appSettingsPath) {
    $ffmpegConfigPath = (Get-Content $appSettingsPath -Raw | ConvertFrom-Json).AppConfig.FfmpegPath
}
$ffmpegFound = ($ffmpegConfigPath -and (Test-Path $ffmpegConfigPath)) -or (Get-Command ffmpeg -ErrorAction SilentlyContinue)

if ($ffmpegFound) {
    Write-Ok 'ffmpeg found (used for orbital/video MP4 assembly).'
} elseif ($InstallFfmpeg -and -not $DryRun) {
    Write-Do 'Installing ffmpeg via winget (Gyan.FFmpeg)...'
    winget install --id Gyan.FFmpeg -e --silent --accept-package-agreements --accept-source-agreements
    if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
        Write-Ok 'ffmpeg installed. Update AppConfig:FfmpegPath in appsettings.json if it is not resolved via PATH.'
    } else {
        Write-WarnStep 'ffmpeg install finished but ffmpeg is not resolving on PATH yet  -  you may need to restart the shell.'
    }
} elseif ($DryRun -and -not $ffmpegFound) {
    Write-Do '[dry run] Would install ffmpeg via winget (Gyan.FFmpeg).'
} else {
    Write-WarnStep 'ffmpeg not found. Orbital MP4 assembly and the Video page will not work until AppConfig:FfmpegPath points at a real ffmpeg.exe. Re-run with -InstallFfmpeg, or: winget install --id Gyan.FFmpeg'
}

# -- Summary -------------------------------------------------------------------
Write-Section 'Summary'
if ($DryRun) {
    Write-Host '  Dry run  -  nothing was installed, created, or executed.' -ForegroundColor Cyan
} elseif ($hadFailure) {
    Write-Host '  Completed with failures  -  see [fail] lines above.' -ForegroundColor Red
    exit 1
} elseif ($hadWarning) {
    Write-Host '  Completed with warnings  -  see [warn] lines above.' -ForegroundColor Yellow
} else {
    Write-Host '  Environment ready.' -ForegroundColor Green
}
