<#
.SYNOPSIS
    Synchronizes an Active Directory user attribute with group membership.

.DESCRIPTION
    This script functions as a state-enforcement tool for Active Directory attributes based on group membership. 
    It performs two primary actions:
    1. Enforce Presence: Checks all members of the target group. If they do not have the specified attribute value, it is added.
    2. Enforce Absence: Checks all users in the domain who currently have the specified attribute. If they are no longer members of the target group, the attribute is cleared.
    
    This is commonly used for:
    - Azure AD Connect filtering (setting extensionAttributes to hide users from cloud sync).
    - Application scoping where access relies on specific user attributes rather than groups.
    - Dynamic address lists based on attributes.

    Configuration:
    Variables for GroupName, AttributeName, AttributeValue, and LogPath are defined in the 
    "CONFIGURATION" section of the script header.

.NOTES
    File Name  : Set-AttributeByGroup.ps1
    Requires   : ActiveDirectory PowerShell Module
    Privileges : Requires Account Operator or higher permissions (Write Property access on user objects).
    Log File   : Generates a transcript of changes at the defined $LogPath.

.EXAMPLE
    .\Set-AttributeByGroup.ps1
    
    Runs the synchronization based on the hardcoded configuration variables in the script. 
    Review the log file for details on which users were updated.
#>

# --- CONFIGURATION ---
$GroupName = "GroupName"
$AttributeName = "extensionAttribute13" 
$AttributeValue = "AttributeName"
$LogPath = "C:\Logs\Group-Attribute-Log.log"

$LogDir = Split-Path $LogPath -Parent
if (!(Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force
}

# --- LOGGING FUNCTION ---
function Write-Log {
    Param ([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogPath -Value "$TimeStamp - $Message"
}

try {
    Import-Module ActiveDirectory

    # 1. Get all current members of the No Sync group (Recursive handles nested groups)
    $GroupMembers = Get-ADGroupMember -Identity $GroupName -Recursive | Where-Object { $_.objectClass -eq "user" }
    
    # 2. Get all users who currently have the attribute set (to check for removals)
    # We use -Properties to ensure we can read the attribute later
    $UsersWithAttribute = Get-ADUser -Filter "$AttributeName -eq '$AttributeValue'" -Properties $AttributeName

    # --- ACTION 1: ADD ATTRIBUTE TO NEW MEMBERS ---
    foreach ($Member in $GroupMembers) {
        # Fetch the specific user object to check their current attribute value
        $ADUser = Get-ADUser -Identity $Member.distinguishedName -Properties $AttributeName
        
        # Only write if the value is different (saves replication traffic)
        if ($ADUser.$AttributeName -ne $AttributeValue) {
            Set-ADUser -Identity $Member.distinguishedName -Replace @{$AttributeName=$AttributeValue}
            Write-Log "ADDED: $AttributeValue tag ($AttributeName) to user $($Member.Name)"
        }
    }

    # --- ACTION 2: REMOVE ATTRIBUTE FROM FORMER MEMBERS ---
    # If a user has the tag, but is NOT in the $GroupMembers list, clear the tag.
    # We create a lookup list of DNs for faster comparison
    $GroupMemberDNs = $GroupMembers | Select-Object -ExpandProperty distinguishedName

    foreach ($TaggedUser in $UsersWithAttribute) {
        if ($GroupMemberDNs -notcontains $TaggedUser.distinguishedName) {
            Set-ADUser -Identity $TaggedUser.distinguishedName -Clear $AttributeName
            Write-Log "REMOVED: $AttributeValue tag ($AttributeName) from user $($TaggedUser.Name)"
        }
    }

} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
}