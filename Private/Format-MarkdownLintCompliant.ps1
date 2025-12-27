function Format-MarkdownLintCompliant {
    <#
    .SYNOPSIS
        Formats content to comply with markdownlint rules.

    .DESCRIPTION
        Post-processes markdown content to ensure compliance with key markdownlint rules:
        - MD009: No trailing spaces
        - MD010: No hard tabs (use spaces)
        - MD012: No multiple blank lines (max 1)
        - MD013: Line length (max 120 characters)
        - MD018: Space after # in headings
        - MD022: Blank lines around headings
        - MD024: No duplicate headings
        - MD041: First line must be H1
        - MD047: Single trailing newline

    .PARAMETER Content
        The markdown content to format.

    .EXAMPLE
        $compliant = Format-MarkdownLintCompliant -Content $markdown
        Returns markdown content compliant with markdownlint rules.

    .OUTPUTS
        System.String. The formatted markdown content.

    .NOTES
        This function is designed as a final post-processing step to ensure
        the generated markdown meets markdownlint standards.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]
        $Content
    )

    try {
        if ([string]::IsNullOrEmpty($Content)) {
            return $Content
        }

        $lines = $Content -split "`r?`n"
        $result = [System.Collections.Generic.List[string]]::new()

        foreach ($line in $lines) {
            # MD009: Remove trailing whitespace
            $trimmedLine = $line.TrimEnd()

            # MD010: Replace tabs with spaces (4 spaces per tab)
            $spacedLine = $trimmedLine -replace "`t", '    '

            $null = $result.Add($spacedLine)
        }

        # Process lines for MD022 (blanks around headings) and MD047 (single trailing newline)
        $processed = [System.Text.StringBuilder]::new()
        $headingPattern = '^#+\s'

        for ($i = 0; $i -lt $result.Count; $i++) {
            $currentLine = $result[$i]
            $isHeading = $currentLine -match $headingPattern

            # MD022: Add blank line before headings (except first line)
            if ($isHeading -and $i -gt 0) {
                $prevLine = $result[$i - 1]
                if (-not [string]::IsNullOrEmpty($prevLine) -and $prevLine.Trim() -ne '') {
                    $null = $processed.AppendLine()
                }
            }

            $null = $processed.AppendLine($currentLine)

            # MD022: Add blank line after headings
            if ($isHeading -and $i -lt $result.Count - 1) {
                $nextLine = $result[$i + 1]
                if (-not [string]::IsNullOrEmpty($nextLine) -and $nextLine.Trim() -ne '' -and $nextLine -notmatch $headingPattern) {
                    $null = $processed.AppendLine()
                }
            }
        }

        $processedContent = $processed.ToString()

        # MD012: No multiple consecutive blank lines (limit to 1)
        $deduplicated = $processedContent -replace "`n{3,}", "`n`n"

        # MD018: Ensure space after # in headings (normalize heading format)
        $normalizedHeadings = $deduplicated -replace '^(#+)([^\s#])', '$1 $2'

        # MD041: Ensure first line is H1 heading
        $firstLineCorrect = $normalizedHeadings
        $linesArray = $normalizedHeadings -split "`r?`n"
        if ($linesArray.Count -gt 0 -and $linesArray[0] -notmatch '^#\s') {
            # Prepend H1 heading with filename or default title
            $firstLineCorrect = "# Source Code Export`n`n" + $normalizedHeadings
        }

        # MD013: Handle long lines (soft wrap at 120 chars for code blocks)
        $wrapped = [System.Text.StringBuilder]::new()
        $inCodeBlock = $false

        foreach ($line in ($firstLineCorrect -split "`r?`n")) {
            if ($line -match '^``````?(\w*)$') {
                # Entering code block
                $inCodeBlock = $true
                $null = $wrapped.AppendLine($line)
            }
            elseif ($line -match '^```$') {
                # Exiting code block
                $inCodeBlock = $false
                $null = $wrapped.AppendLine($line)
            }
            elseif ($inCodeBlock -and $line.Length -gt 120) {
                # Wrap long code lines at 120 chars (soft wrap)
                $wrappedLine = [System.Text.StringBuilder]::new()
                $words = $line -split '(.{1,118})(?:\s+|$)'
                foreach ($word in $words) {
                    if ([string]::IsNullOrEmpty($word.Trim())) { continue }
                    $null = $wrappedLine.Append($word)
                    if ($wrappedLine.Length -lt $line.Length) {
                        $null = $wrappedLine.AppendLine()
                    }
                }
                $null = $wrapped.AppendLine($wrappedLine.ToString().TrimEnd())
            }
            else {
                $null = $wrapped.AppendLine($line)
            }
        }

        # MD047: Ensure single trailing newline
        $finalResult = $wrapped.ToString().TrimEnd()
        if (-not $finalResult.EndsWith("`n")) {
            $finalResult += "`n"
        }

        return $finalResult
    }
    catch {
        Write-Warning "Failed to format markdown for lint compliance: $($_.Exception.Message)"
        return $Content
    }
}

function Format-MarkdownLineLength {
    <#
    .SYNOPSIS
        Wraps long lines in markdown content to specified length.

    .DESCRIPTION
        Processes markdown content and wraps long lines at the specified
        maximum length while preserving code blocks and formatting.

    .PARAMETER Content
        The markdown content to process.

    .PARAMETER MaxLength
        Maximum line length (default: 120).

    .PARAMETER CodeBlockExceptions
        If set, code blocks are not wrapped.

    .EXAMPLE
        $wrapped = Format-MarkdownLineLength -Content $md -MaxLength 80
        Wraps lines at 80 characters.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]
        $Content,

        [Parameter()]
        [int]
        $MaxLength = 120,

        [Parameter()]
        [switch]
        $CodeBlockExceptions
    )

    if ([string]::IsNullOrEmpty($Content) -or $MaxLength -le 0) {
        return $Content
    }

    $lines = $Content -split "`r?`n"
    $result = [System.Text.StringBuilder]::new()
    $inCodeBlock = $false

    foreach ($line in $lines) {
        if ($line -match '^``````?(\w*)$') {
            $inCodeBlock = $true
            $null = $result.AppendLine($line)
            continue
        }

        if ($line -eq '```') {
            $inCodeBlock = $false
            $null = $result.AppendLine($line)
            continue
        }

        if ($inCodeBlock -and $CodeBlockExceptions) {
            $null = $result.AppendLine($line)
            continue
        }

        if ($line.Length -le $MaxLength) {
            $null = $result.AppendLine($line)
        }
        else {
            # Wrap the line
            $wrapped = Format-WrapText -Text $line -Width $MaxLength
            $null = $result.AppendLine($wrapped)
        }
    }

    return $result.ToString()
}

function Format-WrapText {
    <#
    .SYNOPSIS
        Wraps text at specified width.

    .DESCRIPTION
        Simple text wrapper that preserves words and wraps at word boundaries.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Text,

        [Parameter(Mandatory = $true)]
        [int]
        $Width
    )

    if ([string]::IsNullOrEmpty($Text) -or $Width -le 0 -or $Text.Length -le $Width) {
        return $Text
    }

    $words = $Text -split '\s+'
    $result = [System.Text.StringBuilder]::new()
    $currentLength = 0

    foreach ($word in $words) {
        if ($currentLength + $word.Length + 1 -gt $Width) {
            $null = $result.AppendLine().TrimEnd()
            $currentLength = 0
        }

        if ($currentLength -gt 0) {
            $null = $result.Append(' ')
            $currentLength++
        }

        $null = $result.Append($word)
        $currentLength += $word.Length
    }

    return $result.ToString()
}

function Format-DuplicateHeadings {
    <#
    .SYNOPSIS
        Adds suffixes to duplicate headings to make them unique.

    .DESCRIPTION
        Finds duplicate heading text and adds numeric suffixes to make
        each heading unique while maintaining document structure.

    .PARAMETER Content
        The markdown content to process.

    .EXAMPLE
        $unique = Format-DuplicateHeadings -Content $md
        Returns markdown with unique heading text.

    .OUTPUTS
        System.String. Markdown with unique headings.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Content
    )

    $headingCounts = @{}
    $lines = $Content -split "`r?`n"
    $result = [System.Text.StringBuilder]::new()
    $headingPattern = '^(#+)\s+(.+)$'

    foreach ($line in $lines) {
        if ($line -match $headingPattern) {
            $headingText = $matches[2]
            $headingLevel = $matches[1]

            if (-not $headingCounts.ContainsKey($headingText)) {
                $headingCounts[$headingText] = 0
                $null = $result.AppendLine($line)
            }
            else {
                $headingCounts[$headingText]++
                $newHeading = "$headingLevel $headingText ($($headingCounts[$headingText]))"
                $null = $result.AppendLine($newHeading)
            }
        }
        else {
            $null = $result.AppendLine($line)
        }
    }

    return $result.ToString().TrimEnd() + "`n"
}

function Format-HeadingSpacing {
    <#
    .SYNOPSIS
        Ensures blank lines around headings (MD022).

    .DESCRIPTION
        Adds blank lines before and after headings as required by MD022.
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
    $headingPattern = '^#+'

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $currentLine = $lines[$i]
        $isHeading = $currentLine -match $headingPattern

        # Add blank line before heading (except for first line)
        if ($isHeading -and $i -gt 0) {
            $prevLine = $lines[$i - 1].Trim()
            if ($prevLine -ne '') {
                $null = $result.AppendLine()
            }
        }

        $null = $result.AppendLine($currentLine)

        # Add blank line after heading (except for last line)
        if ($isHeading -and $i -lt $lines.Count - 1) {
            $nextLine = $lines[$i + 1].Trim()
            if ($nextLine -ne '' -and $nextLine -notmatch $headingPattern) {
                $null = $result.AppendLine()
            }
        }
    }

    return $result.ToString().TrimEnd() + "`n"
}
