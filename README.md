# System Administration Scripts

A centralized collection of useful scripts and tools for system administration, automation, and operational tasks.

While this repository is designed as a catch-all for various administrative tools, the current focus is primarily on **PowerShell scripts for Windows environments** including Active Directory, Hyper-V, and Network configuration.

## 📂 Repository Contents

Below are the primary utilities currently maintained in this repository.

| Script | Category | Description |
| :--- | :--- | :--- |
| **[Check-ClusterCapacity.ps1](./Check-ClusterCapacity.ps1)** | Hyper-V | Analyzes a Failover Cluster to verify if a single node can handle the total VM workload (N+1 capacity check). |
| **[Set-DNSUpdateCredential.ps1](./Set-DNSUpdateCredential.ps1)** | DHCP/AD | Automates the creation of a secure service account ("DNSUpdate") for DHCP servers to perform dynamic DNS updates. |
| **[Set-TcpipNetbiosOption.ps1](./Set-TcpipNetbiosOption.ps1)** | Network | Bulk modifies NetBIOS over TCP/IP settings (Enable, Disable, or DHCP Default) for network adapters using WMI. |

## 🚀 Getting Started

### Prerequisites
* **PowerShell 5.1** or later (PowerShell Core 7+ recommended for newer scripts).
* **RSAT Tools**: Many scripts (like `Set-DNSUpdateCredential.ps1`) require the Active Directory or DHCP PowerShell modules.
* **Administrative Privileges**: Most scripts interact with system configurations and require an elevated session.

### Installation
Clone the repository to your management workstation or script server:

```powershell
git clone https://github.com/cwsanchez/sysadmin-scripts.git
```

### Usage
Scripts are self-documented. You can view the help and examples for any script using `Get-Help`:

```powershell
# View detailed help and examples
Get-Help .\Check-ClusterCapacity.ps1 -Full
```
## 🤝 Contributing

Contributions are welcome! If you have a script to add or a fix for an existing one, please check out the [CONTRIBUTING.md](./CONTRIBUTING.md) guide for commit message standards and pull request details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

---
**Disclaimer:** These scripts are provided "as is". Always review and test scripts in a non-production environment before deploying them to production systems.