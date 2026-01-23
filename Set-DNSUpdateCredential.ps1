<#
.SYNOPSIS
Sets the Microsoft DHCP Server's DNS Credential by creating a dedicated service account and assigning necessary permissions.

.DESCRIPTION
This script automates the configuration of the DHCP Server's DNS Credential to allow the DHCP server to update DNS records on a client's behalf.

It performs the following actions:
1. Creates a new Active Directory user named "DNSUpdate" (if it does not exist).
2. Adds the user to the "DNSUpdateProxy" AD group.
3. Sets this user as the credential for the DHCP server to access the DNS server for dynamic updates.

This must be run on a server with the Active Directory module installed. If the DHCP server is on a different host than the execution machine, it can be targeted via the -DHCPServer parameter.

.EXAMPLE
.\Set-DNSUpdateCredential.ps1 -CleartextPassword "MySecretPassword123!"
Sets the credentials using a specific cleartext password.

.EXAMPLE
.\Set-DNSUpdateCredential.ps1 -GeneratePassword -OutputCleartextPassword
Generates a complex random password, sets the credential, and outputs the password to the console.

.EXAMPLE
.\Set-DNSUpdateCredential.ps1 -GeneratePassword -DHCPServer "192.168.1.10"
Generates a password and applies the credentials to a remote DHCP server specified by IP or Hostname.

.EXAMPLE
.\Set-DNSUpdateCredential.ps1 -GeneratePassword -Silent
Runs the configuration without returning any success or failure objects to the pipeline.

.NOTES
Requirements: Active Directory PowerShell Module.
User Created: "DNSUpdate"
Target Group: "DNSUpdateProxy"
#>

[cmdletbinding(DefaultParameterSetName = "GeneratePassword")]
param(
	[Parameter(Mandatory = $true, ParameterSetName = 'ProvideSecurePassword')]
	[SecureString]$SecurePassword = $null,

	[Parameter(Mandatory = $true, ParameterSetName = 'ProvideCleartextPassword')]
	[string]$CleartextPassword = $null,

	[Parameter(Mandatory = $true, ParameterSetName = 'GeneratePassword')]
	[switch]$GeneratePassword,
	
	[switch]$Silent,
	[switch]$OutputCleartextPassword,
	[switch]$OutputSecurePassword,
	[string]$DHCPServer
)

# Generates password if specified. Otherwise uses password provided.
if ($GeneratePassword) {
	Add-Type -AssemblyName 'System.Web'
	$length = Get-Random -Minimum 25 -Maximum 28
	$nonAlphaChars = Get-Random -Minimum 8 -Maximum 12
	$password = [System.Web.Security.Membership]::GeneratePassword($length, $nonAlphaChars)
	$secret = ConvertTo-SecureString -String $password -AsPlainText -Force
}
elseif ($SecurePassword.IsPresent) {
	$secret = $SecurePassword
}
elseif ($CleartextPassword.IsPresent) {
	$secret = ConvertTo-SecureString -String $CleartextPassword -AsPlainText -Force
}

# Create user w/ permissions and set credential.
if ( -not($DHCPServer.IsPresent) ) {
	$DHCPServerAddress = "127.0.0.1"
}
else {
	$DHCPServerAddress = $DHCPServer
}

$userParams = @{
	"Name" = "DNSUpdate";
	"DisplayName" = "DNSUpdate";
	"AccountPassword" = $secret;
	"PasswordNeverExpires" = $true;
	"Enabled" = $true;
	"Description" = "Service account for DHCP server to update DNS records on client's behalf." 
}

try { 
	New-ADUser @userParams
}
catch { 
	if ($silent) {
		exit
	}
	else {
		Write-Host -Object "Error occurred, Active Directory module may not be installed. Otherwise, DNSUpdate user could already exist."
		exit
	}
}

Add-ADGroupMember -Identity "DNSUpdateProxy" -Members "DNSUpdate"

$credential = New-Object System.Management.Automation.PSCredential ("DNSUpdate", $secret)
Set-DhcpServerDnsCredential -Credential $credential -ComputerName $DHCPServerAddress

# Outputs credentials if specified.
if ($silent) {
	exit
}
else {
	$returnObj = "" | Select-Object SamAccountName, ClearText, SecurePass
	$userProperties = @{SamAccountName = "DNSUpdate"; CleartextPassword = "$password"; SecurePassword = "$secret" }

	$returnObj.SamAccountName = $userProperties.SamAccountName	

	if ($OutputCleartextPassword) {
		$returnObj.ClearText = $userProperties.CleartextPassword
	}

	if ($OutputSecurePassword) {
		$returnObj.SecurePass = $userProperties.SecurePassword
	} 
	else {
		$returnObj.SecurePass = $null
	}

	return $returnObj
}