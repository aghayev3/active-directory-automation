# Line-by-Line Explanation: Generate-ADConfig.ps1

This script acts as the "Architect." It creates a blueprint file in JSON format. It does not touch your actual Windows server; it just writes down the plan.

| Line # | PowerShell Code | Plain English Explanation |
|:---|:---|:---|
| 1 | `$ErrorActionPreference = "Stop"` | Tells the script: "If anything goes wrong, stop immediately." This prevents the script from making a mess if it hits an error. |
| 3-4 | `$domain = ...` | Sets variables for your network name (e.g., academy.local) so you don't have to type it over and over. |
| 7-12 | `function Get-RandomPassword { ... }` | Creates a "password machine." Every time the script needs a password for a new user, this machine picks random letters/numbers so every person has a unique, secure password. |
| 15-36 | `$departments = @( ... )` | A simple list of the 20 departments we want to create (HR, IT, Finance, etc.). |
| 39-44 | `$organizationalUnits = @( ... )` | This section prepares the "Folders" (OUs). It tells the computer that all the department folders should live inside one big folder called "Departments." |
| 47-51 | `foreach ($dept in $departments) { ... }` | A loop that takes our list of 20 departments and turns them into official folder instructions for the blueprint. |
| 54-58 | `$groups = @() ... foreach ...` | For every department, this creates a "Security Group." Think of this as a bucket. We put users in the "HR-Staff" bucket so we can give them all access to the HR folder at once. |
| 60-66 | `$groups += @( ... )` | Creates special "buckets" for specific tasks, like people who can use the VPN or the Helpdesk Admins. |
| 69-70 | `$firstNames / $lastNames = ...` | A list of common names the script uses to "fake" a real company's employee list. |
| 72-81 | `for ($i = 0; $i -lt $departments.Count; $i++) { ... }` | The main "User Factory." It starts a loop to go through every department and start creating people. |
| 85-86 | `$fn = ... $ln = ...` | Picks a name from our list of names based on the current number the loop is on. |
| 87 | `$sam = ...` | Creates the "Username" (e.g., jsmith0001). This is what the user types to log in. |
| 89-100 | `$users += @{ ... }` | This writes down all the details for a single person: Their name, their username, their random password, and the fact that they MUST change that password the first time they log in. |
| 103-115 | `if ($dept.Name -eq "IT" ...)` | **Security Logic:** If the script is making an IT worker, it makes a second "Admin" account for them (starting with `a-`). This shows you understand that IT people shouldn't use their admin powers for reading emails. |
| 121-127 | `$gpos = @( ... )` | Defines the "Company Rules" (Group Policy). It creates rules like "IT needs long passwords" and "Record everything that happens in Finance." |
| 130-138 | `$gpoLinks = @() ... foreach ...` | This "staples" the rules to the folders. It tells the computer: "Apply the Baseline rules to every single folder we created." |
| 143-151 | `$config = [ordered]@{ ... }` | Collects all the folders, users, groups, and rules into one big final "Master Plan." |
| 153 | `$config | ConvertTo-Json ...` | Takes that Master Plan and saves it as a text file named `ad-config-generated.json`. |
