<#
Written by github.com/cwsanchez 
v1.0 - 01/23/2026
#>

<#
.SYNOPSIS
Checks Hyper-V Cluster Capacity to verify if a single node can handle the total VM workload.

.DESCRIPTION
This script analyzes a Hyper-V Failover Cluster to determine if the physical hosts have enough raw resources to support a "Single Node" scenario (e.g., during maintenance, patching, or failure).

It performs the following:
1. Aggregates the total RAM and vCPU demand of all VMs (distinguishing between "Live" running VMs and "Max" total potential load).
2. Queries each physical node for its total raw RAM and Core count.
3. Outputs a comparison table showing Supply vs. Demand and the vCPU contention ratio.

This is useful for MSPs to verify capacity before running Cluster Aware Updating (CAU) or performing manual drains.

.EXAMPLE
.\Check-ClusterCapacity.ps1

Running this on a cluster node will output a table comparing VM requirements to Host physical limits.

.NOTES
vCPU Ratio Guide:
  < 4:1  :: Healthy / Standard
  > 6:1  :: Overcommitted (Expect performance degradation)
#>

# ==============================================================================
# MSP CLUSTER CAPACITY CHECKER (v1.0)
# ==============================================================================

# --- CONFIGURATION ---
$ClusterName = (Get-Cluster).Name

# --- 1. GATHER VM DATA (THE DEMAND) ---
Write-Host "Analyzing VM Workloads for Cluster '$ClusterName'..." -ForegroundColor Cyan

$AllVMs = Get-ClusterNode | ForEach-Object { Get-VM -ComputerName $_.Name }
$RunningVMs = $AllVMs | Where-Object { $_.State -eq 'Running' }
$StoppedVMs = $AllVMs | Where-Object { $_.State -ne 'Running' }

# Calculate "Live" Demand (Running VMs only - Current Assigned Memory)
$LiveRamBytes = ($RunningVMs | Measure-Object -Property MemoryAssigned -Sum).Sum
$LiveRamGB    = [math]::Round($LiveRamBytes / 1GB, 2)

# Calculate "Max" Demand (Live + Stopped VMs using Startup Memory)
$MaxRamBytes = $LiveRamBytes + ($StoppedVMs | Measure-Object -Property MemoryStartup -Sum).Sum
$MaxRamGB    = [math]::Round($MaxRamBytes / 1GB, 2)

# Calculate Total vCPUs (All VMs)
$TotalvCPUs = ($RunningVMs | Measure-Object -Property ProcessorCount -Sum).Sum + `
              ($StoppedVMs | Measure-Object -Property ProcessorCount -Sum).Sum

Write-Host "------------------------------------------------"
Write-Host "CLUSTER TOTALS (To fit on 1 Node)"
Write-Host "------------------------------------------------"
Write-Host "Total vCPUs:          $TotalvCPUs"
Write-Host "Total VM RAM (Live):  $LiveRamGB GB"
Write-Host "Total VM RAM (Max):   $MaxRamGB GB"
Write-Host "------------------------------------------------`n"

# --- 2. CHECK HOST CAPACITY (THE SUPPLY) ---
$Nodes = Get-ClusterNode
$Results = @()

foreach ($Node in $Nodes) {
    try {
        $ComputerName = $Node.Name
        
        # Get Host Total RAM (Raw Physical)
        $HostSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $ComputerName -ErrorAction Stop
        $HostTotalRamGB = [math]::Round($HostSystem.TotalPhysicalMemory / 1GB, 2)

        # Get Host Physical Cores
        $HostCPU = Get-CimInstance -ClassName Win32_Processor -ComputerName $ComputerName
        $HostCores = ($HostCPU | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum

        # --- OUTPUT TABLE ---
        $Results += [PSCustomObject]@{
            'Node'                = $ComputerName
            'Host RAM (Total)'    = "$HostTotalRamGB GB"
            'Total VM RAM (Live)' = "$LiveRamGB GB"
            'Total VM RAM (Max)'  = "$MaxRamGB GB"
            'vCPU Ratio'          = "$([math]::Round($TotalvCPUs / $HostCores, 1)):1"
        }
    }
    catch {
        $Results += [PSCustomObject]@{ 'Node' = $Node.Name; 'Host RAM (Total)' = "OFFLINE/ERROR" }
    }
}

# --- 3. DISPLAY RESULTS ---
$Results | Format-Table -AutoSize