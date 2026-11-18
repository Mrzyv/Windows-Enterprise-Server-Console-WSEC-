# Windows Enterprise Server Console (WESC)

![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D6?style=for-the-badge&logo=windows)
![Engine](https://img.shields.io/badge/Engine-PowerShell%207.6.6%2B-5391FE?style=for-the-badge&logo=powershell)
![Architecture](https://img.shields.io/badge/Grid-154--Column%20Symmetric-10B981?style=for-the-badge)

**Windows Enterprise Server Console (WESC)** is a real-time, 154-column symmetric Ring-0 & WMI/CIM telemetry, hardware diagnostics, and application management console engineered natively for **PowerShell 7.6.6+**.

## Key Capabilities
* **3-Column Symmetric Telemetry Grid (3s Live Refresh):** OS, SMBIOS & CPU Subsystem, Graphics/WDDM, Storage IOPS, Network RTT, Resource Gauges, and Top CPU/RAM Consumers.
* **Live System Event Log Stream:** Instant filtering of recent Critical, Error, and Warning events.
* **3rd-Party Application Matrix:** Automatically indexes desktop/start-menu binaries, tracks live RUNNING/STOPPED states, and launches apps by ID.
* **28+ Built-in Diagnostic & Optimization Tools:** Gaming/Workstation Boost, RAM Working Set Empty, Disk SMART Health, Kernel Driver Audit, SHA256 Signer verification, UEFI/BCD Store inspector, and PCIe/USB Bus enumerator.

## Installation & In-Place Update
1. Download **WESC_Setup.exe** from the [Latest Release](https://github.com/Mrzyv/WESC/releases/latest).
2. Run **WESC_Setup.exe** as Administrator (automatically verifies/installs PowerShell 7.6.6+, creates backups in Backup/*.zip before updates, and includes a clean uninstaller).
3. Launch from any terminal by typing: `wesc`
