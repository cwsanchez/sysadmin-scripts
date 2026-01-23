<#
.SYNOPSIS
Modifies the TCP/IP NetBIOS options (Enable, Disable, or DHCP) for all valid network adapters.

.DESCRIPTION
This script utilizes WMI (Win32_NetworkAdapterConfiguration) to retrieve all network adapters where the 'TcpipNetbiosOptions' property is not null. 

It iterates through the discovered adapters and modifies the NetBIOS over TCP/IP setting based on the selected switch parameter:
- Enable: Forces NetBIOS On (1)
- Disable: Forces NetBIOS Off (2)
- DHCPDefault: Sets the adapter to use the setting defined by the DHCP server (0)

By default, the script outputs a table detailing the Index, Description, and new status of the changed adapters. Use the -Silent switch to suppress this output.

.PARAMETER Enable
Sets the NetBIOS option to '1' (Enabled) for all adapters.

.PARAMETER Disable
Sets the NetBIOS option to '2' (Disabled) for all adapters.

.PARAMETER DHCPDefault
Sets the NetBIOS option to '0' (Use DHCP setting) for all adapters.

.PARAMETER Silent
Suppresses the console output that details the changes made.

.EXAMPLE
.\Set-TcpipNetbiosOption.ps1 -Enable
Enables NetBIOS over TCP/IP on all available network adapters.

.EXAMPLE
.\Set-TcpipNetbiosOption.ps1 -Disable
Disables NetBIOS over TCP/IP on all available network adapters.

.EXAMPLE
.\Set-TcpipNetbiosOption.ps1 -DHCPDefault -Silent
Reverts all adapters to use the DHCP provided NetBIOS setting and suppresses the output confirmation.

.NOTES
WMI Method: SetTcpIpNetbios
Value Map:
  0 :: Use NetBIOS setting from the DHCP server
  1 :: Enable NetBIOS over TCP/IP
  2 :: Disable NetBIOS over TCP/IP
#>

param (
	[Parameter(Mandatory = $true, ParameterSetName = 'EnableNetbios')]
	[switch]$Enable,
	[Parameter(Mandatory = $true, ParameterSetName = 'DisableNetbios')]
	[switch]$Disable,
	[Parameter(Mandatory = $true, ParameterSetName = 'SetDHCPDefault')]
	[switch]$DHCPDefault,

	[switch]$Silent
)

$netAdapters = Get-WmiObject -ClassName Win32_NetworkAdapterConfiguration | 
	Where-Object -Property 'TcpipNetbiosOptions' -ne $null

if ($netAdapters -eq $null) {
	Write-Host "Could not find valid network adapter!"
	exit
}

$changedAdapters = @()

if ($Enable) {
	$netbiosOption = "1"
}
elseif ($Disable) {
	$netbiosOption = "2"
}
elseif ($DHCPDefault) {
	$netbiosOption = "0"
}	

foreach ($adapter in $netAdapters) {
	$adapter.SetTcpIpNetbios("$netbiosOption") | Out-Null
	$index = $adapter.Index
	$newAdapterSettings = Get-WmiObject -ClassName Win32_NetworkAdapterConfiguration | Where-Object -Property 'Index' -eq "$index"
	$changedAdapters += $newAdapterSettings
}

if ($Silent) {
	exit
}
else {
	foreach ($adapter in $changedAdapters) {
		$adapter | Select-Object -Property Index, Description, TcpIpNetbiosOptions, DHCPEnabled, IPAddress
	}
}