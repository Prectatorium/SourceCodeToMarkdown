Describe "SourceCodeToMarkdown Installation Verification" {

    Context "Module Manifest and Import" {
        It "Should find the module in the PSModulePath" {
            Get-Module -ListAvailable -Name SourceCodeToMarkdown | Should Not BeNullOrEmpty
        }

        It "Should import successfully without errors" {
            { Import-Module SourceCodeToMarkdown -Force } | Should Not Throw
        }

        It "Should have the correct version (2.0.0)" {
            (Get-Module SourceCodeToMarkdown).Version.ToString() | Should Be "2.0.0"
        }
    }

    Context "Command Availability" {
        It "Should export the main function 'Export-SourceCodeToMarkdown'" {
            Get-Command Export-SourceCodeToMarkdown -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "Should support the 'Code2Md' alias" {
            Get-Alias Code2Md -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }
    }

    Context "Directory Structure Integrity" {
        $modulePath = (Get-Module SourceCodeToMarkdown).ModuleBase

        It "Should contain the 'Public' directory" {
            $path = Join-Path $modulePath "Public\Export-SourceCodeToMarkdown.ps1"
            (Test-Path $path) | Should Be $true
        }

        It "Should contain the 'Private' helper scripts" {
            # Checking a representative file from the Private folder
            $path = Join-Path $modulePath "Private\Get-DirectoryTree.ps1"
            (Test-Path $path) | Should Be $true
        }
    }
}