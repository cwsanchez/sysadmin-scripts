<#
.SYNOPSIS
    Intune Proactive Remediation - Remediation script for Outlook Safe Senders list.

.DESCRIPTION
    Creates or updates the Safe Senders list file so it always contains the required
    entries (append-only — never removes user-added entries).

    Designed to be used with Detect-OutlookSafeSenders.ps1 as an Intune Proactive
    Remediation pair.

    Use case: Same as detection script — maintain whitelist for trusted senders while
    blocking external images for everyone else.

.NOTES
    The $folder and $required variables MUST match exactly between this script,
    the detection script, and your Outlook GPO/Intune policy setting.

    Writes UTF-8 without BOM (matches Outlook expectations).

.LINK
    https://learn.microsoft.com/en-us/mem/intune/protect/proactive-remediations

.EXAMPLE
    # Local test (elevated)
    .\Remediate-OutlookSafeSenders.ps1

    # In Intune: upload this file as the Remediation script
#>

# Remediate-OutlookSafeSenders.ps1
# Creates/updates the Safe Senders list file so it always contains required entries.

$ErrorActionPreference = 'Stop'

# --- Path MUST match the Outlook "Specify path to Safe Senders list" policy ---
$folder = Join-Path $env:PUBLIC 'SafeSendersList'
$file   = Join-Path $folder 'SafeSendersList.txt'

# --- Required entries to enforce (append-only; do not remove existing user entries) ---
$required = @(
  'example@example.com',
  'example2@example2.com'
)

# Optional: local log file for quick endpoint troubleshooting
$logDir  = Join-Path $env:ProgramData 'OutlookSafeSenders'
$logFile = Join-Path $logDir 'Remediation.log'

function Write-Log {
  param([string]$Message)
  if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
  }
  $ts = (Get-Date).ToString('s')
  Add-Content -Path $logFile -Value "$ts $Message"
}

try {
  # Ensure folder exists
  if (-not (Test-Path -Path $folder)) {
    New-Item -Path $folder -ItemType Directory -Force | Out-Null
    Write-Log "Created folder: $folder"
  }

  # Read existing entries (if file exists)
  $existing = @()
  if (Test-Path -Path $file) {
    $existing = Get-Content -Path $file -Encoding UTF8 |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ }
  }

  # Normalize existing for comparison
  $existingNorm = $existing |
    ForEach-Object { $_.ToLowerInvariant() } |
    Select-Object -Unique

  # Determine which required entries are missing
  $toAdd = foreach ($r in $required) {
    $rt = $r.Trim()
    if ($rt -and ($rt.ToLowerInvariant() -notin $existingNorm)) {
      $rt
    }
  }

  if ($toAdd.Count -gt 0) {
    Write-Log ("Adding missing entries: " + ($toAdd -join ', '))
  } else {
    Write-Log "No missing entries. File already contains required senders."
  }

  # Final content: preserve existing + add missing; remove blanks; unique
  $final = @($existing + $toAdd) |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ } |
    Select-Object -Unique

  # Write with UTF-8 (no BOM) to reduce formatting surprises across editors
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllLines($file, $final, $utf8NoBom)

  Write-Log "Wrote file: $file (Total entries: $($final.Count))"
  exit 0
}
catch {
  Write-Log "ERROR: $($_.Exception.Message)"
  throw
}