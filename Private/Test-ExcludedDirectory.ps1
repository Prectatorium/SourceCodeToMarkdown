function Test-ExcludedDirectory {
    <#
    .SYNOPSIS
        Tests if a file path contains any excluded directory patterns.
    
    .DESCRIPTION
        Checks if the given file path contains any of the specified directory names
        that should be excluded from processing.
    
    .PARAMETER FilePath
        The full file path to test.
    
    .PARAMETER ExcludedDirectories
        An array of directory names to exclude.
    
    .EXAMPLE
        Test-ExcludedDirectory -FilePath "C:\Project\bin\Debug\app.exe" -ExcludedDirectories @('bin', 'obj')
        Returns: $true
    
    .EXAMPLE
        Test-ExcludedDirectory -FilePath "C:\Project\src\app.cs" -ExcludedDirectories @('bin', 'obj')
        Returns: $false
    
    .OUTPUTS
        System.Boolean. Returns $true if the path contains an excluded directory, otherwise $false.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]
        $ExcludedDirectories
    )

    foreach ($dir in $ExcludedDirectories) {
        # Match directory name with path separators on both sides or at start/end
        $pattern = "*$([System.IO.Path]::DirectorySeparatorChar)$dir$([System.IO.Path]::DirectorySeparatorChar)*"
        if ($FilePath -like $pattern) {
            return $true
        }
    }
    return $false
}