function Remove-FileComments {
    <#
    .SYNOPSIS
        Removes comments from file content based on file extension.

    .DESCRIPTION
        Strips various types of comments from source code files while preserving
        code functionality and string literals. Supports PowerShell, C#, Java,
        JavaScript, HTML, CSS, and other common comment styles.

    .PARAMETER Content
        The file content to remove comments from.

    .PARAMETER Extension
        The file extension to determine which comment style to use.

    .EXAMPLE
        $cleaned = Remove-FileComments -Content $content -Extension '.ps1'
        Removes PowerShell comments from the content.

    .OUTPUTS
        System.String. The content with comments removed.

    .NOTES
        Handles multi-line comments, preserves string literals, and maintains
        line structure for consistent line numbering.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]
        $Content,

        [Parameter(Mandatory = $true)]
        [string]
        $Extension
    )

    try {
        if ([string]::IsNullOrEmpty($Content)) {
            return $Content
        }

        $lowerExt = $Extension.ToLowerInvariant()

        # PowerShell comments: # ... and <# ... #>
        if ($lowerExt -in '.ps1', '.psm1', '.psd1', '.pssc', '.psrc') {
            return Remove-PowerShellComments -Content $Content
        }
        # C-style comments: // ... and /* ... */ (C#, Java, Java, JavaScript, etc.)
        elseif ($lowerExt -in '.cs', '.java', '.js', '.ts', '.c', '.cpp', '.h', '.hpp',
            '.go', '.rs', '.swift', '.kt', '.dart', '.php', '.rb', '.scss', '.less') {
            return Remove-CStyleComments -Content $Content
        }
        # HTML comments: <!-- ... -->
        elseif ($lowerExt -in '.html', '.htm', '.xhtml', '.xml', '.svg', '.razor') {
            return Remove-HtmlComments -Content $Content
        }
        # SQL comments: -- ... and /* ... */
        elseif ($lowerExt -in '.sql', '.psql', '.mysql') {
            return Remove-SqlComments -Content $Content
        }
        # Bash/Shell comments: # ...
        elseif ($lowerExt -in '.sh', '.bash', '.zsh', '.fish', '.ps1') {
            return Remove-PowerShellComments -Content $Content
        }
        # Python comments: # ...
        elseif ($lowerExt -in '.py', '.pyw') {
            return Remove-PythonComments -Content $Content
        }
        # CSS/HTML comments: /* ... */ and <!-- ... -->
        elseif ($lowerExt -in '.css', '.scss', '.sass', '.styl') {
            return Remove-CStyleComments -Content $Content
        }
        # XML comments: <!-- ... --> and <? ... ?>
        elseif ($lowerExt -in '.xml', '.csproj', '.fsproj', '.vbproj', '.sln', '.props', '.targets') {
            return Remove-HtmlComments -Content $Content
        }
        # JSON, YAML, Markdown, Docker, INI - no comments to remove
        elseif ($lowerExt -in '.json', '.yml', '.yaml', '.md', '.dockerfile', '.ini', '.cfg', '.conf', '.toml') {
            return $Content
        }
        # Default: try to remove C-style comments as fallback
        else {
            return Remove-CStyleComments -Content $Content
        }
    }
    catch {
        Write-Warning "Failed to remove comments from file: $($_.Exception.Message)"
        return $Content
    }
}

function Remove-PowerShellComments {
    <#
    .SYNOPSIS
        Removes PowerShell-style comments from content.

    .DESCRIPTION
        Strips both single-line (#) and multi-line (<# ... #`>) comments
        while preserving string literals and maintaining line structure.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Content
    )

    $lines = $Content -split "`r?`n"
    $result = [System.Text.StringBuilder]::new()

    foreach ($line in $lines) {
        $processedLine = $line

        # Track if we're inside a multi-line comment
        if ($script:MultiLineCommentState -and $script:MultiLineCommentState -gt 0) {
            # Look for end of multi-line comment
            $endIndex = $processedLine.IndexOf('#>')
            if ($endIndex -ge 0) {
                $script:MultiLineCommentState = 0
                # Keep everything after #>
                $processedLine = $processedLine.Substring($endIndex + 2).TrimStart()
                if ([string]::IsNullOrEmpty($processedLine)) {
                    $null = $result.AppendLine()
                    continue
                }
            }
            else {
                # Still inside multi-line comment, skip this line
                $null = $result.AppendLine()
                continue
            }
        }

        # Skip if line is entirely a comment (after trimming)
        $trimmedLine = $processedLine.TrimStart()
        if ([string]::IsNullOrEmpty($trimmedLine)) {
            $null = $result.AppendLine()
            continue
        }

        # Check for start of multi-line comment
        $mlStart = $processedLine.IndexOf('<#')
        if ($mlStart -ge 0) {
            # Check if it's inside a string (naive check)
            $beforeMl = $processedLine.Substring(0, $mlStart)
            $inString = Test-InString -Text $beforeMl
            if (-not $inString) {
                $script:MultiLineCommentState = 1
                $processedLine = $processedLine.Substring(0, $mlStart)
                if ([string]::IsNullOrEmpty($processedLine.Trim())) {
                    $null = $result.AppendLine()
                    continue
                }
            }
        }

        # Handle single-line comments (#)
        $commentIndex = -1
        $scanIndex = 0
        while ($scanIndex -lt $processedLine.Length) {
            $char = $processedLine[$scanIndex]
            if ($char -eq '"') {
                # Skip string literals
                $scanIndex++
                while ($scanIndex -lt $processedLine.Length -and $processedLine[$scanIndex] -ne '"') {
                    if ($processedLine[$scanIndex] -eq '\' -and $scanIndex + 1 -lt $processedLine.Length) {
                        $scanIndex++
                    }
                    $scanIndex++
                }
                $scanIndex++
            }
            elseif ($char -eq '#') {
                # Check if this is not inside a string and not a PowerShellv5 attribute
                if ($scanIndex -gt 0 -and $processedLine[$scanIndex - 1] -ne '[') {
                    $commentIndex = $scanIndex
                    break
                }
                $scanIndex++
            }
            else {
                $scanIndex++
            }
        }

        if ($commentIndex -ge 0) {
            $processedLine = $processedLine.Substring(0, $commentIndex).TrimEnd()
        }

        if ([string]::IsNullOrEmpty($processedLine)) {
            $null = $result.AppendLine()
        }
        else {
            $null = $result.AppendLine($processedLine)
        }
    }

    return $result.ToString()
}

function Remove-CStyleComments {
    <#
    .SYNOPSIS
        Removes C-style comments from content.

    .DESCRIPTION
        Strips both single-line (//) and multi-line (/* ... */) comments
        while preserving string literals and maintaining line structure.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Content
    )

    $lines = $Content -split "`r?`n"
    $result = [System.Text.StringBuilder]::new()
    $inMultiLineComment = $false

    foreach ($line in $lines) {
        $processedLine = $line

        if ($inMultiLineComment) {
            # Look for end of multi-line comment
            $endIndex = $processedLine.IndexOf('*/')
            if ($endIndex -ge 0) {
                $inMultiLineComment = $false
                $processedLine = $processedLine.Substring($endIndex + 2)
            }
            else {
                $null = $result.AppendLine()
                continue
            }
        }

        $trimmedLine = $processedLine.TrimStart()
        if ([string]::IsNullOrEmpty($trimmedLine)) {
            $null = $result.AppendLine()
            continue
        }

        # Process the line for comments
        $resultLine = [System.Text.StringBuilder]::new()
        $i = 0
        while ($i -lt $processedLine.Length) {
            $char = $processedLine[$i]

            if ($char -eq '"' -or $char -eq "'") {
                # Preserve string/char literals
                $quote = $char
                $null = $resultLine.Append($char)
                $i++
                while ($i -lt $processedLine.Length -and $processedLine[$i] -ne $quote) {
                    if ($processedLine[$i] -eq '\' -and $i + 1 -lt $processedLine.Length) {
                        $null = $resultLine.Append($processedLine[$i])
                        $null = $resultLine.Append($processedLine[$i + 1])
                        $i += 2
                    }
                    else {
                        $null = $resultLine.Append($processedLine[$i])
                        $i++
                    }
                }
                if ($i -lt $processedLine.Length) {
                    $null = $resultLine.Append($processedLine[$i])
                    $i++
                }
            }
            elseif ($i -lt $processedLine.Length - 1 -and $char -eq '/' -and $processedLine[$i + 1] -eq '*') {
                # Start of multi-line comment
                $inMultiLineComment = $true
                $i += 2
                while ($i -lt $processedLine.Length - 1 -and -not ($processedLine[$i] -eq '*' -and $processedLine[$i + 1] -eq '/')) {
                    $i++
                }
                if ($i -lt $processedLine.Length - 1) {
                    $i += 2
                }
            }
            elseif ($i -lt $processedLine.Length - 1 -and $char -eq '/' -and $processedLine[$i + 1] -eq '/') {
                # Single-line comment - skip rest of line
                break
            }
            else {
                $null = $resultLine.Append($char)
                $i++
            }
        }

        $finalLine = $resultLine.ToString().TrimEnd()
        if ([string]::IsNullOrEmpty($finalLine)) {
            $null = $result.AppendLine()
        }
        else {
            $null = $result.AppendLine($finalLine)
        }
    }

    return $result.ToString()
}

function Remove-HtmlComments {
    <#
    .SYNOPSIS
        Removes HTML-style comments from content.

    .DESCRIPTION
        Strips HTML comments (<!-- ... -->) while preserving content.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Content
    )

    # Remove HTML comments
    $result = $Content -replace '<!--.*?-->', ''

    # Also handle multi-line comments
    $result = $result -replace '<!--[\s\S]*?-->', ''

    return $result
}

function Remove-SqlComments {
    <#
    .SYNOPSIS
        Removes SQL-style comments from content.

    .DESCRIPTION
        Strips both single-line (--) and multi-line (/* ... */) comments.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Content
    )

    $lines = $Content -split "`r?`n"
    $result = [System.Text.StringBuilder]::new()
    $inMultiLineComment = $false

    foreach ($line in $lines) {
        $processedLine = $line

        if ($inMultiLineComment) {
            $endIndex = $processedLine.IndexOf('*/')
            if ($endIndex -ge 0) {
                $inMultiLineComment = $false
                $processedLine = $processedLine.Substring($endIndex + 2)
            }
            else {
                $null = $result.AppendLine()
                continue
            }
        }

        # Remove single-line comments (--) but preserve URLs
        $tempLine = $processedLine
        $resultLine = [System.Text.StringBuilder]::new()
        $i = 0
        while ($i -lt $tempLine.Length) {
            if ($i -lt $tempLine.Length - 1 -and $tempLine[$i] -eq '-' -and $tempLine[$i + 1] -eq '-') {
                # Check if this is a URL (http:// or https://)
                $beforeDash = $tempLine.Substring(0, $i).TrimEnd()
                if ($beforeDash -notmatch '://$') {
                    # It's a comment, skip rest of line
                    break
                }
            }
            elseif ($i -lt $tempLine.Length - 1 -and $tempLine[$i] -eq '/' -and $tempLine[$i + 1] -eq '*') {
                $inMultiLineComment = $true
                $i += 2
                while ($i -lt $tempLine.Length - 1 -and -not ($tempLine[$i] -eq '*' -and $tempLine[$i + 1] -eq '/')) {
                    $i++
                }
                if ($i -lt $tempLine.Length - 1) {
                    $i += 2
                }
            }
            else {
                $null = $resultLine.Append($tempLine[$i])
                $i++
            }
        }

        $finalLine = $resultLine.ToString().TrimEnd()
        if ([string]::IsNullOrEmpty($finalLine)) {
            $null = $result.AppendLine()
        }
        else {
            $null = $result.AppendLine($finalLine)
        }
    }

    return $result.ToString()
}

function Remove-PythonComments {
    <#
    .SYNOPSIS
        Removes Python-style comments from content.

    .DESCRIPTION
        Strips single-line comments (#) while preserving string literals.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Content
    )

    $lines = $Content -split "`r?`n"
    $result = [System.Text.StringBuilder]::new()

    foreach ($line in $lines) {
        $processedLine = $line

        # Skip empty lines
        $trimmedLine = $processedLine.TrimStart()
        if ([string]::IsNullOrEmpty($trimmedLine)) {
            $null = $result.AppendLine()
            continue
        }

        # Process line to remove comments while preserving strings
        $resultLine = [System.Text.StringBuilder]::new()
        $inString = $false
        $i = 0

        while ($i -lt $processedLine.Length) {
            $char = $processedLine[$i]

            if ($char -eq '"' -or $char -eq "'") {
                # Handle string literals
                $quote = $char
                $tripleCount = 0

                # Check for triple quotes
                if ($i + 2 -lt $processedLine.Length -and $processedLine.Substring($i, 3) -eq $quote + $quote + $quote) {
                    $tripleCount = 3
                }
                elseif ($i + 1 -lt $processedLine.Length -and $processedLine[$i + 1] -eq $quote) {
                    $tripleCount = 2
                }

                $null = $resultLine.Append($char)
                $i++

                if ($tripleCount -gt 0) {
                    $inString = $true
                    $null = $resultLine.Append($processedLine[$i])
                    $null = $resultLine.Append($processedLine[$i + 1])
                    $i += 2

                    while ($i -lt $processedLine.Length - $tripleCount + 1) {
                        if ($processedLine.Substring($i, $tripleCount) -eq $quote) {
                            $null = $resultLine.Append($processedLine.Substring($i, $tripleCount))
                            $i += $tripleCount
                            $inString = $false
                            break
                        }
                        else {
                            $null = $resultLine.Append($processedLine[$i])
                            $i++
                        }
                    }
                }
                else {
                    $i++
                    while ($i -lt $processedLine.Length -and $processedLine[$i] -ne $quote) {
                        if ($processedLine[$i] -eq '\' -and $i + 1 -lt $processedLine.Length) {
                            $null = $resultLine.Append($processedLine[$i])
                            $null = $resultLine.Append($processedLine[$i + 1])
                            $i += 2
                        }
                        else {
                            $null = $resultLine.Append($processedLine[$i])
                            $i++
                        }
                    }
                    if ($i -lt $processedLine.Length) {
                        $null = $resultLine.Append($processedLine[$i])
                        $i++
                    }
                }
            }
            elseif ($char -eq '#' -and -not $inString) {
                # Comment found outside string - trim and break
                break
            }
            else {
                $null = $resultLine.Append($char)
                $i++
            }
        }

        $finalLine = $resultLine.ToString().TrimEnd()
        if ([string]::IsNullOrEmpty($finalLine)) {
            $null = $result.AppendLine()
        }
        else {
            $null = $result.AppendLine($finalLine)
        }
    }

    return $result.ToString()
}

function Test-InString {
    <#
    .SYNOPSIS
        Naive check if position is inside a string literal.

    .DESCRIPTION
        Checks if a given position in the text is inside a string literal
        by counting unescaped quotes before that position.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Text
    )

    $quoteCount = 0
    $inEscape = $false

    for ($i = 0; $i -lt $Text.Length; $i++) {
        if ($inEscape) {
            $inEscape = $false
            continue
        }

        if ($Text[$i] -eq '\') {
            $inEscape = $true
        }
        elseif ($Text[$i] -eq '"') {
            $quoteCount++
        }
    }

    return ($quoteCount % 2) -eq 1
}
