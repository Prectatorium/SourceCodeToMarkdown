function Export-SourceCodeToMarkdown {
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

                # Write header
                $streamWriter.WriteLine("# Source Code Export")
                $streamWriter.WriteLine("> Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
                $streamWriter.WriteLine("> Source: $resolvedPath")
                $streamWriter.WriteLine()
                $streamWriter.WriteLine("---")
                $streamWriter.WriteLine()

                # Visual Tree Section
                if ($IncludeVisualTree) {
                    Write-Verbose "Generating visual tree structure"
                    $streamWriter.WriteLine("## Directory Structure")
                    $streamWriter.WriteLine('```text')
                    
                    $treeContent = Get-DirectoryTree -RootPath $resolvedPath -FileList $filesToProcess
                    $streamWriter.WriteLine($treeContent)
                    
                    $streamWriter.WriteLine('```')
                    $streamWriter.WriteLine()
                    $streamWriter.WriteLine("---")
                    $streamWriter.WriteLine()
                }

                # Table of Contents Section
                if ($IncludeTableOfContents) {
                    Write-Verbose "Generating table of contents"
                    $streamWriter.WriteLine("## Table of Contents")
                    $streamWriter.WriteLine()

                    foreach ($file in $filesToProcess) {
                        $relativePath = [System.IO.Path]::GetRelativePath($resolvedPath, $file.FullName)
                        $anchor = Get-MarkdownAnchor -Text "file-$relativePath"
                        $streamWriter.WriteLine("- [$relativePath]($anchor)")
                    }
                    
                    $streamWriter.WriteLine()
                    $streamWriter.WriteLine("---")
                    $streamWriter.WriteLine()
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
                        $streamWriter.WriteLine("## File: $relativePath")
                        $streamWriter.WriteLine("**Path:** `$relativePath`  ")
                        $streamWriter.WriteLine("**Size:** $($file.Length) bytes  ")
                        $streamWriter.WriteLine("**Modified:** $(Get-Date $file.LastWriteTime -Format 'yyyy-MM-dd HH:mm:ss')")
                        $streamWriter.WriteLine()

                        # Determine language for syntax highlighting
                        $extension = [System.IO.Path]::GetExtension($file.Name).ToLower()
                        $language = if ($languageMap.ContainsKey($extension)) {
                            $languageMap[$extension]
                        }
                        else {
                            'text'
                        }

                        # Write code block
                        $streamWriter.WriteLine("``````$language")
                        
                        $fileContent = Get-Content -Path $file.FullName -Raw -Encoding $defaultEncoding -ErrorAction Stop
                        
                        if ($IncludeLineNumbers) {
                            $lines = $fileContent -split "`r?`n"
                            $lineCount = $lines.Count
                            $padding = $lineCount.ToString().Length
                            
                            for ($i = 0; $i -lt $lineCount; $i++) {
                                $lineNumber = ($i + 1).ToString().PadLeft($padding, '0')
                                $streamWriter.WriteLine("${lineNumber}: $($lines[$i])")
                            }
                        }
                        else {
                            $streamWriter.WriteLine($fileContent)
                        }
                        
                        $streamWriter.WriteLine('```')
                        $streamWriter.WriteLine()
                        $streamWriter.WriteLine("---")
                        $streamWriter.WriteLine()

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