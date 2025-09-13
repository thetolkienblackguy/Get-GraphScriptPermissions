# Get-GraphScriptPermissions

A PowerShell script analyzer that identifies Microsoft Graph SDK cmdlets and their required permissions in your scripts. Stop the guesswork and trial-and-error when sharing Graph-powered PowerShell scripts with your team.

## 🎯 Problem This Solves

You've written a PowerShell script using the Microsoft Graph SDK. It works perfectly during testing, but when you share it with teammates, it breaks because they don't have the right Graph API permissions. Sound familiar?

While `Find-MgGraphCommand` is great for checking individual cmdlets, analyzing entire scripts line-by-line is tedious and time-consuming. **Get-GraphScriptPermissions** scales this process by automatically parsing your entire script and providing a consolidated permissions report.

## 🚀 Features

- **Automated Discovery**: Scans PowerShell scripts and identifies all Microsoft Graph SDK cmdlets
- **Smart Filtering**: Excludes authentication-only cmdlets that don't require Graph API permissions
- **Least-Privileged Focus**: Highlights the minimum permissions needed for each cmdlet
- **Comprehensive Reporting**: Shows all valid permissions, not just the least-privileged ones
- **Scope Validation**: Indicates whether your current Graph session has the required permissions
- **Export Capability**: Save results as CSV for documentation or sharing
- **Line Number Tracking**: Know exactly where each cmdlet appears in your script

## 📦 Installation

### From PowerShell Gallery (Recommended)
```powershell
Install-Script -Name Get-GraphScriptPermissions
```

### From GitHub
```powershell
# Clone the repository
git clone https://github.com/thetolkienblackguy/Get-GraphScriptPermissions.git

# Or download the script directly
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/thetolkienblackguy/Get-GraphScriptPermissions/main/Get-GraphScriptPermissions.ps1" -OutFile "Get-GraphScriptPermissions.ps1"
```

## 📋 Prerequisites

- **PowerShell 5.1** or later
- **Microsoft.Graph** PowerShell SDK
- **Graph Authentication**: Must be connected to Microsoft Graph (`Connect-MgGraph`) for scope validation

## 🔧 Usage

### Basic Analysis
```powershell
.\Get-GraphScriptPermissions.ps1 -ScriptPath .\MyScript.ps1
```

### Export Results to CSV
```powershell
.\Get-GraphScriptPermissions.ps1 -ScriptPath .\MyScript.ps1 -OutputPath .\permissions-report.csv
```

## 📊 Sample Output

Given this input script:
```powershell
Get-MgUserManager -UserId test.user@contoso.com
Update-MgUser -UserId test.user@contoso.com -AccountEnabled:$false
Revoke-MgUserSignInSession -UserId test.user@contoso.com
```

The analyzer returns:

```
Cmdlet                             : Get-MgUserManager
LineNumbers                        : 1
LeastPrivilegedEffectivePermission : User.Read.All
Description                        : Read all users' full profiles
Permissions                        : User.Read.All, User.ReadWrite.All
HasScope                           : True

Cmdlet                             : Update-MgUser
LineNumbers                        : 2
LeastPrivilegedEffectivePermission : User.ReadWrite.All
Description                        : Read and write all users' full profiles
Permissions                        : User.ReadWrite.All, DeviceManagementServiceConfig.ReadWrite.All, [...]
HasScope                           : True

Cmdlet                             : Revoke-MgUserSignInSession
LineNumbers                        : 3
LeastPrivilegedEffectivePermission : User.ReadWrite.All
Description                        : Read and write all users' full profiles
Permissions                        : User.ReadWrite.All
HasScope                           : True
```

## 🔍 Output Fields Explained

| Field | Description |
|-------|-------------|
| **Cmdlet** | The Microsoft Graph SDK cmdlet found in your script |
| **LineNumbers** | Comma-separated list of line numbers where the cmdlet appears |
| **LeastPrivilegedEffectivePermission** | The minimum permission scope required |
| **Description** | What the least-privileged permission allows |
| **Permissions** | All valid permission scopes for this cmdlet |
| **HasScope** | Whether your current Graph session has any required permissions |

## ⚙️ Parameters

### `-ScriptPath` (Required)
- **Type**: String
- **Description**: Path to the PowerShell script to analyze
- **Validation**: Must be a valid file path

### `-OutputPath` (Optional)
- **Type**: String  
- **Description**: Path to export results as CSV
- **Default**: Results display in console only

## 🧠 How It Works

1. **Script Parsing**: Reads your PowerShell script line by line
2. **Cmdlet Detection**: Uses regex pattern matching with approved PowerShell verbs to find Graph SDK cmdlets (`*-Mg*`)
3. **Permission Lookup**: Leverages `Find-MgGraphCommand` to get permission information for each unique cmdlet
4. **Smart Filtering**: Excludes authentication-only cmdlets and "me-only" permissions
5. **Result Aggregation**: Groups identical cmdlets and merges their line numbers
6. **Scope Validation**: Compares required permissions against your current Graph session scopes

## 📝 Advanced Examples

### Permission Gap Analysis
```powershell
# Connect with limited scopes
Connect-MgGraph -Scopes "User.Read.All"

# Analyze script to see what's missing
$results = .\Get-GraphScriptPermissions.ps1 -ScriptPath .\MyScript.ps1
$missingPermissions = $results | Where-Object { $_.HasScope -eq $false }
$missingPermissions | Select-Object Cmdlet, LeastPrivilegedEffectivePermission
```

## ⚠️ Important Notes

- **Authentication Required**: You must be authenticated with Microsoft Graph (`Connect-MgGraph`) for the `HasScope` field to be accurate
- **Comment Handling**: Single-line comments are ignored; block comments are not currently supported
- **Performance**: Large scripts with many unique cmdlets may take longer to analyze due to individual `Find-MgGraphCommand` lookups

## 🐛 Troubleshooting

### "This session is not authenticated with Microsoft Graph"
```powershell
# Connect to Microsoft Graph first
Connect-MgGraph
```

## 🤝 Contributing

Contributions are welcome! Areas for improvement:

- **Block Comment Support**: Currently only handles single-line comments
- **Performance Optimization**: Batch permission lookups
- **Enhanced Filtering**: More sophisticated permission categorization
- **Integration**: PowerShell module packaging

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👨‍💻 Author

**Gabriel Delaney**
- GitHub: [@thetolkienblackguy](https://github.com/thetolkienblackguy)
- Version: 1.0.0
- Date: September 13, 2025

## 🔗 Related Resources

- [Microsoft Graph PowerShell SDK Documentation](https://docs.microsoft.com/powershell/microsoftgraph/)
- [Microsoft Graph Permissions Reference](https://docs.microsoft.com/graph/permissions-reference)
- [Find-MgGraphCommand Documentation](https://docs.microsoft.com/powershell/module/microsoft.graph.authentication/find-mggraphcommand)

---

**Made with ❤️ to simplify Microsoft Graph PowerShell development**