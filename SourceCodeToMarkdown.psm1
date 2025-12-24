# SourceCodeToMarkdown.psm1
# Root module that imports all public and private functions

$PublicFunctions  = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)
$PrivateFunctions = @(Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue)

# Dot source all private functions first
foreach ($PrivateFunction in $PrivateFunctions) {
    try {
        . $PrivateFunction.FullName
        Write-Debug "Imported private function: $($PrivateFunction.Name)"
    }
    catch {
        Write-Error "Failed to import private function $($PrivateFunction.Name): $_"
    }
}

# Dot source all public functions
foreach ($PublicFunction in $PublicFunctions) {
    try {
        . $PublicFunction.FullName
        Write-Debug "Imported public function: $($PublicFunction.Name)"
    }
    catch {
        Write-Error "Failed to import public function $($PublicFunction.Name): $_"
    }
}

# Module-level variables and configuration
$Script:ModuleConfig = @{
    MaxIndividualFileSize = 50MB
    MaxTotalOutputSize    = 1GB
    DefaultEncoding       = [System.Text.Encoding]::UTF8
    DefaultExcludedDirectories = @('.git', 'bin', 'obj', 'node_modules', '.vs', 'dist', 'packages', '.idea', '__pycache__')
    LanguageMap = @{
        '.ps1'    = 'powershell'
        '.psm1'   = 'powershell'
        '.psd1'   = 'powershell'
        '.cs'     = 'csharp'
        '.js'     = 'javascript'
        '.ts'     = 'typescript'
        '.jsx'    = 'jsx'
        '.tsx'    = 'tsx'
        '.py'     = 'python'
        '.sql'    = 'sql'
        '.xml'    = 'xml'
        '.json'   = 'json'
        '.yml'    = 'yaml'
        '.yaml'   = 'yaml'
        '.md'     = 'markdown'
        '.css'    = 'css'
        '.scss'   = 'scss'
        '.less'   = 'less'
        '.html'   = 'html'
        '.htm'    = 'html'
        '.csproj' = 'xml'
        '.fsproj' = 'xml'
        '.vbproj' = 'xml'
        '.java'   = 'java'
        '.c'      = 'c'
        '.cpp'    = 'cpp'
        '.h'      = 'cpp'
        '.hpp'    = 'cpp'
        '.go'     = 'go'
        '.rs'     = 'rust'
        '.rb'     = 'ruby'
        '.php'    = 'php'
        '.swift'  = 'swift'
        '.kt'     = 'kotlin'
        '.dart'   = 'dart'
        '.sh'     = 'bash'
        '.bash'   = 'bash'
        '.zsh'    = 'bash'
    }
}

# Export module members
Export-ModuleMember -Function 'Export-SourceCodeToMarkdown'
Export-ModuleMember -Alias 'Export-CodeToMarkdown', 'Code2Md'

# Optional: Export configuration as read-only
foreach ($key in $Script:ModuleConfig.Keys) {
    Set-Variable -Name $key -Value $Script:ModuleConfig[$key] -Scope Script -Option ReadOnly
}