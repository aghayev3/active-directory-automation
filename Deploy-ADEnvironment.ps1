<#
.SYNOPSIS
    Creates an Active Directory environment from a JSON config with security auditing.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$ConfigPath = (Join-Path $PSScriptRoot "ad-config-generated.json"),

    [Parameter()]
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

function New-AdEnvironmentFromConfig {
    param([object]$Config, [switch]$DryRun)

    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        throw "ActiveDirectory module is required."
    }
    Import-Module ActiveDirectory -ErrorAction Stop

    $ouMap = @{}
    $groupMap = @{}
    $domain = $Config.domain
    $domainDn = (Get-ADDomain -Current LocalComputer).DistinguishedName

    foreach ($ou in $Config.organizationalUnits) { $ouMap[$ou.id] = $ou.distinguishedName }

    # Create OUs
    $ouOrdered = $Config.organizationalUnits | Sort-Object { if ($_.parentId) { 1 } else { 0 } }
    foreach ($ou in $ouOrdered) {
        $dn = $ou.distinguishedName
        if ($DryRun) { Write-Host "[WhatIf] Would create OU: $dn"; continue }
        
        if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue)) {
            $parentPath = if ($ou.parentId) { $ouMap[$ou.parentId] } else { $domainDn }
            New-ADOrganizationalUnit -Name $ou.name -Path $parentPath -ProtectedFromAccidentalDeletion:$true -ErrorAction Stop
            Write-Host "Created OU: $dn"
        }
    }

    # Create groups
    foreach ($grp in $Config.groups) {
        $ouDn = $ouMap[$grp.ouId]
        $grpDn = "CN=$($grp.name),$ouDn"
        if ($DryRun) { Write-Host "[WhatIf] Would create group: $($grp.name)"; $groupMap[$grp.id] = $grpDn; continue }
        
        if (-not (Get-ADGroup -Filter "DistinguishedName -eq '$grpDn'" -ErrorAction SilentlyContinue)) {
            $adGroup = New-ADGroup -Name $grp.name -SamAccountName $grp.sAMAccountName -GroupScope $grp.scope -GroupCategory $grp.type -Path $ouDn -PassThru
            $groupMap[$grp.id] = $adGroup.DistinguishedName
            Write-Host "Created group: $($grp.name)"
        } else {
            $groupMap[$grp.id] = $grpDn
        }
    }

    # Create users
    foreach ($usr in $Config.users) {
        $ouDn = $ouMap[$usr.ouId]
        if ($DryRun) { Write-Host "[WhatIf] Would create user: $($usr.sAMAccountName)"; continue }

        $existingUser = Get-ADUser -Filter "SamAccountName -eq '$($usr.sAMAccountName)'" -ErrorAction SilentlyContinue
        if (-not $existingUser) {
            $upn = "$($usr.sAMAccountName)@$($Config.domain)"
            $secPwd = ConvertTo-SecureString $usr.password -AsPlainText -Force
            
            New-ADUser -Name $usr.displayName -GivenName $usr.givenName -Surname $usr.surname -SamAccountName $usr.sAMAccountName `
                -UserPrincipalName $upn -Path $ouDn -AccountPassword $secPwd `
                -ChangePasswordAtLogon $usr.mustChangePasswordAtLogon -PasswordNeverExpires $usr.passwordNeverExpires -Enabled $usr.enabled -PassThru | Out-Null
            Write-Host "Created user: $($usr.sAMAccountName)"
        }

        foreach ($gid in $usr.memberOfGroupIds) {
            if ($groupMap[$gid]) {
                Add-ADGroupMember -Identity $groupMap[$gid] -Members $usr.sAMAccountName -ErrorAction SilentlyContinue
            }
        }
    }

    # Create and link GPOs
    if (Get-Module -ListAvailable -Name GroupPolicy) {
        Import-Module GroupPolicy
        $gpoGuidMap = @{}
        foreach ($gpo in $Config.gpos) {
            $existing = Get-GPO -Name $gpo.name -ErrorAction SilentlyContinue
            if ($DryRun) { Write-Host "[WhatIf] Would create/link GPO: $($gpo.name)"; $gpoGuidMap[$gpo.id] = $gpo.gpoId -replace '[{}]', ''; continue }
            
            if ($existing) {
                $gpoGuidMap[$gpo.id] = $existing.Id.ToString()
            } else {
                $newGpo = New-GPO -Name $gpo.name -Comment $gpo.description -ErrorAction Stop
                $gpoGuidMap[$gpo.id] = $newGpo.Id.ToString()
                Write-Host "Created GPO: $($gpo.name)"
            }
        }
        foreach ($link in $Config.gpoLinks) {
            $ouDn = $ouMap[$link.ouId]
            $guid = $gpoGuidMap[$link.gpoId]
            if (-not $guid) { continue }
            if ($DryRun) { Write-Host "[WhatIf] Would link GPO to OU $ouDn"; continue }
            
            try {
                New-GPLink -Guid $guid -Target $ouDn -LinkEnabled Yes -Enforced $link.enforced -Order $link.linkOrder -ErrorAction Stop | Out-Null
                Write-Host "Linked GPO to $ouDn"
            } catch { Write-Warning "GPO link failed: $_" }
        }
    } else {
        Write-Warning "GroupPolicy module not available. Skipping GPOs."
    }
}

# --- Main ---
if (-not (Test-Path $ConfigPath)) { Write-Host "Config file not found: $ConfigPath"; exit 1 }

$logPath = ".\AD-Deployment-Audit-$(Get-Date -Format 'yyyyMMdd_HHmm').log"
Start-Transcript -Path $logPath -NoClobber

$json = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
$config = $json | ConvertFrom-Json

foreach ($usr in $config.users) {
    if ($null -eq $usr.memberOfGroupIds) { $usr | Add-Member -NotePropertyName memberOfGroupIds -NotePropertyValue @() -Force }
    elseif ($usr.memberOfGroupIds -isnot [Array]) { $usr.memberOfGroupIds = @($usr.memberOfGroupIds) }
}

New-AdEnvironmentFromConfig -Config $config -DryRun:(-not $Apply)

Stop-Transcript
