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