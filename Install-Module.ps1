<#
.SYNOPSIS
    Installs the SourceCodeToMarkdown module and verifies environment readiness.
#>
param(
    [Parameter()]
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser',

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ModuleName = "SourceCodeToMarkdown"

# 1. Elevation Check for AllUsers scope
if ($Scope -eq 'AllUsers') {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "Administrative privileges are required to install for 'AllUsers'. Please restart PowerShell as Administrator."
    }
}

try {
    # 2. Determine and Create Destination
    $moduleRoot = if ($Scope -eq 'CurrentUser') {
        Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell\Modules"
    }
    else {
        Join-Path ([Environment]::GetFolderPath('ProgramFiles')) "PowerShell\Modules"
    }

    $destination = Join-Path $moduleRoot $ModuleName
    $source = $PSScriptRoot

    Write-Host "--- Starting Installation for $ModuleName ---" -ForegroundColor Cyan

    if (Test-Path $destination) {
        if ($Force) {
            Write-Verbose "Removing existing version at $destination"
            Remove-Item $destination -Recurse -Force
        }
        else {
            throw "Module already exists at $destination. Use -Force to overwrite."
        }
    }

    # 3. Perform Copy (Excluding git/meta files)
    Write-Host "Installing to: $destination" -ForegroundColor Gray
    New-Item -ItemType Directory -Path $destination -Force | Out-Null

    # Selective copy to avoid infinite loops if installing from within the destination
    Get-ChildItem -Path $source -Exclude ".git", ".vscode", "tests" | Copy-Item -Destination $destination -Recurse -Force

    # 4. Update Session and Environment
    if ($env:PSModulePath -notlike "*$moduleRoot*") {
        Write-Host "Updating PSModulePath for current session..." -ForegroundColor Gray
        $env:PSModulePath += ";$moduleRoot"
    }

    # 5. Import and Verification
    Write-Host "Verifying installation..." -ForegroundColor Cyan
    Import-Module $destination -Force

    $cmd = Get-Command -Module $ModuleName -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host "Success! Module '$ModuleName' is now available." -ForegroundColor Green
        Write-Host "Try running: Get-Help Export-SourceCodeToMarkdown -Examples" -ForegroundColor White
    }
    else {
        throw "Module imported but commands were not found."
    }

    # 6. Summary Output
    [PSCustomObject]@{
        ModuleName  = $ModuleName
        Version     = (Get-Module $ModuleName).Version
        InstallPath = $destination
        Scope       = $Scope
        DateTime    = Get-Date
    }
}
catch {
    Write-Error "Installation failed: $($_.Exception.Message)"
}