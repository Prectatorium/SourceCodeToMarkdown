@{
    # Basic module identification
    RootModule           = 'SourceCodeToMarkdown.psm1'
    ModuleVersion        = '2.0.1'
    GUID                 = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author               = 'Paul Kooiman'
    CompanyName          = 'Independent'
    Copyright            = '(c) 2025 Paul Kooiman. All rights reserved.'
    Description          = 'Exports source code files into consolidated, navigable Markdown documents with syntax highlighting and structured navigation.'

    # PowerShell requirements
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')

    # Module dependencies
    RequiredModules      = @()

    # Exported members
    FunctionsToExport    = @('Export-SourceCodeToMarkdown')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @('Export-CodeToMarkdown', 'Code2Md')

    # Module data
    PrivateData          = @{
        PSData = @{
            Tags         = @('Documentation', 'CodeReview', 'Markdown', 'Export', 'SourceCode')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ProjectUri   = 'https://github.com/Prectatorium/SourceCodeToMarkdown'
            ReleaseNotes = @'
## Version 2.0.0
- Added interactive directory tree visualization
- Implemented navigable table of contents with Markdown anchors
- Added optional line numbering in code blocks
- Enhanced performance for large codebases
- Configurable file size limits and exclusion patterns
- Improved error handling with continue-on-error support
'@
        }
    }
}