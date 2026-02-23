<#
.SYNOPSIS
    Intune Proactive Remediation - Detection script for Outlook Safe Senders list.

.DESCRIPTION
    Checks that the custom Safe Senders list file exists at the exact path required
    by the Outlook Group Policy "Specify path to Safe Senders list" and that it
    contains all required sender addresses.

    Designed to be used with Remediate-OutlookSafeSenders.ps1 as an Intune Proactive
    Remediation pair.

    Use case: Enforce "Don't download pictures automatically" while still allowing
    auto-download for specific trusted senders (helpdesk, internal domains, etc.).

    Exit codes (required by Intune):
      0 = Compliant
      1 = Non-compliant → run remediation

.NOTES
    The $folder and $required variables MUST match exactly between this script,
    the remediation script, and your Outlook GPO/Intune policy setting.

    The script is append-only and never removes entries the user has added manually.

.LINK
    https://learn.microsoft.com/en-us/mem/intune/protect/proactive-remediations

.EXAMPLE
    # Local test
    .\Detect-OutlookSafeSenders.ps1

    # In Intune: upload this file as the Detection script
#>

# Detect-OutlookSafeSenders.ps1
# Exit 0 = Compliant (no remediation)
# Exit 1 = Noncompliant (run remediation)

$ErrorActionPreference = 'SilentlyContinue'

# --- Path MUST match the Outlook "Specify path to Safe Senders list" policy ---
$folder = Join-Path $env:PUBLIC 'SafeSendersList'
$file   = Join-Path $folder 'SafeSendersList.txt'

# --- Required entries: ensure these exist (not an exact match requirement) ---
$required = @(
  'example@example.com',
  'example2@example2.com'
)

# If the file doesn't exist, Outlook ignores the policy at startup and we need remediation
if (-not (Test-Path -Path $file)) {
  Write-Output "Noncompliant: Safe Senders file missing at $file"
  exit 1
}

# Load and normalize existing entries: trim, lowercase, ignore blanks, unique
$existing = Get-Content -Path $file -Encoding UTF8 |
  ForEach-Object { $_.Trim().ToLowerInvariant() } |
  Where-Object { $_ } |
  Select-Object -Unique

# Normalize required entries and check for missing
$requiredNorm = $required |
  ForEach-Object { $_.Trim().ToLowerInvariant() } |
  Where-Object { $_ } |
  Select-Object -Unique

$missing = $requiredNorm | Where-Object { $_ -notin $existing }

if ($missing.Count -gt 0) {
  Write-Output ("Noncompliant: Missing entries: " + ($missing -join ', '))
  exit 1
}

Write-Output "Compliant: All required Safe Senders entries present."
exit 0