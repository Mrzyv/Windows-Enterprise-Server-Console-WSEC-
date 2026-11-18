# Windows Enterprise Server Console (WESC)

![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D6?style=for-the-badge&logo=windows)
![Engine](https://img.shields.io/badge/Engine-PowerShell%207.6.6%2B-5391FE?style=for-the-badge&logo=powershell)
![Architecture](https://img.shields.io/badge/Grid-154--Column%20Symmetric-10B981?style=for-the-badge)

**Windows Enterprise Server Console (WESC)** is a real-time, 154-column symmetric Ring-0 & WMI/CIM telemetry, hardware diagnostics, and application management console engineered natively for **PowerShell 7.6.6+**.

---

## Live Console Visuals (Windows Terminal & Legacy Conhost)

### 1. Modern Windows Terminal (`wt.exe`) — Acrylic / GPU-Accelerated Rendering
![WESC Windows Terminal View](assets/preview_terminal.jpg)

### 2. Classic Windows Console Host (`conhost.exe`) — Direct Win32 VT100 Rendering
![WESC Conhost View](assets/preview_conhost.jpg)

---

## Complete Telemetry & Interface Breakdown

WESC renders a **154-column symmetric, zero-wrap diagnostic matrix** refreshing every **3 seconds** via native Win32 Virtual Terminal (VT) ANSI escape sequences. Everything visible on the screen is structured into four operational tiers:

### 1. Top 3-Column Hardware, Firmware & Kernel Matrix

#### **Left Column: Core System, SMBIOS, CPU & Memory**
* **`[ OS & KERNEL ENVIRONMENT ]`** — Displays Windows SKU (`Windows 11 Pro N for Workstations`), exact OS Build (`26300`), `SecureBoot: ON` state, `ADMINISTRATOR (Elevated)` privilege status, active host/user session, and `VBS / HVCI` virtualization security audit.
* **`[ PLATFORM & SMBIOS FIRMWARE ]`** — Reads DMI/SMBIOS motherboard model, chassis serial number, exact BIOS firmware version/date, continuous system uptime, and boot timestamp.
* **`[ PROCESSOR & CACHE SUBSYSTEM ]`** — Identifies CPU model, physical/logical core topology (`10C / 16T`), socket type, `VT-x` status, real-time effective clock (`MHz Eff`) vs. base frequency, `L1 / L2 / L3` hardware cache sizes, and SMBIOS UUID.
* **`[ MEMORY & KERNEL POOL ALLOCATION ]`** — Tracks physical RAM (`Used / Free`), virtual commit charge, hard page-fault rate (`PgFlt/s`), populated DIMM slots and MT/s speed, Kernel `Paged` and `Non-Paged` pool allocations, Pagefile usage, and active Windows service counts.

#### **Center Column: Graphics, Storage, Network & Ring-0 Operations**
* **`[ GRAPHICS & WDDM SUBSYSTEM ]`** — Monitors discrete GPU hardware, VRAM allocation, core temperature (`°C`), board power draw (`W`), PCIe performance state (`P0–P8`), live Core/Memory clocks, active display resolution/refresh rate (`144Hz`), and WDDM/DirectX driver version.
* **`[ STORAGE & I/O SUBSYSTEM ]`** — Summarizes total physical drives and capacity, system `Volume C:` utilization bar, secondary partitions (`D:`, `E:`), live Read/Write throughput (`KB/s`), real-time `IOPS`, and disk queue depth.
* **`[ NETWORK INTERFACE & ROUTING ]`** — Displays active NIC adapter, hardware MAC address, local `IPv4`, default gateway, DNS server, live `RX / TX` bandwidth, link speed (`Mbps`), and real-time gateway ping latency (`RTT ms`).
* **`[ RING-0 KERNEL & TCP STATE ]`** — Tracks OS context switches (`CtxSw/s`), system calls (`SysCall/s`), hardware interrupts (`HW Int/s`), active `Established`, `Listening`, and `TimeWait/CloseWait` TCP sockets, plus total indexed 3rd-party binaries.

#### **Right Column: Live Gauges, Top Consumers & Security**
* **`[ RESOURCE UTILIZATION & HANDLES ]`** — Dynamic color-coded load bars for **CPU**, **RAM**, and **Volume C**, alongside total active kernel/user threads and open OS object handles.
* **`[ TOP CPU CONSUMERS (CUMULATIVE TIME) ]`** — Ranks the top 5 processes by cumulative CPU execution time with exact PIDs.
* **`[ TOP MEMORY CONSUMERS (PROCESS / PID / WS) ]`** — Ranks the top 5 processes by physical Working Set (`WS`) RAM footprint.
* **`[ POWER, SECURITY & KERNEL STATE ]`** — Shows AC/Battery power status, `SecureBoot` and process integrity level (`High`), Microsoft Defender signature version and real-time protection status, installed QFE security hotfixes, and NT Kernel (`ntoskrnl.exe` PID 4).

---

### 2. Middle Section: Live System Event Log Stream
* **`[ SYSTEM EVENT LOG STREAM: CRITICAL / ERROR / WARNING ]`** — Streams the latest Critical, Error, and Warning events directly from the Windows `System` event log with exact timestamps, severity badges, Event IDs, provider names, and descriptions.

---

### 3. Lower Section: Discovered 3rd-Party Applications Matrix
* **`[ DISCOVERED 3RD-PARTY APPLICATIONS ]`** — Automatically scans Start Menu and Desktop shortcuts to index installed 3rd-party software, checks live process tables every 3 seconds to display real-time **`RUNNING`** (green) or **`STOPPED`** (gray) status badges, and launches any app instantly by its `[ID#]`.

---

### 4. Bottom Command Deck (28+ Interactive Tools & Diagnostics)
Pressing any key pauses the 3-second telemetry loop and opens the interactive command prompt:
* **App & Console Control:** `[ID#]` Launch App | `[P]` Next Page | `[R]` Rescan Apps | `[S]` Deep Search | `[T]` Task Manager | `[Y]` Resource Monitor | `[EV]` Event Viewer | `[Q]` Exit
* **Hardware & Firmware Audits:** `[G]` GPU & Power Mode | `[A]` Battery & Thermals | `[D]` Volume Inventory | `[H]` Disk SMART Health | `[B]` System Benchmark | `[BC]` UEFI & BCD Store | `[PE]` PCIe & USB Buses
* **Kernel, Security & Network:** `[L]` 24h Event Audit | `[O]` Process DLL Audit | `[J]` Scheduled Tasks | `[FW]` Firewall Rules | `[WU]` QFE Hotfix Audit | `[I]` DNS & Ping Matrix | `[V]` Security & Ports | `[W]` Service Auditor | `[FI]` SHA256 Signer | `[N]` Active TCP Sockets | `[HO]` ARP & Hosts | `[X]` Kernel Drivers | `[SH]` SMB Shares | `[US]` User & Token Priv
* **Performance & Maintenance:** `[Z]` Gaming/WS Boost | `[M]` Optimize RAM | `[U]` Startup Auditor | `[K]` Terminate PID | `[E]` Export Audit Log (ZIP) | `[F]` Flush DNS | `[C]` Purge Temp Cache

---

## Installation & In-Place Update
1. Download **`WESC_Setup.exe`** from the [**Latest Release**](https://github.com/Mrzyv/Windows-Enterprise-Server-Console-WESC-/releases/latest).
2. Run **`WESC_Setup.exe`** as Administrator (automatically verifies/installs **PowerShell 7.6.6+**, archives existing versions to `Backup/*.zip` before in-place updates, and includes 1-click rollback + clean uninstaller).
3. Launch from any terminal (`pwsh`, Windows Terminal, or `conhost`) by typing: `wesc`

