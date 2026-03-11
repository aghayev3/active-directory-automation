# Line-by-Line Explanation: Deploy-ADEnvironment.ps1

This script is the "Construction Worker." It reads the `ad-config-generated.json` blueprint and actually builds the folders and users on your Windows Server.

| Line # | PowerShell Code | Plain English Explanation |
|:---|:---|:---|
| 1-5 | `<# .SYNOPSIS ... #>` | This is a "Comment Block." It's just a note for humans explaining what the script does. The computer ignores this. |
| 7-13 | `param( ... )` | Sets up the "Settings" for the script. It lets you choose which blueprint file to use and adds an `-Apply` switch so you don't accidentally build things before you're ready. |
| 15 | `$ErrorActionPreference = "Stop"` | Again, tells the computer to stop if it hits a snag. Safety first. |
| 17 | `function New-AdEnvironmentFromConfig { ... }` | This defines the "Engine" of the script. Everything inside these curly brackets is the step-by-step assembly line. |
| 21-24 | `if (-not (Get-Module ...))` | Checks if the "Active Directory Tools" are installed on the computer. If they aren't, it stops and tells you to install them. |
| 35-46 | `foreach ($ou in $ouOrdered) { ... }` | **Folder Builder:** It looks at the blueprint and starts creating the folders (OUs). |
| 39 | `if (-not (Get-ADOrganizationalUnit ...))` | **Logic Check:** Before creating a folder, it checks if it's already there. If it is, it skips it. This prevents "Duplicate" errors. |
| 42 | `New-ADOrganizationalUnit ... -Protected...` | Actually creates the folder. It adds a "Lock" so no one can accidentally delete the folder later. |
| 49-60 | `foreach ($grp in $Config.groups) { ... }` | **Group Builder:** It goes through the blueprint and creates the "Access Buckets" (Security Groups) inside the folders we just made. |
| 63-79 | `foreach ($usr in $Config.users) { ... }` | **User Builder:** It starts the process of creating all 950+ people in the system. |
| 67 | `$existingUser = Get-ADUser ...` | Checks if the person already exists. If you run this script twice, it won't try to create the same person again. |
| 70 | `$secPwd = ConvertTo-SecureString ...` | Encrypts the user's password in the computer's memory so a hacker can't "see" the password while the script is running. |
| 72-75 | `New-ADUser ...` | The actual command that creates the user account in Windows. |
| 78-82 | `Add-ADGroupMember ...` | This takes the user we just created and "drops" them into their department's bucket (Group). |
| 86-113 | `if (Get-Module ... GroupPolicy) { ... }` | **Rule Applier:** This section looks for the "Rules" (GPOs) in the blueprint and sets them up on the server. |
| 118-121 | `if (-not (Test-Path $ConfigPath)) { ... }` | Checks to make sure the blueprint file actually exists on your hard drive before starting. |
| 123 | `$logPath = ...` | Creates a name for a "Receipt" file (Log) that will record everything the script does. |
| 124 | `Start-Transcript ...` | **The Recorder:** Starts recording every line of text that pops up on the screen into that Log file. This is your "Audit Trail." |
| 126-127 | `$json = ... | ConvertFrom-Json` | Opens the blueprint file and translates it from "Text" into "Data" that PowerShell can understand. |
| 134 | `New-AdEnvironmentFromConfig ...` | This is the "Go" button. It tells the assembly line to start working. |
| 136 | `Stop-Transcript` | Turns off the recorder. Your audit log is now finished and saved. |
