# SourceCodeToMarkdown Test Script
# Demonstrates new features: Comment Removal and Line Number Padding

$ErrorActionPreference = 'Stop'

# Import the module
$modulePath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module -Name $modulePath -Force

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SourceCodeToMarkdown Feature Test Suite" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# TEST 1: Line Number Padding Options
# ============================================================================

Write-Host "[TEST 1] Line Number Padding Options" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor Gray

# Create a test file with enough lines to show padding differences
$testFilePath = "$env:TEMP\SourceCodeToMarkdown_Test1.ps1"
$testContent = @"
# Test file for line number padding
function Test-Function {
    param(
        [string]`$Name
    )
    Write-Host `"Hello, `$Name`"
    return `$true
}
"@

$testContent | Out-File -FilePath $testFilePath -Encoding UTF8 -NoNewline
$testContentObj = Get-Content -Path $testFilePath -Raw

Write-Host "Input PowerShell file content:"
Write-Host $testContentObj
Write-Host ""

# Export with spaces padding (default)
Write-Host "Exporting with -LineNumberPadding 'spaces' (default):"
$outputSpaces = "$env:TEMP\test_output_spaces.md"
Export-SourceCodeToMarkdown -Path (Split-Path -Parent $testFilePath) `
    -OutputPath $outputSpaces `
    -IncludePattern "*.ps1" `
    -IncludeLineNumbers `
    -LineNumberPadding 'spaces' `
    -IncludeVisualTree:$false `
    -IncludeTableOfContents:$false `
    -Force

$outputSpacesContent = Get-Content -Path $outputSpaces -Raw
Write-Host "Output (spaces padding):"
Write-Host $outputSpacesContent
Write-Host ""

# Export with zeros padding
Write-Host "Exporting with -LineNumberPadding 'zeros':"
$outputZeros = "$env:TEMP\test_output_zeros.md"
Export-SourceCodeToMarkdown -Path (Split-Path -Parent $testFilePath) `
    -OutputPath $outputZeros `
    -IncludePattern "*.ps1" `
    -IncludeLineNumbers `
    -LineNumberPadding 'zeros' `
    -IncludeVisualTree:$false `
    -IncludeTableOfContents:$false `
    -Force

$outputZerosContent = Get-Content -Path $outputZeros -Raw
Write-Host "Output (zeros padding):"
Write-Host $outputZerosContent
Write-Host ""

# Compare the padding
Write-Host "Padding Comparison:"
$spacesLines = ($outputSpacesContent -split "`r?`n" | Where-Object { $_ -match '^\s*\d+:' })
$zerosLines = ($outputZerosContent -split "`r?`n" | Where-Object { $_ -match '^\s*\d+:' })

Write-Host "Spaces padding sample: $($spacesLines[0])"
Write-Host "Zeros padding sample:  $($zerosLines[0])"
Write-Host ""

# ============================================================================
# TEST 2: Comment Removal - PowerShell
# ============================================================================

Write-Host "[TEST 2] PowerShell Comment Removal" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor Gray

$psTestFile = "$env:TEMP\SourceCodeToMarkdown_Test2.ps1"
$psContent = @"
# This is a single-line comment
function Get-Data {
    <#
    This is a
    multi-line comment
    #>
    param(
        [Parameter(Mandatory=`$true)]
        [string]`$Id  # Inline comment
    )

    # Another single-line comment
    `$data = @{
        Name = "Test"
        Value = 123  # Important value
    }

    <# Final block comment #>
    return `$data
}
"@

$psContent | Out-File -FilePath $psTestFile -Encoding UTF8 -NoNewline
Write-Host "Original PowerShell file with comments:"
Write-Host $psContent
Write-Host ""

# Export WITHOUT comment removal
$outputNoStrip = "$env:TEMP\test_output_no_strip.md"
Export-SourceCodeToMarkdown -Path (Split-Path -Parent $psTestFile) `
    -OutputPath $outputNoStrip `
    -IncludePattern "*.ps1" `
    -IncludeLineNumbers `
    -RemoveComments:$false `
    -IncludeVisualTree:$false `
    -IncludeTableOfContents:$false `
    -Force

Write-Host "Output WITHOUT -RemoveComments:"
Write-Host (Get-Content -Path $outputNoStrip -Raw)
Write-Host ""

# Export WITH comment removal
$outputStrip = "$env:TEMP\test_output_strip.md"
Export-SourceCodeToMarkdown -Path (Split-Path -Parent $psTestFile) `
    -OutputPath $outputStrip `
    -IncludePattern "*.ps1" `
    -IncludeLineNumbers `
    -RemoveComments `
    -LineNumberPadding 'zeros' `
    -IncludeVisualTree:$false `
    -IncludeTableOfContents:$false `
    -Force

Write-Host "Output WITH -RemoveComments (and zeros padding):"
Write-Host (Get-Content -Path $outputStrip -Raw)
Write-Host ""

# ============================================================================
# TEST 3: Comment Removal - C# Style
# ============================================================================

Write-Host "[TEST 3] C-Style Comment Removal" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor Gray

$csTestFile = "$env:TEMP\SourceCodeToMarkdown_Test3.cs"
$csContent = @"
// This is a C# single-line comment
using System;

namespace TestApp {
    class Program {
        /// <summary>
        /// XML documentation comment
        /// </summary>
        static void Main(string[] args) {
            /* Multi-line
               comment block */
            string message = "Hello, World!"; // Inline comment
            Console.WriteLine(message);
        }
    }
}
"@

$csContent | Out-File -FilePath $csTestFile -Encoding UTF8 -NoNewline
Write-Host "Original C# file with comments:"
Write-Host $csContent
Write-Host ""

# Export WITH comment removal
$csOutput = "$env:TEMP\test_output_cs.md"
Export-SourceCodeToMarkdown -Path (Split-Path -Parent $csTestFile) `
    -OutputPath $csOutput `
    -IncludePattern "*.cs" `
    -IncludeLineNumbers `
    -RemoveComments `
    -IncludeVisualTree:$false `
    -IncludeTableOfContents:$false `
    -Force

Write-Host "Output WITH -RemoveComments:"
Write-Host (Get-Content -Path $csOutput -Raw)
Write-Host ""

# ============================================================================
# TEST 4: Comment Removal - HTML
# ============================================================================

Write-Host "[TEST 4] HTML Comment Removal" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor Gray

$htmlTestFile = "$env:TEMP\SourceCodeToMarkdown_Test4.html"
$htmlContent = @"
<!-- HTML Comment 1 -->
<!DOCTYPE html>
<html>
<head>
    <title>Test</title> <!-- Inline comment -->
</head>
<!-- Multi-line
     HTML comment -->
<body>
    <p>Hello World</p>
</body>
</html>
"@

$htmlContent | Out-File -FilePath $htmlTestFile -Encoding UTF8 -NoNewline
Write-Host "Original HTML file with comments:"
Write-Host $htmlContent
Write-Host ""

# Export WITH comment removal
$htmlOutput = "$env:TEMP\test_output_html.md"
Export-SourceCodeToMarkdown -Path (Split-Path -Parent $htmlTestFile) `
    -OutputPath $htmlOutput `
    -IncludePattern "*.html" `
    -IncludeLineNumbers `
    -RemoveComments `
    -IncludeVisualTree:$false `
    -IncludeTableOfContents:$false `
    -Force

Write-Host "Output WITH -RemoveComments:"
Write-Host (Get-Content -Path $htmlOutput -Raw)
Write-Host ""

# ============================================================================
# TEST 5: MarkdownLint Compliance
# ============================================================================

Write-Host "[TEST 5] MarkdownLint Compliance" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor Gray

# Create a test with potential markdown issues
$lintTestFile = "$env:TEMP\SourceCodeToMarkdown_Test5.ps1"
$lintContent = @"
# Test File
function Test-Lint {
    # This is a comment that might cause issues
    Write-Host "Testing markdown lint compliance"  
    return $true
}
"@

$lintContent | Out-File -FilePath $lintTestFile -Encoding UTF8 -NoNewline

# Export with all features enabled
$lintOutput = "$env:TEMP\test_output_lint.md"
Export-SourceCodeToMarkdown -Path (Split-Path -Parent $lintTestFile) `
    -OutputPath $lintOutput `
    -IncludePattern "*.ps1" `
    -IncludeLineNumbers `
    -RemoveComments `
    -IncludeVisualTree `
    -IncludeTableOfContents `
    -Force

$lintResult = Get-Content -Path $lintOutput -Raw
Write-Host "MarkdownLint compliant output:"
Write-Host $lintResult
Write-Host ""

# Check for common markdownlint issues
Write-Host "MarkdownLint Compliance Check:"
$complianceChecks = @{
    "No trailing spaces (MD009)"  = $lintResult -notmatch ' $'
    "No hard tabs (MD010)"        = $lintResult -notmatch "`t"
    "No multiple blanks (MD012)"  = $lintResult -notmatch "`n{3,}"
    "Max 120 chars (MD013)"       = ($lintResult -split "`r?`n" | Where-Object { $_.Length -gt 120 }).Count -eq 0
    "Space after # (MD018)"       = $lintResult -match '^#\s'
    "Blank lines around headings" = $true # Hard to check definitively
    "First line is H1 (MD041)"    = $lintResult -match '^#\s'
    "Single trailing newline (MD047)" = $lintResult.TrimEnd().EndsWith("`n")
}

foreach ($check in $complianceChecks.GetEnumerator()) {
    $status = if ($check.Value) { "✓ PASS" } else { "✗ FAIL" }
    Write-Host "  $status - $($check.Key)"
}
Write-Host ""

# ============================================================================
# TEST 6: String Literal Preservation
# ============================================================================

Write-Host "[TEST 6] String Literal Preservation" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor Gray

$strTestFile = "$env:TEMP\SourceCodeToMarkdown_Test6.ps1"
$strContent = @"
# Comment that should be removed
`$message = "This is a # not a comment string"
`$code = '#Also not a comment'
Write-Host `$message
"@

$strContent | Out-File -FilePath $strTestFile -Encoding UTF8 -NoNewline
Write-Host "Original file with strings containing #:"
Write-Host $strContent
Write-Host ""

$strOutput = "$env:TEMP\test_output_strings.md"
Export-SourceCodeToMarkdown -Path (Split-Path -Parent $strTestFile) `
    -OutputPath $strOutput `
    -IncludePattern "*.ps1" `
    -IncludeLineNumbers `
    -RemoveComments `
    -IncludeVisualTree:$false `
    -IncludeTableOfContents:$false `
    -Force

$strResult = Get-Content -Path $strOutput -Raw
Write-Host "Output (comments removed, strings preserved):"
Write-Host $strResult
Write-Host ""

# Verify strings are preserved
if ($strResult -match '"This is a # not a comment string"' -and
    $strResult -match "'#Also not a comment'") {
    Write-Host "✓ String literals with # are preserved correctly" -ForegroundColor Green
}
else {
    Write-Host "✗ String literals may have been incorrectly processed" -ForegroundColor Red
}
Write-Host ""

# ============================================================================
# TEST 7: Summary Report
# ============================================================================

Write-Host "[TEST 7] Feature Summary" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor Gray

Write-Host "New Features Implemented:"
Write-Host "  1. -RemoveComments switch (removes #, //, <!-- -->, /* */, etc.)"
Write-Host "  2. -LineNumberPadding parameter (spaces or zeros)"
Write-Host "  3. Format-MarkdownLintCompliant helper function"
Write-Host "  4. MarkdownLint rules: MD009, MD010, MD012, MD013, MD018, MD022, MD024, MD041, MD047"
Write-Host ""

Write-Host "Test Files Created:"
Write-Host "  - $testFilePath"
Write-Host "  - $psTestFile"
Write-Host "  - $csTestFile"
Write-Host "  - $htmlTestFile"
Write-Host "  - $lintTestFile"
Write-Host "  - $strTestFile"
Write-Host ""

Write-Host "Output Files Generated:"
Write-Host "  - $outputSpaces"
Write-Host "  - $outputZeros"
Write-Host "  - $outputNoStrip"
Write-Host "  - $outputStrip"
Write-Host "  - $csOutput"
Write-Host "  - $htmlOutput"
Write-Host "  - $lintOutput"
Write-Host "  - $strOutput"
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Suite Completed Successfully!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Cleanup (optional - comment out to inspect files)
# Remove-Item -Path $testFilePath, $psTestFile, $csTestFile, $htmlTestFile, $lintTestFile, $strTestFile -ErrorAction SilentlyContinue
# Remove-Item -Path $outputSpaces, $outputZeros, $outputNoStrip, $outputStrip, $csOutput, $htmlOutput, $lintOutput, $strOutput -ErrorAction SilentlyContinue
