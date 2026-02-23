# Outlook Safe Senders List Enforcement (Intune Proactive Remediation)

**Maintains a central Safe Senders list for Outlook so trusted senders always bypass "Don't download pictures automatically".**

## 🎯 Problem This Solves

You have enabled the Outlook security setting:

> **Do not automatically download pictures from external senders**  

> (recommended security baseline)

…but you still need certain senders (helpdesk, internal distribution lists, key vendors, monitoring systems, etc.) to **auto-download images** every time.

Outlook only honors the image-download bypass when the sender is in the **user’s personal Safe Senders list**.  

Manually maintaining that list across hundreds/thousands of endpoints is impossible.

This detection + remediation pair solves it by:

- Using the official Outlook policy **"Specify path to Safe Senders list"**

- Automatically creating/updating a shared text file on every endpoint

- Ensuring your required addresses are **always present** (append-only — never deletes user-added entries)

## 📁 Files

| File                              | Purpose                              |

|-----------------------------------|--------------------------------------|

| `Detect-OutlookSafeSenders.ps1`   | Intune Detection script (exit 0/1)   |

| `Remediate-OutlookSafeSenders.ps1`| Intune Remediation script            |

| `README.md` (this file)           | Full documentation                   |

## ✅ Requirements

- Windows 10/11 with Outlook 2016 / Microsoft 365 Apps

- Intune Proactive Remediation (or ConfigMgr)

- The following **Outlook policy** must be configured (GPO or Intune Administrative Template):

  **User Configuration > Policies > Administrative Templates > Microsoft Outlook 2016 > Security > Automatic Picture Download**

  - **Specify path to Safe Senders list** = `%PUBLIC%\SafeSendersList\SafeSendersList.txt`  

    (Exact path — must match the scripts)

## 🚀 Intune Deployment (Step-by-Step)

1. Go to **Intune > Reports > Endpoint analytics > Proactive remediations**

2. **Create script package**

3. **Name**: `Outlook - Enforce Safe Senders List`

4. **Description**: `Ensures trusted senders are always in the Safe Senders list (bypasses external image block)`

5. **Detection script**: Upload `Detect-OutlookSafeSenders.ps1`

6. **Remediation script**: Upload `Remediate-OutlookSafeSenders.ps1`

7. **Run as**: `System`

8. **Enforce signature check**: No

9. **64-bit**: Yes

10. Assign to your device groups (recommended: daily or every 3 days)

**Tip**: Run the remediation once manually on a test machine to verify the file is created.

## 🔧 Customization

Edit **both scripts** (they must stay in sync):

```powershell

# --- Required entries to enforce ---

$required = @(

    'helpdesk@yourcompany.com',

    'alerts@yourcompany.com',

    'vendor@trustedpartner.com',

    'noreply@monitoring.com'

)

```

- You can add as many entries as you want.

- Use full email addresses or domains (Outlook treats `*@yourcompany.com` as wildcard in Safe Senders).

- Changes are applied on next remediation run.

## 📋 How It Works

**Detection script**

- Checks if the file exists

- Reads all entries (case-insensitive)

- Reports **Non-compliant** if any required entry is missing → triggers remediation

**Remediation script**

- Creates the folder and file if missing

- Preserves every entry the user has added manually

- Appends only missing required entries

- Writes UTF-8 without BOM (Outlook compatible)

- Logs to `%ProgramData%\OutlookSafeSenders\Remediation.log`

## 🧪 Local Testing

```powershell

# Test detection

.\Detect-OutlookSafeSenders.ps1

# Run remediation (must be elevated)

.\Remediate-OutlookSafeSenders.ps1

```

## 🔍 Troubleshooting

- Check the log: `%ProgramData%\OutlookSafeSenders\Remediation.log`

- Verify the policy path is **exactly** `%PUBLIC%\SafeSendersList\SafeSendersList.txt`

- Make sure the Intune policy "Specify path to Safe Senders list" is deployed to the same devices

- After remediation, restart Outlook or run `outlook.exe /cleanviews` once

## 📝 Notes

- The file is stored in the **Public** profile so it applies to all users on the device.

- User-added entries are never removed (safe for personal whitelists).

- Works alongside any existing user Safe Senders.

- No additional modules or internet required.

---

**Part of [sysadmin-scripts](https://github.com/cwsanchez/sysadmin-scripts)**  

MIT License • Provided as-is

```