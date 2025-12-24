# Install-Module.ps1
param(
    [Parameter()]
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser'
)

$ErrorActionPreference = 'Stop'

try {
    # Determine destination based on scope
    if ($Scope -eq 'CurrentUser') {
        $destination = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath "PowerShell\Modules\SourceCodeToMarkdown"
    }
    else {
        $destination = Join-Path -Path ([Environment]::GetFolderPath('ProgramFiles')) -ChildPath "PowerShell\Modules\SourceCodeToMarkdown"
    }
    
    # Get the source path
    $source = Join-Path -Path $PSScriptRoot -ChildPath "*"
    
    Write-Host "Installing SourceCodeToMarkdown module to: $destination" -ForegroundColor Green
    
    # Create destination directory
    if (-not (Test-Path -Path $destination)) {
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
    }
    
    # Copy module files
    Copy-Item -Path $source -Destination $destination -Recurse -Force
    
    # Verify installation
    $installed = Test-Path -Path (Join-Path -Path $destination -ChildPath "SourceCodeToMarkdown.psd1")
    
    if ($installed) {
        Write-Host "Module installed successfully!" -ForegroundColor Green
        Write-Host "To use the module, run: Import-Module SourceCodeToMarkdown" -ForegroundColor Cyan
        Write-Host "Get help with: Get-Help Export-SourceCodeToMarkdown -Full" -ForegroundColor Cyan
    }
    else {
        Write-Error "Installation may have failed. Please check the destination path."
    }
}
catch {
    Write-Error "Installation failed: $_"
}