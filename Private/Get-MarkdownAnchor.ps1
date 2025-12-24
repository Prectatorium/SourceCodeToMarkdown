function Get-MarkdownAnchor {
    <#
    .SYNOPSIS
        Converts text to a Markdown-compatible anchor link.
    
    .DESCRIPTION
        Transforms text by removing special characters and converting spaces to hyphens
        to create valid Markdown anchor links.
    
    .PARAMETER Text
        The text to convert to a Markdown anchor.
    
    .EXAMPLE
        Get-MarkdownAnchor -Text "My File Name.cs"
        Returns: #my-file-name-cs
    
    .EXAMPLE
        Get-MarkdownAnchor -Text "Special_File@Name.txt"
        Returns: #specialfilename-txt
    
    .OUTPUTS
        System.String. The Markdown anchor with leading '#'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Text
    )

    # Convert to lowercase, remove special characters, replace spaces with hyphens
    $anchor = $Text.ToLower() -replace '[^\w\s-]', '' -replace '\s+', '-'
    
    # Remove leading/trailing hyphens
    $anchor = $anchor.Trim('-')
    
    # Return with leading hash for Markdown
    return "#$anchor"
}