# List available modules
Get-Module -ListAvailable -Name SourceCodeToMarkdown

# Import the module
Import-Module SourceCodeToMarkdown -Force

# Test the function
Get-Command Export-SourceCodeToMarkdown

# Get help
Get-Help Export-SourceCodeToMarkdown -Examples