$ErrorActionPreference = "Stop"

$domain = "academy.local"
$domainDc = "DC=academy,DC=local"

# Helper Function: Generate Complex Passwords
function Get-RandomPassword {
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*'
    $pwd = ''
    1..12 | ForEach-Object { $pwd += $chars[(Get-Random -Maximum $chars.Length)] }
    return $pwd + "Aa1!" # Guarantee complexity requirements are met
}

# 20 departments (OUs + groups)
$departments = @(
    @{ Id = "ou_hr";        Name = "HR"         }
    @{ Id = "ou_it";        Name = "IT"         }
    @{ Id = "ou_fin";       Name = "Finance"    }
    @{ Id = "ou_sales";     Name = "Sales"      }
    @{ Id = "ou_marketing"; Name = "Marketing"  }
    @{ Id = "ou_legal";     Name = "Legal"      }
    @{ Id = "ou_ops";       Name = "Operations" }
    @{ Id = "ou_support";   Name = "Support"    }
    @{ Id = "ou_research";  Name = "Research"   }
    @{ Id = "ou_dev";       Name = "Development"}
    @{ Id = "ou_man";       Name = "Manufacturing" }
    @{ Id = "ou_logistics"; Name = "Logistics"  }
    @{ Id = "ou_training";  Name = "Training"   }
    @{ Id = "ou_facilities";Name = "Facilities" }
    @{ Id = "ou_exec";      Name = "Executive"  }
    @{ Id = "ou_procurement"; Name = "Procurement" }
    @{ Id = "ou_compliance";  Name = "Compliance"  }
    @{ Id = "ou_quality";     Name = "Quality"     }
    @{ Id = "ou_data";        Name = "Data"        }
    @{ Id = "ou_custsuccess"; Name = "CustSuccess" }
)

# Build OU objects
$organizationalUnits = @(
    @{ id = "ou_departments_root"; name = "Departments"; distinguishedName = "OU=Departments,$domainDc"; parentId = $null }
)
foreach ($dept in $departments) {
    $organizationalUnits += @{ id = $dept.Id; name = $dept.Name; distinguishedName = "OU=$($dept.Name),OU=Departments,$domainDc"; parentId = "ou_departments_root" }
}

# Generate Groups
$groups = @()
foreach ($dept in $departments) {
    $grpName = "$($dept.Name)-Staff"
    $groups += @{ id = "grp_$($dept.Id)_staff"; name = $grpName; sAMAccountName = $grpName; scope = "Global"; type = "Security"; ouId = $dept.Id }
}
$groups += @(
    @{ id = "grp_all_staff"; name = "All-Staff"; sAMAccountName = "All-Staff"; scope = "Global"; type = "Security"; ouId = "ou_departments_root" },
    @{ id = "grp_vpn_users"; name = "VPN-Users"; sAMAccountName = "VPN-Users"; scope = "Global"; type = "Security"; ouId = "ou_departments_root" },
    @{ id = "grp_rdp_users"; name = "RDP-Users"; sAMAccountName = "RDP-Users"; scope = "Global"; type = "Security"; ouId = "ou_departments_root" },
    @{ id = "grp_helpdesk_admins"; name = "Helpdesk-Admins"; sAMAccountName = "Helpdesk-Admins"; scope = "Global"; type = "Security"; ouId = "ou_departments_root" },
    @{ id = "grp_finance_approvers"; name = "Finance-Approvers"; sAMAccountName = "Finance-Approvers"; scope = "Global"; type = "Security"; ouId = "ou_departments_root" }
)

# Name pools
$firstNames = @("James","Mary","Robert","Patricia","John","Jennifer","Michael","Linda","William","Elizabeth")
$lastNames = @("Smith","Johnson","Williams","Brown","Jones","Garcia","Miller","Davis","Rodriguez","Martinez")

$totalUsers = 100
$usersPerDeptBase = [int]($totalUsers / $departments.Count)
$remainderUsers = $totalUsers % $departments.Count

$users = @()
$userIndex = 1

for ($i = 0; $i -lt $departments.Count; $i++) {
    $dept = $departments[$i]
    $countForDept = $usersPerDeptBase + ($(if ($i -lt $remainderUsers) { 1 } else { 0 }))
    $grpId = "grp_$($dept.Id)_staff"

    for ($j = 1; $j -le $countForDept; $j++) {
        $fn = $firstNames[($userIndex - 1) % $firstNames.Count]
        $ln = $lastNames[([math]::Floor(($userIndex - 1) / $firstNames.Count)) % $lastNames.Count]
        $sam = ("{0}{1:D4}" -f ($fn.Substring(0,1) + $ln).ToLower(), $userIndex)
        
        $users += @{
            id = "usr_{0:D4}" -f $userIndex
            givenName = $fn
            surname = $ln
            displayName = "$fn $ln"
            sAMAccountName = $sam
            ouId = $dept.Id
            password = Get-RandomPassword
            mustChangePasswordAtLogon = $true
            passwordNeverExpires = $false
            enabled = $true
            memberOfGroupIds = @($grpId)
        }

        # IT Admin Tiering Enhancement
        if ($dept.Name -eq "IT" -and $j -le 5) {
            $users += @{
                id = "usr_admin_{0:D4}" -f $userIndex
                givenName = "Admin-$fn"
                surname = $ln
                displayName = "Admin $fn $ln"
                sAMAccountName = "a-$sam"
                ouId = $dept.Id
                password = Get-RandomPassword
                mustChangePasswordAtLogon = $true
                passwordNeverExpires = $false
                enabled = $true
                memberOfGroupIds = @($grpId, "grp_helpdesk_admins")
            }
        }
        $userIndex++
    }
}

# 5 GPOs (Security Focused)
$gpos = @(
    @{ id = "gpo_baseline"; name = "Baseline Workstation Policy"; description = "Standard baseline (LLMNR disabled, LAPS enabled)"; gpoId = "{aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee}" },
    @{ id = "gpo_hr"; name = "HR Data Protection"; description = "Stricter data protection for HR USB drives"; gpoId = "{bbbbbbbb-cccc-dddd-eeee-ffffffffffff}" },
    @{ id = "gpo_it_strong_password"; name = "IT Strong Password Policy"; description = "IT password policy requiring length > 14 characters"; gpoId = "{11111111-2222-3333-4444-555555555555}" },
    @{ id = "gpo_finance_audit"; name = "Finance Audit Policy"; description = "Advanced Audit and logging for Finance"; gpoId = "{66666666-7777-8888-9999-000000000000}" },
    @{ id = "gpo_domain_security"; name = "Domain Security Settings"; description = "Domain-wide security baseline (SMB Signing required)"; gpoId = "{12345678-1234-1234-1234-1234567890ab}" }
)

# Link GPOs
$gpoLinks = @()
foreach ($dept in $departments) {
    $gpoLinks += @{ ouId = $dept.Id; gpoId = "gpo_baseline"; enforced = $false; linkOrder = 1 }
}
$gpoLinks += @{ ouId = "ou_hr"; gpoId = "gpo_hr"; enforced = $true; linkOrder = 2 }
$gpoLinks += @{ ouId = "ou_it"; gpoId = "gpo_it_strong_password"; enforced = $true; linkOrder = 2 }
$gpoLinks += @{ ouId = "ou_fin"; gpoId = "gpo_finance_audit"; enforced = $true; linkOrder = 2 }

$organizationalUnits += @{ id = "ou_domain_root"; name = "DomainRoot"; distinguishedName = $domainDc; parentId = $null }
$gpoLinks += @{ ouId = "ou_domain_root"; gpoId = "gpo_domain_security"; enforced = $true; linkOrder = 1 }

$config = [ordered]@{
    domain = $domain
    organizationalUnits = $organizationalUnits
    groups = $groups
    users = $users
    gpos = $gpos
    gpoLinks = $gpoLinks
}

$config | ConvertTo-Json -Depth 6 | Set-Content -Path ".\ad-config-generated.json" -Encoding UTF8
Write-Host "Config generated at .\ad-config-generated.json"
