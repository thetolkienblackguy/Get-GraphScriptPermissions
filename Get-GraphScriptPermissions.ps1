<#
    .SYNOPSIS
    Analyze a PowerShell script for Microsoft Graph cmdlets and required permissions.

    .DESCRIPTION
    Parses a script, finds Microsoft Graph cmdlets, and returns the least privileged
    and full permission sets for each. Optionally exports the results.

    .PARAMETER ScriptPath
    The path to the script file to analyze.

    .PARAMETER OutputPath
    Optional path to export results as CSV.

    .EXAMPLE
    .\Get-GraphScriptPermissions.ps1 -ScriptPath .\myscript.ps1

    .EXAMPLE
    .\Get-GraphScriptPermissions.ps1 -ScriptPath .\myscript.ps1 -OutputPath .\permissions.csv

    .INPUTS
    System.String

    .OUTPUTS
    System.Object[]

    .NOTES
    Author: Gabriel Delaney
    Date: 09/13/2025
    Version: 1.0.0
    Name: Get-GraphScriptPermissions

    Version History:
    1.0.0 - Initial release - Gabriel Delaney - 09/13/2025
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true,Position=0)]
    [ValidateScript({Test-Path -Path $_})]
    [string]$ScriptPath,
    [Parameter(Mandatory=$false,Position=1)]
    [string]$OutputPath

)
#region Helper functions
# Function to find the Graph cmdlets in a script
Function Find-GraphCmdletString {
    <#
        .SYNOPSIS
        Extracts cmdlets that query the Graph API from a script.

        .DESCRIPTION
        Extracts cmdlets that query the Graph API from a script.

        .PARAMETER Content
        The content of the script to search.
    
        .EXAMPLE
        Find-GraphCmdletString -Content $script_content
    
        .EXAMPLE
        Get-Content -Path $script_path | Find-GraphCmdletString

        .INPUTS
        System.String

        .OUTPUTS
        System.Object[]


    #>
    [CmdletBinding()]
    [OutputType([system.object[]])]
    Param(
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]
        [object]$Content
    
    )
    Begin {
        # Get the cmdlets that do not query the Graph API
        $exclusions = (Get-Command -Module Microsoft.Graph.Authentication).Name

        # Get the approved verbs
        $approved_verbs = (Get-Verb).Verb

        # Create a regex pattern to match the approved verbs followed by -Mg and any alphanumeric characters
        $pattern = "($($approved_verbs -join '|'))-Mg\w+"

        # Initialize an array to store the results
        $line_number = 0
    } Process {
        foreach ($line in $content) {
            # Increment the line number
            $line_number++

            # Skip empty lines
            If (!$line) { 
                continue 
            
            }

            # Remove comments
            $line = $line -replace '\s*#.*$',''

            # Skip lines that are just comments. Currently doesn't support block comments.
            if ($line.Trim().StartsWith("#")) { 
                continue 
            
            }

            # Find all cmdlets in the line
            $cmdlet_matches = ($line | Select-String -Pattern $pattern -AllMatches).Matches.Value
            foreach ($cmdlet in $cmdlet_matches) {
                # Microsoft.Graph.Authentication do not query the Graph API so we can ignore them
                If ($cmdlet -in $exclusions) {
                    continue

                }
                $obj = [ordered] @{}
                # Add the cmdlet to the object
                $obj["Cmdlet"] = $cmdlet
                $obj["Line"] = $line.Trim()
                $obj["LineNumber"] = $line_number
                [pscustomobject]$obj
            
            }
        }
    }
}

# Function to get the permissions for a given Graph cmdlet
Function Get-GraphCmdletPermissions {
    <#
        .SYNOPSIS
        Wrapper for Find-MgGraphCommand that extracts permissions.

        .DESCRIPTION
        For a given Graph cmdlet, returns the least privileged permission,
        all valid permissions, and the cmdlet name.

        .PARAMETER Cmdlet
        The Graph cmdlet to query.

        .EXAMPLE
        Get-GraphCmdletPermissions -Cmdlet Get-MgUser

        .INPUTS
        System.String

        .OUTPUTS
        System.Object
    
    #>
    [CmdletBinding()]
    [OutputType([System.Object])]
    Param(
        [Parameter(Mandatory=$true,Position=0)]
        [string]$Cmdlet,
        [Parameter(Mandatory=$false,Position=1)]
        [string]$ApiVersion = "v1.0"
    
    )
    Begin {
        # Create the parameters for Find-MgGraphCommand
        $find_cmd_params = @{}
        $find_cmd_params["Command"] = $cmdlet
        $find_cmd_params["ApiVersion"] = $apiVersion

        # Initialize the has_scope variable
        $has_scope = $false

        # Get the Graph context
        $context = Get-MgContext
        
        # If the context is not authenticated with Microsoft Graph, throw a warning
        If (!$context) {
            Write-Warning "This session is not authenticated with Microsoft Graph. In order to determine scopes, you must be authenticated with Microsoft Graph."
        
        } Else {
            $current_scopes = $context.Scopes
        
        }
    } Process {
        Try {
            # Get the permissions for the cmdlet
            $permissions = (Find-MgGraphCommand @find_cmd_params ).Permissions | Where-Object { 
                $_.FullDescription -like "Allows the app*" -and $_.FullDescription -notmatch "\byour\b" 
            
            }     
        } Catch {
            Write-Error "$($_.Exception.Message)" -ErrorAction Stop
        
        }

        # Check if the current scopes have any of the permissions
        Foreach ($scope in $current_scopes) {
            If ($scope -in $permissions.Name) {
                $has_scope = $true
                Break
            
            }
        }

        # Create the object
        $obj = [ordered] @{}
        $obj["Cmdlet"] = $cmdlet
        $obj["LeastPrivilegedEffectivePermission"] = $permissions[0].Name
        $obj["Description"] = $permissions[0].Description
        $obj["Permissions"] = ($permissions.Name | Select-Object -Unique) -join ", "
        $obj["HasScope"] = $has_scope

    } End {
        # Return the object
        [pscustomobject]$obj
    
    }
}

#endregion

#region Main
# Initialize the results list
$results = [System.Collections.Generic.List[System.Object]]::new()

# Get the script content
$script_content = Get-Content -Path $scriptPath

# Find the Graph cmdlets in the script
$graph_cmdlets = $script_content | Find-GraphCmdletString

# Group by cmdlet and merge line numbers
$grouped = $graph_cmdlets | Group-Object -Property Cmdlet

# Get the permissions for each Graph cmdlet
foreach ($group in $grouped) {
    $perm_info = Get-GraphCmdletPermissions -Cmdlet $group.Name

    # Create the object
    $obj = [ordered] @{}
    $obj["Cmdlet"] = $group.Name
    $obj["LineNumbers"] = ($group.Group.LineNumber -join ", ")
    $obj["LeastPrivilegedEffectivePermission"] = $perm_info.LeastPrivilegedEffectivePermission
    $obj["Description"] = $perm_info.Description
    $obj["Permissions"] = $perm_info.Permissions | Select-Object -Unique
    $obj["HasScope"] = $perm_info.HasScope

    # Add the object to the results list
    [void]$results.Add([pscustomobject]$obj)

}

#endregion

#region Output
if ($outputPath) {
    try {
        $results | Export-Csv -Path $outputPath -NoTypeInformation -Force
        Write-Output "Results exported to $outputPath"
    
    } catch {
        Write-Warning "Failed to export results to $outputPath. $($_.Exception.Message)"
    }
}

$results

#endregion