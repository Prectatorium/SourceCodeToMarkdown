function Get-DirectoryTree {
    <#
    .SYNOPSIS
        Generates an ASCII-style visual representation of a directory structure.
    
    .DESCRIPTION
        Creates a tree structure showing directories and files in a hierarchical ASCII format.
    
    .PARAMETER RootPath
        The root directory path to start the tree from.
    
    .PARAMETER FileList
        An array of FileInfo objects representing the files to include in the tree.
    
    .EXAMPLE
        $files = Get-ChildItem -Path "C:\Source" -Recurse -File
        Get-DirectoryTree -RootPath "C:\Source" -FileList $files
    
    .OUTPUTS
        System.String. The ASCII tree representation.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $RootPath,

        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo[]]
        $FileList
    )

    try {
        $treeLines = [System.Collections.Generic.List[string]]::new()
        $treeLines.Add($RootPath)

        # Build hierarchical structure
        $nodeDictionary = @{}
        foreach ($file in $FileList) {
            $relativePath = [System.IO.Path]::GetRelativePath($RootPath, $file.FullName)
            $pathParts = $relativePath.Split([System.IO.Path]::DirectorySeparatorChar)
            
            $currentNode = $nodeDictionary
            foreach ($part in $pathParts) {
                if (-not $currentNode.ContainsKey($part)) {
                    $currentNode[$part] = @{}
                }
                $currentNode = $currentNode[$part]
            }
        }

        # Recursive function to write tree nodes
        function Write-TreeNodes {
            param (
                [hashtable] $Nodes,
                [string] $Prefix = ''
            )

            $keys = @($Nodes.Keys | Sort-Object)
            $keyCount = $keys.Count
            
            for ($i = 0; $i -lt $keyCount; $i++) {
                $key = $keys[$i]
                $isLast = ($i -eq $keyCount - 1)
                
                if ($isLast) {
                    $connector = '└── '
                    $childPrefix = $Prefix + '    '
                }
                else {
                    $connector = '├── '
                    $childPrefix = $Prefix + '│   '
                }
                
                $treeLines.Add($Prefix + $connector + $key)
                Write-TreeNodes -Nodes $Nodes[$key] -Prefix $childPrefix
            }
        }

        Write-TreeNodes -Nodes $nodeDictionary
        return $treeLines -join [Environment]::NewLine
    }
    catch {
        Write-Warning "Failed to generate directory tree: $($_.Exception.Message)"
        return "Tree generation failed: $($_.Exception.Message)"
    }
}