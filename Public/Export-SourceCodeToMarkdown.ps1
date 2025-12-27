function Export-SourceCodeToMarkdown {
    <#
    .SYNOPSIS
        Exports source code files from directories into consolidated Markdown documents.

    .DESCRIPTION
        The Export-SourceCodeToMarkdown cmdlet recursively traverses directory structures
        and consolidates source code files into a single Markdown document with optional
        features including:
        - Visual tree structure of directories
        - Table of contents with clickable links
        - Syntax highlighting for various programming languages
        - Line numbering in code blocks with customizable padding
        - File metadata and statistics
        - Configurable file inclusion/exclusion patterns
        - Optional comment removal from source files
        - MarkdownLint compliance for generated output

        The module is designed with performance and flexibility in mind, supporting large
        codebases with configurable size limits and error handling.

    .PARAMETER Path
        One or more directory paths containing source files to export. Wildcards are supported.

    .PARAMETER OutputPath
        The output Markdown file path. Must be a valid file path.

    .PARAMETER IncludePattern
        File inclusion patterns (e.g., '*.ps1', '*.cs'). Default is all files ('*').

    .PARAMETER ExcludePattern
        File exclusion patterns (e.g., '*.Designer.cs', '*.min.js').

    .PARAMETER ExcludeDirectory
        Directory names to exclude (e.g., 'bin', 'obj', '.git'). Default exclusions are
        configured in the module.

    .PARAMETER IncludeLineNumbers
        Adds line numbers to code blocks. Use -LineNumberPadding to customize formatting.

    .PARAMETER LineNumberPadding
        Specifies the padding character for line numbers. Valid values are 'spaces' (default)
        or 'zeros'. When set to 'spaces', line numbers are right-aligned with spaces. When
        set to 'zeros', line numbers are padded with leading zeros.

    .PARAMETER RemoveComments
        When enabled, removes comments from source code files before generating the Markdown.
        Supports PowerShell (#, <# #`>), C-style (//, /* */), HTML (<!-- -->), and SQL (--) comments.
        String literals are preserved to maintain code functionality.

    .PARAMETER IncludeTableOfContents
        Adds a navigable table of contents with anchor links to each file.

    .PARAMETER IncludeVisualTree
        Adds an ASCII-style visual representation of the directory structure.

    .PARAMETER Force
        Overwrites the output file without confirmation if it already exists.

    .PARAMETER ContinueOnError
        Continues processing even if errors occur, logging them to the summary.

    .EXAMPLE
        Export-SourceCodeToMarkdown -Path ".\src" -OutputPath ".\docs\source-export.md"

        Exports all files from the 'src' directory to 'source-export.md' with default settings.

    .EXAMPLE
        Export-SourceCodeToMarkdown -Path ".\src" -OutputPath ".\export.md" -IncludeTableOfContents -IncludeVisualTree -IncludeLineNumbers

        Exports with table of contents, visual tree, and line numbers.

    .EXAMPLE
        Export-SourceCodeToMarkdown -Path ".\project" -OutputPath ".\review.md" -IncludePattern "*.ps1", "*.cs" -IncludeLineNumbers -LineNumberPadding 'zeros'

        Exports PowerShell and C# files with zero-padded line numbers (001, 002, etc.).

    .EXAMPLE
        Export-SourceCodeToMarkdown -Path ".\src" -OutputPath ".\clean-export.md" -RemoveComments -IncludeLineNumbers

        Exports source files with comments removed while preserving line numbers.

    .EXAMPLE
        Export-SourceCodeToMarkdown -Path ".\src", ".\tests" -OutputPath ".\full-export.md" -ExcludeDirectory "bin", "obj", ".git" -Force

        Exports from multiple directories, excluding common build directories.

    .OUTPUTS
        PSCustomObject. Returns a summary object with destination path, file count, size, duration, and error information.

    .NOTES
        Performance considerations:
        - Processing large repositories may take significant time and memory
        - Consider using more specific IncludePatterns for large codebases
        - Output files can become very large; monitor file size
        - Binary files are automatically skipped
        - File size limits are configurable through module variables

        MarkdownLint compliance:
        - Generated output complies with MD009, MD010, MD012, MD013, MD018, MD022, MD024, MD041, MD047
        - Use the -RemoveComments switch to strip comments before export
        - Line numbering is applied after comment removal for accurate line references

    .LINK
        https://github.com/Prectatorium/SourceCodeToMarkdown
    #>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Medium'
    )]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            HelpMessage = 'Enter one or more directory paths containing source files'
        )]
        [ValidateScript({
                foreach ($item in $_) {
                    if (-not (Test-Path -Path $item -PathType Container)) {
                        throw "Path '$item' does not exist or is not a directory"
                    }
                }
                $true
            })]
        [Alias('SourcePath', 'Directory')]
        [string[]]
        $Path,

        [Parameter(
            Mandatory = $true,
            Position = 1,
            HelpMessage = 'Enter the output Markdown file path'
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('OutputFile', 'Destination')]
        [string]
        $OutputPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias('Include')]
        [string[]]
        $IncludePattern = @('*'),

        [Parameter()]
        [Alias('Exclude')]
        [string[]]
        $ExcludePattern,

        [Parameter()]
        [string[]]
        $ExcludeDirectory = $Script:ModuleConfig.DefaultExcludedDirectories,

        [Parameter()]
        [Alias('LineNumbers')]
        [switch]
        $IncludeLineNumbers,

        [Parameter()]
        [ValidateSet('spaces', 'zeros')]
        [string]
        $LineNumberPadding = 'spaces',

        [Parameter()]
        [Alias('StripComments', 'NoComments')]
        [switch]
        $RemoveComments,

        [Parameter()]
        [Alias('TOC')]
        [switch]
        $IncludeTableOfContents,

        [Parameter()]
        [Alias('Tree')]
        [switch]
        $IncludeVisualTree,

        [Parameter()]
        [switch]
        $Force,

        [Parameter()]
        [switch]
        $ContinueOnError
    )

    begin {
        Write-Debug "Function execution started at $(Get-Date)"

        # Performance tracking
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $totalFilesProcessed = 0
        $totalBytesProcessed = 0
        $filesWithErrors = [System.Collections.Generic.List[string]]::new()

        # Configuration from module
        $MAX_INDIVIDUAL_FILE_SIZE = $Script:ModuleConfig.MaxIndividualFileSize
        $MAX_TOTAL_OUTPUT_SIZE = $Script:ModuleConfig.MaxTotalOutputSize
        $languageMap = $Script:ModuleConfig.LanguageMap
        $defaultEncoding = $Script:ModuleConfig.DefaultEncoding

        # Determine padding character for line numbers
        $paddingChar = if ($LineNumberPadding -eq 'zeros') { '0' } else { ' ' }

        # Validate and prepare output path
        try {
            $fullOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
            $outputDirectory = [System.IO.Path]::GetDirectoryName($fullOutputPath)

            # Ensure output directory exists
            if (-not (Test-Path -Path $outputDirectory -PathType Container)) {
                Write-Verbose "Creating output directory: $outputDirectory"
                New-Item -Path $outputDirectory -ItemType Directory -Force | Out-Null
            }

            # Check if output file exists
            if (Test-Path -Path $fullOutputPath -PathType Leaf) {
                if ($Force -or $PSCmdlet.ShouldContinue(
                        "Output file '$fullOutputPath' already exists. Overwrite?",
                        "Confirm Overwrite"
                    )) {
                    Write-Verbose "Output file will be overwritten: $fullOutputPath"
                }
                else {
                    throw "Operation cancelled by user"
                }
            }
        }
        catch {
            throw "Failed to validate output path: $($_.Exception.Message)"
        }

        # Initialize output writer
        $streamWriter = $null
        try {
            $streamWriter = [System.IO.StreamWriter]::new($fullOutputPath, $false, $defaultEncoding)
        }
        catch {
            throw "Failed to create output file writer: $($_.Exception.Message)"
        }
    }

    process {
        foreach ($inputPath in $Path) {
            try {
                $resolvedPath = Resolve-Path -Path $inputPath -ErrorAction Stop
                Write-Verbose "Processing directory: $resolvedPath"

                # Get all files recursively
                $allFiles = Get-ChildItem -Path $resolvedPath -File -Recurse -Include $IncludePattern -ErrorAction SilentlyContinue

                if ($ExcludePattern) {
                    $allFiles = $allFiles | Where-Object {
                        $excludeFile = $false
                        foreach ($pattern in $ExcludePattern) {
                            if ($_.Name -like $pattern) {
                                $excludeFile = $true
                                break
                            }
                        }
                        -not $excludeFile
                    }
                }

                # Filter excluded directories
                $filesToProcess = $allFiles | Where-Object {
                    -not (Test-ExcludedDirectory -FilePath $_.FullName -ExcludedDirectories $ExcludeDirectory)
                }

                Write-Verbose "Found $($filesToProcess.Count) files to process in $resolvedPath"

                if ($filesToProcess.Count -eq 0) {
                    Write-Warning "No files found matching criteria in path: $resolvedPath"
                    continue
                }

                # Build file content buffer for markdownlint formatting
                $outputBuffer = [System.Text.StringBuilder]::new()

                # Write header
                $null = $outputBuffer.AppendLine("# Source Code Export")
                $null = $outputBuffer.AppendLine("> Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
                $null = $outputBuffer.AppendLine("> Source: $resolvedPath")
                $null = $outputBuffer.AppendLine()
                $null = $outputBuffer.AppendLine("---")
                $null = $outputBuffer.AppendLine()

                # Visual Tree Section
                if ($IncludeVisualTree) {
                    Write-Verbose "Generating visual tree structure"
                    $null = $outputBuffer.AppendLine("## Directory Structure")
                    $null = $outputBuffer.AppendLine('```text')

                    $treeContent = Get-DirectoryTree -RootPath $resolvedPath -FileList $filesToProcess
                    $null = $outputBuffer.AppendLine($treeContent)

                    $null = $outputBuffer.AppendLine('```')
                    $null = $outputBuffer.AppendLine()
                    $null = $outputBuffer.AppendLine("---")
                    $null = $outputBuffer.AppendLine()
                }

                # Table of Contents Section
                if ($IncludeTableOfContents) {
                    Write-Verbose "Generating table of contents"
                    $null = $outputBuffer.AppendLine("## Table of Contents")
                    $null = $outputBuffer.AppendLine()

                    foreach ($file in $filesToProcess) {
                        $relativePath = [System.IO.Path]::GetRelativePath($resolvedPath, $file.FullName)
                        $anchor = Get-MarkdownAnchor -Text "file-$relativePath"
                        $null = $outputBuffer.AppendLine("- [$relativePath]($anchor)")
                    }

                    $null = $outputBuffer.AppendLine()
                    $null = $outputBuffer.AppendLine("---")
                    $null = $outputBuffer.AppendLine()
                }

                # Process each file
                foreach ($file in $filesToProcess) {
                    $relativePath = [System.IO.Path]::GetRelativePath($resolvedPath, $file.FullName)

                    if (-not $PSCmdlet.ShouldProcess(
                            "File: $relativePath",
                            "Export to Markdown document"
                        )) {
                        Write-Verbose "Skipping file (WhatIf): $relativePath"
                        continue
                    }

                    try {
                        # Check file size limit
                        if ($file.Length -gt $MAX_INDIVIDUAL_FILE_SIZE) {
                            $message = "File '$relativePath' exceeds size limit ($([Math]::Round($file.Length / 1MB, 2))MB > $([Math]::Round($MAX_INDIVIDUAL_FILE_SIZE / 1MB, 2))MB)"
                            if ($ContinueOnError) {
                                Write-Warning "$message - Skipping"
                                $filesWithErrors.Add($relativePath)
                                continue
                            }
                            else {
                                throw $message
                            }
                        }

                        # Check total output size
                        if (($totalBytesProcessed + $file.Length) -gt $MAX_TOTAL_OUTPUT_SIZE) {
                            $message = "Total output size would exceed limit ($([Math]::Round($MAX_TOTAL_OUTPUT_SIZE / 1GB, 2))GB)"
                            if ($ContinueOnError) {
                                Write-Warning "$message - Stopping further processing"
                                break
                            }
                            else {
                                throw $message
                            }
                        }

                        Write-Verbose "Processing file: $relativePath ($($file.Length) bytes)"

                        # Write file header
                        $null = $outputBuffer.AppendLine("## File: $relativePath")
                        $null = $outputBuffer.AppendLine("**Path:** `$relativePath")
                        $null = $outputBuffer.AppendLine("**Size:** $($file.Length) bytes")
                        $null = $outputBuffer.AppendLine("**Modified:** $(Get-Date $file.LastWriteTime -Format 'yyyy-MM-dd HH:mm:ss')")
                        $null = $outputBuffer.AppendLine()

                        # Determine language for syntax highlighting
                        $extension = [System.IO.Path]::GetExtension($file.Name).ToLower()
                        $language = if ($languageMap.ContainsKey($extension)) {
                            $languageMap[$extension]
                        }
                        else {
                            'text'
                        }

                        # Read file content
                        $fileContent = Get-Content -Path $file.FullName -Raw -Encoding $defaultEncoding -ErrorAction Stop

                        # Remove comments if requested
                        if ($RemoveComments) {
                            Write-Verbose "Removing comments from: $relativePath"
                            $fileContent = Remove-FileComments -Content $fileContent -Extension $extension
                        }

                        # Create code block
                        $null = $outputBuffer.AppendLine("``````$language")

                        if ($IncludeLineNumbers) {
                            $lines = $fileContent -split "`r?`n"
                            $lineCount = $lines.Count
                            $padding = $lineCount.ToString().Length

                            for ($i = 0; $i -lt $lineCount; $i++) {
                                $lineNumber = ($i + 1).ToString().PadLeft($padding, $paddingChar)
                                $null = $outputBuffer.AppendLine("${lineNumber}: $($lines[$i])")
                            }
                        }
                        else {
                            $null = $outputBuffer.Append($fileContent)
                        }

                        $null = $outputBuffer.AppendLine()
                        $null = $outputBuffer.AppendLine('```')
                        $null = $outputBuffer.AppendLine()
                        $null = $outputBuffer.AppendLine("---")
                        $null = $outputBuffer.AppendLine()

                        # Update counters
                        $totalFilesProcessed++
                        $totalBytesProcessed += $file.Length
                    }
                    catch {
                        $errorMessage = "Failed to process file '$relativePath': $($_.Exception.Message)"
                        if ($ContinueOnError) {
                            Write-Warning $errorMessage
                            $filesWithErrors.Add($relativePath)
                        }
                        else {
                            throw $errorMessage
                        }
                    }
                }

                # Apply markdownlint formatting to the entire buffer
                Write-Verbose "Applying markdownlint compliance formatting"
                $rawMarkdown = $outputBuffer.ToString()
                $formattedMarkdown = Format-MarkdownLintCompliant -Content $rawMarkdown

                # Write to output file
                $streamWriter.Write($formattedMarkdown)
            }
            catch {
                Write-Error "Failed to process path '$inputPath': $($_.Exception.Message)"
                if (-not $ContinueOnError) {
                    throw
                }
            }
        }
    }

    end {
        try {
            if ($null -ne $streamWriter) {
                $streamWriter.Dispose()
                Write-Verbose "Output stream closed"
            }

            $stopwatch.Stop()

            # Create summary object
            $summary = [PSCustomObject]@{
                DestinationPath  = $fullOutputPath
                TotalFiles       = $totalFilesProcessed
                TotalSizeMB      = [Math]::Round($totalBytesProcessed / 1MB, 2)
                Duration         = $stopwatch.Elapsed.ToString('hh\:mm\:ss\.fff')
                FilesWithErrors  = $filesWithErrors.Count
                OutputFileSizeMB = if (Test-Path $fullOutputPath) {
                    [Math]::Round((Get-Item $fullOutputPath).Length / 1MB, 2)
                }
                else { 0 }
                Success          = ($filesWithErrors.Count -eq 0)
                Timestamp        = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            }

            # Write summary to verbose stream
            Write-Verbose @"
Export Summary:
- Destination: $($summary.DestinationPath)
- Files Processed: $($summary.TotalFiles)
- Total Data: $($summary.TotalSizeMB) MB
- Output Size: $($summary.OutputFileSizeMB) MB
- Duration: $($summary.Duration)
- Errors: $($summary.FilesWithErrors)
- Comment Removal: $($RemoveComments.IsPresent)
- Line Number Padding: $LineNumberPadding
- MarkdownLint Compliant: True
"@

            if ($filesWithErrors.Count -gt 0) {
                Write-Warning "Some files had errors during processing. Check verbose output for details."
                foreach ($failedFile in $filesWithErrors) {
                    Write-Verbose "Failed file: $failedFile"
                }
            }

            return $summary
        }
        catch {
            Write-Error "Failed during cleanup: $($_.Exception.Message)"
        }
        finally {
            Write-Debug "Function execution completed at $(Get-Date)"
        }
    }
}

# Define aliases
Set-Alias -Name Export-CodeToMarkdown -Value Export-SourceCodeToMarkdown -Scope Script
Set-Alias -Name Code2Md -Value Export-SourceCodeToMarkdown -Scope Script
