<#
.SYNOPSIS
    Mirrors a source folder tree onto a destination folder tree.

.DESCRIPTION
    After a run the destination matches the source:
      - files that exist only in the source are copied (parent folders are created)
      - files that exist in both but differ (size, then SHA-256) are overwritten
      - files and folders that exist only in the destination are DELETED

    Any '.git' folder (at any depth) and its contents are left completely alone:
    never copied, overwritten or deleted, whether it exists in the source, the destination, or both.

    The source is never modified. Use -WhatIf first to preview every copy and delete.

.PARAMETER Source
    Folder to copy from. Must exist. Defaults to the path hard-coded in the param block.

.PARAMETER Destination
    Folder to mirror into. Created if it does not exist. Defaults to the path hard-coded
    in the param block.

.EXAMPLE
    .\syncChanges.ps1 -WhatIf
    Uses the hard-coded default source and destination.

.EXAMPLE
    .\syncChanges.ps1 -Source C:\work\repo -Destination D:\backup\repo -WhatIf

.EXAMPLE
    .\syncChanges.ps1 C:\work\repo D:\backup\repo
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    # EDIT THESE: used when the script is run with no arguments (or with only one of the two).
    [Parameter(Position = 0)][string]$Source = 'C:\0000-Files\0009-Work\0000-GitHub\raytracingManager',
    [Parameter(Position = 1)][string]$Destination = 'CHANGE-ME-set-the-default-destination-in-syncChanges.ps1'
)

$ErrorActionPreference = 'Stop'

if ($Destination -like 'CHANGE-ME*') {
    throw "No destination given and the default in the script's param block has not been set. Edit `$Destination in syncChanges.ps1 or pass -Destination."
}

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    throw "Source folder not found: $Source"
}
$src = (Resolve-Path -LiteralPath $Source).ProviderPath.TrimEnd('\', '/')

if (-not (Test-Path -LiteralPath $Destination)) {
    if ($PSCmdlet.ShouldProcess($Destination, 'Create destination folder')) {
        New-Item -ItemType Directory -Path $Destination | Out-Null
    }
}
if (Test-Path -LiteralPath $Destination) {
    $dst = (Resolve-Path -LiteralPath $Destination).ProviderPath.TrimEnd('\', '/')
}
else {
    # only reachable under -WhatIf, when the destination was not actually created
    $dst = [System.IO.Path]::GetFullPath($Destination).TrimEnd('\', '/')
}

# A mirror that deletes must never have overlapping roots: nested trees would delete the source.
$sep = [System.IO.Path]::DirectorySeparatorChar
if ($src -ieq $dst -or
    ($dst + $sep).StartsWith($src + $sep, [System.StringComparison]::OrdinalIgnoreCase) -or
    ($src + $sep).StartsWith($dst + $sep, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Source and destination must not be the same folder or nested in one another: '$src' / '$dst'"
}

$copied = 0; $updated = 0; $deletedFiles = 0; $deletedDirs = 0

# Paths that are never touched (not copied, overwritten or deleted): any '.git' folder (or file) at any depth, and everything under it.
function Test-Protected([string]$relativePath) {
    return $relativePath -match '(^|[\\/])\.git([\\/]|$)'
}

# 1. Copy new files and overwrite changed ones.
Get-ChildItem -LiteralPath $src -Recurse -File -Force | ForEach-Object {
    $relative = $_.FullName.Substring($src.Length).TrimStart('\', '/')
    if (Test-Protected $relative) { return }
    $target = Join-Path $dst $relative

    if (-not (Test-Path -LiteralPath $target)) {
        if ($PSCmdlet.ShouldProcess($target, 'Copy new file')) {
            Write-Host "Adding   $relative"
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
            Copy-Item -LiteralPath $_.FullName -Destination $target -Force
            $copied++
        }
        return
    }

    $existing = Get-Item -LiteralPath $target -Force
    $differs = $existing.Length -ne $_.Length -or
        (Get-FileHash -LiteralPath $_.FullName).Hash -ne (Get-FileHash -LiteralPath $target).Hash
    if ($differs -and $PSCmdlet.ShouldProcess($target, 'Overwrite changed file')) {
        Write-Host "Updating $relative"
        Copy-Item -LiteralPath $_.FullName -Destination $target -Force
        $updated++
    }
}

# 2. Delete destination files that no longer exist in the source.
if (Test-Path -LiteralPath $dst) {
    Get-ChildItem -LiteralPath $dst -Recurse -File -Force | ForEach-Object {
        $relative = $_.FullName.Substring($dst.Length).TrimStart('\', '/')
        if (-not (Test-Protected $relative) -and
            -not (Test-Path -LiteralPath (Join-Path $src $relative) -PathType Leaf) -and
            $PSCmdlet.ShouldProcess($_.FullName, 'Delete file not in source')) {
            Write-Host "Deleting $relative"
            Remove-Item -LiteralPath $_.FullName -Force
            $deletedFiles++
        }
    }

    # 3. Delete destination folders that no longer exist in the source (deepest first).
    Get-ChildItem -LiteralPath $dst -Recurse -Directory -Force |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object {
            $relative = $_.FullName.Substring($dst.Length).TrimStart('\', '/')
            if (-not (Test-Protected $relative) -and
                -not (Test-Path -LiteralPath (Join-Path $src $relative) -PathType Container) -and
                (Test-Path -LiteralPath $_.FullName) -and
                $PSCmdlet.ShouldProcess($_.FullName, 'Delete folder not in source')) {
                Write-Host "Deleting $relative\"
                Remove-Item -LiteralPath $_.FullName -Recurse -Force
                $deletedDirs++
            }
        }
}

Write-Host ("Done: {0} added, {1} updated, {2} files deleted, {3} folders deleted." -f $copied, $updated, $deletedFiles, $deletedDirs)
