# [WESC_PWSH7_GUARD] Force execution inside PowerShell 7 (pwsh.exe)
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwsh7 = "C:\Program Files\PowerShell\7\pwsh.exe"
    if (-not (Test-Path $pwsh7)) {
        $cmdPwsh = Get-Command "pwsh.exe" -ErrorAction SilentlyContinue
        if ($cmdPwsh) { $pwsh7 = $cmdPwsh.Source }
    }
    if (Test-Path $pwsh7) {
        Start-Process -FilePath $pwsh7 -ArgumentList "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Wait
        exit
    } else {
        Write-Host "[CRITICAL] PowerShell 7.6.6+ (pwsh.exe) tapılmadı! Zəhmət olmasa PowerShell 7 quraşdırın." -ForegroundColor Red
        Start-Sleep -Seconds 3
        exit 1
    }
}
$__wescOriginalTitle = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "Administrator: Windows Enterprise Server Console (WESC) [PWSH " + $PSVersionTable.PSVersion.ToString() + "]"
# Enable Win32 Virtual Terminal Processing & 156-Column Console Geometry
$vtApiCode = @"
using System;
using System.Runtime.InteropServices;
public class WescConsoleVT {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
    public static void EnableVT() {
        IntPtr hOut = GetStdHandle(-11);
        uint mode;
        if (GetConsoleMode(hOut, out mode)) {
            SetConsoleMode(hOut, mode | 0x0004);
        }
    }
}
"@;
try {
    Add-Type -TypeDefinition $vtApiCode -ErrorAction SilentlyContinue;
    [WescConsoleVT]::EnableVT();
} catch {}
try {
    if ([System.Console]::BufferWidth -lt 156) { [System.Console]::BufferWidth = 156; }
    if ([System.Console]::WindowWidth -lt 156) {
        $maxW = [System.Console]::LargestWindowWidth;
        [System.Console]::WindowWidth = [math]::Min(156, $maxW);
    }
} catch {}
# ==============================================================================
# WINDOWS ENTERPRISE SYSTEM TELEMETRY & DIAGNOSTICS CONSOLE
# ARCHITECTURE: .NET CORE ATOMIC ENGINE - GRID: 154-COLUMN SYMMETRIC (48-48-48)
# ==============================================================================
$ErrorActionPreference = "SilentlyContinue";

$E  = [string][char]27;
$V  = [string][char]124;
$BS = [string][char]92;
$NL = [System.Environment]::NewLine;

$cReset   = ($E) + "[0m";
$cCyan    = ($E) + "[36m";
$cWhite   = ($E) + "[37m";
$cMagenta = ($E) + "[35m";
$cYellow  = ($E) + "[33m";
$cGreen   = ($E) + "[32m";
$cRed     = ($E) + "[31m";
$cGray    = ($E) + "[90m";
$hdrBorder = "+" + ("-" * 152) + "+";

$memApiCode = @"
using System;
using System.Runtime.InteropServices;
public class Win32Mem {
    [DllImport("psapi.dll")]
    public static extern int EmptyWorkingSet(IntPtr hwProc);
}
"@;
try { Add-Type -TypeDefinition:($memApiCode) -ErrorAction:("SilentlyContinue"); } catch {}

function FitPlain ($text, $width) {
    $s = if ($null -ne $text) { [string]($text) } else { "" };
    if (($s.Length) -gt ($width)) { return $s.Substring(0, ($width)); }
    return $s.PadRight(($width));
}

function GetVisualGauge ($percent, $width) {
    $clamped = [math]::Max(0, [math]::Min(100, [int]($percent)));
    $filled = [int][math]::Round((($clamped) / 100.0) * ($width));
    $empty = ($width) - ($filled);
    return "[" + ("#" * ($filled)) + ("-" * ($empty)) + "]";
}

function GetLoadColor ($percent) {
    if (($percent) -ge 85) { return ($cRed); }
    elseif (($percent) -ge 60) { return ($cYellow); }
    else { return ($cGreen); }
}

function FormatHeader ($title, $width) {
    $clean = "[ " + ($title.Trim()) + " ]";
    return ($cMagenta) + (FitPlain ($clean) ($width)) + ($cReset);
}

function FormatKV ($label, $val, $width, $valColor) {
    if (-not ($valColor)) { $valColor = ($cWhite); }
    $lblClean = FitPlain (($label) + ":") 12;
    $valWidth = ($width) - 12;
    $vStr = if ($null -ne $val) { [string]($val) } else { "N/A" };
    if (($vStr.Length) -gt ($valWidth)) {
        $vStr = ($vStr.Substring(0, (($valWidth) - 2))) + "..";
    }
    return ($cCyan) + ($lblClean) + ($cReset) + ($valColor) + (FitPlain ($vStr) ($valWidth)) + ($cReset);
}

function FormatProc ($rank, $name, $pidVal, $val, $width) {
    $pre = ([string]($rank)) + ". ";
    $nStr = [string]($name);
    if (($nStr.Length) -gt 16) { $nStr = ($nStr.Substring(0, 14)) + ".."; }
    $withPid = ($pre) + ($nStr) + " (" + ([string]($pidVal)) + ")";
    $prePadded = FitPlain ($withPid) 30;
    $rem = ($width) - 32;
    $vStr = FitPlain ([string]($val)) ($rem);
    return ($cWhite) + ($prePadded) + ($cGray) + ($V) + " " + ($cWhite) + ($vStr) + ($cReset);
}

function FormatCmdPair ($leftCmd, $rightCmd, $colLeft, $colRight) {
    $leftPadded  = FitPlain ($leftCmd) 24;
    $rightPadded = FitPlain ($rightCmd) 24;
    return ($colLeft) + ($leftPadded) + ($cReset) + ($colRight) + ($rightPadded) + ($cReset);
}

function ShowModuleHeader ($title) {
    try { [System.Console]::CursorVisible = $true; } catch {};
    [System.Console]::Clear();
    $centered = FitPlain (($title.PadLeft(76 + [int](($title.Length) / 2)))) 152;
    [System.Console]::WriteLine((($cCyan) + ($hdrBorder) + ($cReset)));
    [System.Console]::WriteLine((($cCyan) + ($V) + ($cWhite) + ($centered) + ($cCyan) + ($V) + ($cReset)));
    [System.Console]::WriteLine((($cCyan) + ($hdrBorder) + ($cReset)));
}

function WaitModuleReturn {
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
    $null = Read-Host -Prompt:("Press Enter to return to telemetry console");
}

# ==============================================================================
# PRECISION 3RD-PARTY APPLICATION AUTO-DISCOVERY ENGINE (STRICT FILTER)
# ==============================================================================
function DiscoverThirdPartyApps {
    $discovered = [System.Collections.Generic.List[hashtable]]::new();
    $seenPaths  = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase);
    $seenNames  = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase);

    $exNames = @(
        "uninstall","unins000","updater","update","setup","install","crash","reporter",
        "vcredist","vc_redist","dxsetup","directx","edgeupdate","onedrive","cortana",
        "diagnostics","readme","manual","license","website","feedback","error","daemon",
        "bootstrap","unitycrashhandler","cephtmlengine","notification_helper","elevation_service",
        "createdump","configsecuritypolicy","iediagcmd","ieinstal","imagingdevices","mpcmdrun",
        "msedge_proxy","msinfo32","mssense","msi_ambientsilent","msi center sdk",
        "msi nbfoundation service","easyanticheat_eos","easyanticheat","gameoverlayui",
        "googleupdate","integratedoffice","msi_warningnotice","msi\.terminalserver",
        "steamerrorreporter","steamservice","epicwebhelper","riotclientcrashhandler","vgtray",
        "nvcontainer","nvfvsdksvc_x64","nvidia frameview sdk","officeclicktorun","appactions",
        "compattelrunner","dismhost","presentmon_x64","program files","program files \(x86\)",
        "common files","windows","system32","realtek","intel","amd"
    ) -join ($V);
    $excludeNameRegex = "(?i)^(" + ($exNames) + ")$";

    $exSubs = @(
        "uninstall","unins000","crashhandler","crashreporter","updater","vcredist","vc_redist",
        "dxsetup","configsecuritypolicy","iediagcmd","ieinstal","imagingdevices","mpcmdrun",
        "msedge_proxy","msinfo32","mssense","nbfoundation","ambientsilent","center sdk",
        "diagnostic","elevation_service","helper","easyanticheat","gameoverlayui","googleupdate",
        "integratedoffice","warningnotice","terminalserver","errorreporter","webhelper",
        "nvcontainer","nvfvsdksvc","frameview","officeclicktorun","clicktorun","telemetry",
        "service","broker","agent","runner","realtek","ethernet controller","audio console",
        "bluetooth","chipset","mei","rst","dptf","nahimic","soundblaster","driver","redist","prereq"
    ) -join ($V);
    $excludeSubRegex = "(?i)(" + ($exSubs) + ")";

    $exPaths = @(
        "\\Windows\\","\\Microsoft\\Edge","\\WindowsApps\\","\\Temp\\","\\Installer\\",
        "\\Common Files\\","\\Windows Defender","\\Internet Explorer\\","\\Windows Mail\\",
        "\\Windows Media Player\\","\\Windows NT\\","\\Windows Photo Viewer\\","\\Windows Security\\",
        "\\WindowsPowerShell\\","\\ModifiableWindowsApps\\","\\Reference Assemblies\\","\\MSBuild\\",
        "\\dotnet\\","\\PackageManagement\\","\\Windows Kits\\","\\Google\\Update\\","\\EasyAntiCheat",
        "\\NVIDIA Corporation\\FrameViewSDK","\\NVIDIA Corporation\\NvContainer",
        "\\Microsoft Shared\\ClickToRun","\\Realtek\\","\\Intel\\","\\AMD\\"
    ) -join ($V);
    $excludePathRegex = "(?i)(" + ($exPaths) + ")";

    $pubExRegex = "(?i)^(" + (@("Microsoft","Microsoft Corporation","Windows","Realtek","Intel","Intel Corporation","Advanced Micro Devices") -join ($V)) + ")$";
    $dirExRegex = "(?i)^(" + (@("RECYCLE\.BIN","System Volume Information","Windows","ProgramData","Program Files","Program Files \(x86\)","Recovery","PerfLogs","Config\.Msi","MSI","NVIDIA Corporation","Microsoft","Common Files","Realtek","Intel","AMD","ModifiableWindowsApps","WindowsApps") -join ($V)) + ")$";
    $genericExeRegex = "(?i)^(" + (@("app","main","launcher","client","start","game","bin") -join ($V)) + ")$";

    $friendlyMap = @{
        "7zFM"                = "7-Zip File Manager";
        "acad"                = "Autodesk AutoCAD";
        "DefenderControl"     = "Defender Control";
        "HoYoPlay"            = "HoYoPlay Launcher";
        "gsudo"               = "Gsudo Elevation";
        "pwsh"                = "PowerShell 7 (x64)";
        "Zen"                 = "Zen Browser";
        "chrome"              = "Google Chrome / Helium";
        "GenshinImpact"       = "Genshin Impact";
        "WorldOfTanks"        = "World of Tanks";
        "steam"               = "Steam Client";
        "Rainmeter"           = "Rainmeter Desktop";
        "NVDisplay.Container" = "SKIP_INTERNAL";
    };

    $wsh = New-Object -ComObject:("WScript.Shell");
    $sDirs = @(
        ([System.IO.Path]::Combine(($env:ProgramData), "Microsoft", "Windows", "Start Menu", "Programs")),
        ([System.IO.Path]::Combine(($env:USERPROFILE), "AppData", "Roaming", "Microsoft", "Windows", "Start Menu", "Programs")),
        ([System.Environment]::GetFolderPath("Desktop")),
        ([System.Environment]::GetFolderPath("CommonDesktopDirectory"))
    );
    $lnks = @(Get-ChildItem -Path:($sDirs) -Filter:("*.lnk") -Recurse -ErrorAction:("SilentlyContinue"));

    for ($i = 0; ($i) -lt ($lnks.Count); $i++) {
        $lnk = $lnks[($i)];
        $bName = ($lnk.BaseName).Trim();
        if (($bName.Length) -lt 2) { continue; }
        if ((($bName) -match ($excludeNameRegex)) -or (($bName) -match ($excludeSubRegex))) { continue; }
        try {
            $sc = $wsh.CreateShortcut(($lnk.FullName));
            $target = [string]($sc.TargetPath);
            if (($target) -and ($target.EndsWith(".exe", [System.StringComparison]::OrdinalIgnoreCase))) {
                if (($target) -match ($excludePathRegex)) { continue; }
                if ([System.IO.File]::Exists(($target))) {
                    $procName = [System.IO.Path]::GetFileNameWithoutExtension(($target));
                    if ((($procName) -match ($excludeNameRegex)) -or (($procName) -match ($excludeSubRegex))) { continue; }
                    if ($friendlyMap.ContainsKey(($procName))) {
                        $mapped = $friendlyMap[($procName)];
                        if (($mapped) -eq "SKIP_INTERNAL") { continue; }
                        $bName = $mapped;
                    }
                    if ((-not ($seenPaths.Contains(($target)))) -and (-not ($seenNames.Contains(($bName))))) {
                        $null = $seenPaths.Add(($target));
                        $null = $seenNames.Add(($bName));
                        $discovered.Add(@{ Name = ($bName); ProcessName = ($procName); Path = ($target); });
                    }
                }
            }
        } catch {}
    }

    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    );
    $regItems = @(Get-ItemProperty -Path:($regPaths) -ErrorAction:("SilentlyContinue"));

    for ($r = 0; ($r) -lt ($regItems.Count); $r++) {
        $item = $regItems[($r)];
        $dName = [string]($item.DisplayName);
        if ([string]::IsNullOrWhiteSpace(($dName))) { continue; }
        $dName = ($dName -replace "\s+\(x64\)|\s+\(x86\)|\s+\d+(\.\d+)+.*$", "").Trim();
        if ((($dName) -match ($excludeNameRegex)) -or (($dName) -match ($excludeSubRegex))) { continue; }
        if (($item.SystemComponent) -eq 1) { continue; }
        $pub = [string]($item.Publisher);
        if (($pub) -match ($pubExRegex)) { continue; }

        $exeCandidate = "";
        $iconStr = [string]($item.DisplayIcon);
        if (-not [string]::IsNullOrWhiteSpace(($iconStr))) {
            $cleanIcon = ($iconStr.Split(",")[0]).Replace('"', '').Trim();
            if (($cleanIcon.EndsWith(".exe", [System.StringComparison]::OrdinalIgnoreCase)) -and ([System.IO.File]::Exists(($cleanIcon)))) {
                if ((($cleanIcon) -notmatch ($excludeSubRegex)) -and (($cleanIcon) -notmatch ($excludePathRegex))) { $exeCandidate = ($cleanIcon); }
            }
        }
        if ((-not ($exeCandidate)) -and ($item.InstallLocation)) {
            $instLoc = ([string]($item.InstallLocation)).Replace('"', '').Trim();
            if ([System.IO.Directory]::Exists(($instLoc))) {
                $exes = @(Get-ChildItem -Path:($instLoc) -Filter:("*.exe") -Depth:2 -ErrorAction:("SilentlyContinue"));
                for ($e = 0; ($e) -lt ($exes.Count); $e++) {
                    $f = $exes[($e)];
                    if ((($f.BaseName) -notmatch ($excludeNameRegex)) -and (($f.BaseName) -notmatch ($excludeSubRegex))) {
                        $exeCandidate = $f.FullName;
                        break;
                    }
                }
            }
        }
        if (($exeCandidate) -and (-not (($exeCandidate) -match ($excludePathRegex)))) {
            $procName = [System.IO.Path]::GetFileNameWithoutExtension(($exeCandidate));
            if ((($procName) -match ($excludeNameRegex)) -or (($procName) -match ($excludeSubRegex))) { continue; }
            if ($friendlyMap.ContainsKey(($procName))) {
                $mapped = $friendlyMap[($procName)];
                if (($mapped) -eq "SKIP_INTERNAL") { continue; }
                $dName = $mapped;
            }
            if ((-not ($seenPaths.Contains(($exeCandidate)))) -and (-not ($seenNames.Contains(($dName))))) {
                $null = $seenPaths.Add(($exeCandidate));
                $null = $seenNames.Add(($dName));
                $discovered.Add(@{ Name = ($dName); ProcessName = ($procName); Path = ($exeCandidate); });
            }
        }
    }

    $progRoots = [System.Collections.Generic.List[string]]::new();
    $progRoots.Add(($env:ProgramFiles));
    $progRoots.Add((${env:ProgramFiles(x86)}));
    $progRoots.Add(([System.IO.Path]::Combine(($env:LOCALAPPDATA), "Programs")));
    $progRoots.Add(([System.IO.Path]::Combine(($env:LOCALAPPDATA), "imput")));

    $fixedDrives = @(Get-CimInstance -ClassName:("Win32_LogicalDisk") -Filter:("DriveType=3") -ErrorAction:("SilentlyContinue"));
    for ($fd = 0; ($fd) -lt ($fixedDrives.Count); $fd++) {
        $drvRoot = ([string]($fixedDrives[($fd)].DeviceID)) + $BS;
        if (($drvRoot) -ne "C:\") {
            $progRoots.Add(($drvRoot));
            $progRoots.Add(([System.IO.Path]::Combine(($drvRoot), "Games")));
            $progRoots.Add(([System.IO.Path]::Combine(($drvRoot), "Program Files")));
            $progRoots.Add(([System.IO.Path]::Combine(($drvRoot), "Program Files (x86)")));
        }
    }

    for ($pr = 0; ($pr) -lt ($progRoots.Count); $pr++) {
        $rootDir = $progRoots[($pr)];
        if ((-not ($rootDir)) -or (-not [System.IO.Directory]::Exists(($rootDir)))) { continue; }
        $subFolders = @(Get-ChildItem -Path:($rootDir) -Directory -ErrorAction:("SilentlyContinue"));
        for ($sf = 0; ($sf) -lt ($subFolders.Count); $sf++) {
            $folder = $subFolders[($sf)];
            if (($folder.FullName) -match ($excludePathRegex)) { continue; }
            $cleanFolderName = ($folder.Name).TrimStart('$');
            if (($cleanFolderName) -match ($dirExRegex)) { continue; }

            $foundExes = @(Get-ChildItem -Path:($folder.FullName) -Filter:("*.exe") -Depth:1 -ErrorAction:("SilentlyContinue"));
            for ($fx = 0; ($fx) -lt ($foundExes.Count); $fx++) {
                $exeFile = $foundExes[($fx)];
                $baseN = $exeFile.BaseName;
                if ((($baseN) -match ($excludeNameRegex)) -or (($baseN) -match ($excludeSubRegex))) { continue; }
                if (($exeFile.FullName) -match ($excludePathRegex)) { continue; }
                if (($exeFile.Length) -lt 307200) { continue; }

                $friendly = if ($friendlyMap.ContainsKey(($baseN))) { $friendlyMap[($baseN)] } elseif (($baseN.Length) -gt 3 -and ($baseN -notmatch ($genericExeRegex))) { $baseN } else { $folder.Name };
                if ((($friendly) -eq "SKIP_INTERNAL") -or (($friendly) -match ($excludeNameRegex)) -or (($friendly) -match ($excludeSubRegex))) { continue; }

                if ((-not ($seenPaths.Contains(($exeFile.FullName)))) -and (-not ($seenNames.Contains(($friendly))))) {
                    $null = $seenPaths.Add(($exeFile.FullName));
                    $null = $seenNames.Add(($friendly));
                    $discovered.Add(@{ Name = ($friendly); ProcessName = ($baseN); Path = ($exeFile.FullName); });
                    break;
                }
            }
        }
    }

    $sorted = [System.Linq.Enumerable]::ToArray(
        [System.Linq.Enumerable]::OrderBy(($discovered), [Func[hashtable, string]]{ param($x) return [string]($x["Name"]) })
    );
    $finalList = [System.Collections.Generic.List[hashtable]]::new();
    for ($idx = 0; ($idx) -lt ($sorted.Length); $idx++) {
        $entry = $sorted[($idx)];
        $entry["ID"] = [string](($idx) + 1);
        $finalList.Add(($entry));
    }
    return ,$finalList;
}

function GetNvidiaMetrics {
    $smi = Get-Command -Name:("nvidia-smi.exe") -ErrorAction:("SilentlyContinue");
    if (-not ($smi)) {
        $defSmi = "C:/Windows/System32/nvidia-smi.exe";
        if ([System.IO.File]::Exists(($defSmi))) { $smi = @{ Source = ($defSmi) }; }
    }
    if ($smi) {
        try {
            $pInfo = [System.Diagnostics.ProcessStartInfo]::new();
            $pInfo.FileName = $smi.Source;
            $pInfo.Arguments = "--query-gpu=memory.total,memory.used,utilization.gpu,temperature.gpu,power.draw,clocks.current.graphics,clocks.current.memory,pstate --format=csv,noheader,nounits";
            $pInfo.RedirectStandardOutput = $true;
            $pInfo.UseShellExecute = $false;
            $pInfo.CreateNoWindow = $true;
            $proc = [System.Diagnostics.Process]::Start(($pInfo));
            $out = $proc.StandardOutput.ReadToEnd();
            $proc.WaitForExit(500);
            if (-not [string]::IsNullOrWhiteSpace(($out))) {
                $parts = ($out.Trim()).Split(",");
                if (($parts.Length) -ge 8) {
                    return @{
                        Valid    = $true;
                        VramTot  = [math]::Round(([double]($parts[0].Trim())) / 1024.0, 1);
                        VramUse  = [math]::Round(([double]($parts[1].Trim())) / 1024.0, 1);
                        GpuLoad  = [int]([double]($parts[2].Trim()));
                        GpuTemp  = ($parts[3].Trim()) + "C";
                        GpuPwr   = ($parts[4].Trim()) + "W";
                        GpuClock = ($parts[5].Trim()) + "MHz";
                        MemClock = ($parts[6].Trim()) + "MHz";
                        PState   = ($parts[7].Trim());
                    };
                }
            }
        } catch {}
    }
    return @{ Valid = $false };
}

function GetFastLatency ($hostAddr) {
    $p = Get-CimInstance -ClassName:("Win32_PingStatus") -Filter:("Address='" + ($hostAddr) + "' AND Timeout=350");
    if (($p) -and (($p.StatusCode) -eq 0)) { return ([string]($p.ResponseTime)) + " ms"; }
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew();
        $tcp = [System.Net.Sockets.TcpClient]::new();
        $ar = $tcp.BeginConnect(($hostAddr), 443, $null, $null);
        $ok = $ar.AsyncWaitHandle.WaitOne(400, $false);
        $sw.Stop();
        $tcp.Close();
        if ($ok) { return ([string]($sw.ElapsedMilliseconds)) + " ms"; }
    } catch {}
    return "OFFLINE";
}

# ==============================================================================
# ENTERPRISE FORENSIC, KERNEL & DIAGNOSTIC MODULES
# ==============================================================================
function InvokeAuthenticodeVerifier {
    ShowModuleHeader "CRYPTOGRAPHIC SHA-256 & X.509 AUTHENTICODE BINARY VERIFIER";
    $target = Read-Host -Prompt:("Enter Full Binary Path or Active Process PID");
    if (-not [string]::IsNullOrWhiteSpace(($target))) {
        $filePath = $target.Trim().Replace('"', '');
        $pidVal = 0;
        if ([int]::TryParse(($filePath), [ref]($pidVal))) {
            $pObj = Get-Process -Id:($pidVal) -ErrorAction:("SilentlyContinue");
            if (($pObj) -and ($pObj.MainModule.FileName)) { $filePath = $pObj.MainModule.FileName; }
        }
        if ([System.IO.File]::Exists(($filePath))) {
            $fInfo = [System.IO.FileInfo]::new(($filePath));
            $hashObj = Get-FileHash -Path:($filePath) -Algorithm:("SHA256") -ErrorAction:("SilentlyContinue");
            $sigObj  = Get-AuthenticodeSignature -FilePath:($filePath) -ErrorAction:("SilentlyContinue");
            $verInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo(($filePath));
            $sigStat = if ($sigObj) { [string]($sigObj.Status) } else { "Unknown" };
            $sigCol  = if (($sigStat) -eq "Valid") { ($cGreen) } else { ($cRed) };
            $signer  = if (($sigObj) -and ($sigObj.SignerCertificate)) { [string]($sigObj.SignerCertificate.Subject) } else { "Unsigned / No X.509 Certificate" };
            $thumb   = if (($sigObj) -and ($sigObj.SignerCertificate)) { [string]($sigObj.SignerCertificate.Thumbprint) } else { "N/A" };

            [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
            [System.Console]::WriteLine((($cWhite) + "  Target Binary Path   : " + ($cCyan) + ($filePath) + ($cReset)));
            [System.Console]::WriteLine((($cWhite) + "  File Size & Version  : " + ([string]([math]::Round(($fInfo.Length) / 1KB, 2))) + " KB  " + ($V) + "  Version: " + ([string]($verInfo.FileVersion)) + "  " + ($V) + "  Product: " + ([string]($verInfo.ProductName)) + ($cReset)));
            [System.Console]::WriteLine((($cWhite) + "  Creation / Modified  : " + ($fInfo.CreationTime.ToString("yyyy-MM-dd HH:mm:ss")) + "  " + ($V) + "  Modified: " + ($fInfo.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")) + ($cReset)));
            [System.Console]::WriteLine((($cWhite) + "  SHA-256 Digest       : " + ($cYellow) + ([string]($hashObj.Hash)) + ($cReset)));
            [System.Console]::WriteLine((($cWhite) + "  Authenticode Status  : " + ($sigCol) + ($sigStat) + ($cWhite) + " (" + ([string]($sigObj.StatusMessage)) + ")" + ($cReset)));
            [System.Console]::WriteLine((($cWhite) + "  X.509 Signer Subject : " + ($cCyan) + (FitPlain ($signer) 124) + ($cReset)));
            [System.Console]::WriteLine((($cWhite) + "  Cert Thumbprint      : " + ($cGray) + ($thumb) + ($cReset)));
        } else {
            [System.Console]::WriteLine((($cRed) + "  [!] Target binary file not found or protected." + ($cReset)));
        }
    }
    WaitModuleReturn;
}

function InvokeArpHostsAuditor {
    ShowModuleHeader "L2/L3 NEIGHBOR ARP CACHE & LOCAL DNS HOSTS AUDITOR";
    [System.Console]::WriteLine((($cYellow) + "  [ ACTIVE L2/L3 ARP NEIGHBOR TABLE (IPV4) ]" + ($cReset)));
    [System.Console]::WriteLine((($cYellow) + "  " + ("IP ADDRESS".PadRight(26)) + ("LINK-LAYER MAC".PadRight(26)) + ("STATE".PadRight(20)) + ("INTERFACE INDEX".PadRight(20)) + "ADDRESS FAMILY" + ($cReset)));
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));

    $neighbors = @(Get-NetNeighbor -AddressFamily:("IPv4") -ErrorAction:("SilentlyContinue"));
    $shown = 0;
    for ($i = 0; (($i) -lt ($neighbors.Count)) -and (($shown) -lt 14); $i++) {
        $nb = $neighbors[($i)];
        $st = [string]($nb.State);
        if ((($st) -ne "Unreachable") -and (($st) -ne "Permanent")) {
            $ip  = FitPlain ($nb.IPAddress) 26;
            $ll  = FitPlain ($nb.LinkLayerAddress) 26;
            $stP = FitPlain ($st) 20;
            $idx = FitPlain ([string]($nb.ifIndex)) 20;
            $col = if (($st) -eq "Reachable") { ($cGreen) } else { ($cCyan) };
            [System.Console]::WriteLine((($cWhite) + "  " + ($ip) + ($cCyan) + ($ll) + ($col) + ($stP) + ($cWhite) + ($idx) + "IPv4" + ($cReset)));
            $shown++;
        }
    }
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
    [System.Console]::WriteLine((($cYellow) + "  [ LOCAL ETC/HOSTS STATIC DNS OVERRIDES ]" + ($cReset)));
    $hostsPath = [System.IO.Path]::Combine(($env:SystemRoot), "System32", "drivers", "etc", "hosts");
    if ([System.IO.File]::Exists(($hostsPath))) {
        $hLines = [System.IO.File]::ReadAllLines(($hostsPath));
        $hCount = 0;
        for ($h = 0; ($h) -lt ($hLines.Length); $h++) {
            $ln = ($hLines[($h)]).Trim();
            if (($ln.Length -gt 0) -and (-not ($ln.StartsWith("#")))) {
                [System.Console]::WriteLine((($cRed) + "  [OVERRIDE] " + ($cWhite) + (FitPlain ($ln) 136) + ($cReset)));
                $hCount++;
            }
        }
        if (($hCount) -eq 0) { [System.Console]::WriteLine((($cGreen) + "  [OK] Clean hosts file. Zero static DNS overrides configured." + ($cReset))); }
    }
    WaitModuleReturn;
}

function InvokeSmbShareAuditor {
    ShowModuleHeader "SMB NETWORK SHARES, SESSIONS & OPEN FILE LOCKS AUDITOR";
    [System.Console]::WriteLine((($cYellow) + "  " + ("SHARE NAME".PadRight(28)) + ("LOCAL PATH".PadRight(54)) + ("SHARE TYPE".PadRight(22)) + "DESCRIPTION" + ($cReset)));
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));

    $shares = @(Get-CimInstance -ClassName:("Win32_Share") -ErrorAction:("SilentlyContinue"));
    for ($i = 0; ($i) -lt ($shares.Count); $i++) {
        $sh = $shares[($i)];
        $nm = FitPlain ($sh.Name) 28;
        $pt = FitPlain ($sh.Path) 54;
        $tp = FitPlain ([string]($sh.Type)) 22;
        $ds = FitPlain ($sh.Description) 44;
        [System.Console]::WriteLine((($cWhite) + "  " + ($nm) + ($cCyan) + ($pt) + ($cYellow) + ($tp) + ($cGray) + ($ds) + ($cReset)));
    }
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
    [System.Console]::WriteLine((($cYellow) + "  [ ACTIVE INBOUND SMB SESSIONS ]" + ($cReset)));
    $sessions = @(Get-SmbSession -ErrorAction:("SilentlyContinue"));
    if (($sessions.Count) -gt 0) {
        for ($s = 0; ($s) -lt ($sessions.Count); $s++) {
            $ss = $sessions[($s)];
            [System.Console]::WriteLine((($cRed) + "  [SESSION] Client: " + ([string]($ss.ClientComputerName)) + "  " + ($V) + "  User: " + ([string]($ss.ClientUserName)) + "  " + ($V) + "  Open Files: " + ([string]($ss.NumOpens)) + ($cReset)));
        }
    } else {
        [System.Console]::WriteLine((($cGreen) + "  [OK] Zero external SMB client sessions connected." + ($cReset)));
    }
    WaitModuleReturn;
}

function InvokeUserSessionAuditor {
    ShowModuleHeader "LOCAL USER ACCOUNTS & PROCESS TOKEN PRIVILEGE AUDITOR";
    [System.Console]::WriteLine((($cYellow) + "  " + ("ACCOUNT NAME".PadRight(28)) + ("ENABLED".PadRight(14)) + ("LOCKOUT".PadRight(14)) + ("PASSWORDS EXPIRES".PadRight(22)) + "SID (SECURITY IDENTIFIER)" + ($cReset)));
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));

    $users = @(Get-CimInstance -ClassName:("Win32_UserAccount") -Filter:("LocalAccount=True") -ErrorAction:("SilentlyContinue"));
    for ($u = 0; ($u) -lt ($users.Count); $u++) {
        $usr = $users[($u)];
        $en  = if (-not ($usr.Disabled)) { "True" } else { "False" };
        $enCol = if (($en) -eq "True") { ($cGreen) } else { ($cGray) };
        [System.Console]::WriteLine((($cWhite) + "  " + (FitPlain ($usr.Name) 28) + ($enCol) + (FitPlain ($en) 14) + ($cWhite) + (FitPlain ([string]($usr.Lockout)) 14) + (FitPlain ([string]($usr.PasswordExpires)) 22) + ($cCyan) + (FitPlain ($usr.SID) 68) + ($cReset)));
    }
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
    [System.Console]::WriteLine((($cYellow) + "  [ CURRENT PROCESS ACCESS TOKEN PRIVILEGES ]" + ($cReset)));
    $privOut = @(whoami /priv);
    $shown = 0;
    for ($p = 0; (($p) -lt ($privOut.Count)) -and (($shown) -lt 14); $p++) {
        $line = ($privOut[($p)]).Trim();
        if (($line.StartsWith("Se")) -and (($line.IndexOf("Privilege")) -ge 0)) {
            $col = if (($line.IndexOf("Enabled")) -ge 0) { ($cGreen) } else { ($cGray) };
            [System.Console]::WriteLine((($col) + "  " + (FitPlain ($line) 148) + ($cReset)));
            $shown++;
        }
    }
    WaitModuleReturn;
}

function InvokeFirewallAuditor {
    ShowModuleHeader "WINDOWS DEFENDER FIREWALL INBOUND ALLOW RULE AUDITOR";
    [System.Console]::WriteLine((($cYellow) + "  " + ("RULE DISPLAY NAME".PadRight(48)) + ("PROFILE".PadRight(22)) + ("DIRECTION".PadRight(16)) + ("ACTION".PadRight(14)) + "INTERNAL RULE ID" + ($cReset)));
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));

    $rules = @(Get-NetFirewallRule -Enabled:("True") -Direction:("Inbound") -Action:("Allow") -ErrorAction:("SilentlyContinue"));
    $shown = 0;
    for ($r = 0; (($r) -lt ($rules.Count)) -and (($shown) -lt 22); $r++) {
        $rl = $rules[($r)];
        $dn = FitPlain ($rl.DisplayName) 48;
        $pr = FitPlain ([string]($rl.Profile)) 22;
        $dr = FitPlain ([string]($rl.Direction)) 16;
        $ac = FitPlain ([string]($rl.Action)) 14;
        $nm = FitPlain ($rl.Name) 48;
        [System.Console]::WriteLine((($cWhite) + "  " + ($dn) + ($cCyan) + ($pr) + ($cYellow) + ($dr) + ($cGreen) + ($ac) + ($cGray) + ($nm) + ($cReset)));
        $shown++;
    }
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
    [System.Console]::WriteLine((($cGreen) + "  Total Active Inbound Allow Rules: " + ([string]($rules.Count)) + " (Showing top " + ([string]($shown)) + ")" + ($cReset)));
    WaitModuleReturn;
}

function InvokeHotfixAuditor {
    ShowModuleHeader "WINDOWS QFE HOTFIX & SECURITY PATCH INVENTORY";
    [System.Console]::WriteLine((($cYellow) + "  " + ("HOTFIX ID".PadRight(22)) + ("DESCRIPTION".PadRight(34)) + ("INSTALLED ON".PadRight(28)) + "INSTALLED BY / CONTEXT" + ($cReset)));
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));

    $qfe = @(Get-CimInstance -ClassName:("Win32_QuickFixEngineering") -ErrorAction:("SilentlyContinue"));
    for ($i = 0; (($i) -lt ($qfe.Count)) -and (($i) -lt 22); $i++) {
        $hf = $qfe[($i)];
        $id = FitPlain ($hf.HotFixID) 22;
        $ds = FitPlain ($hf.Description) 34;
        $dt = if ($hf.InstalledOn) { FitPlain ([string]($hf.InstalledOn)) 28 } else { FitPlain "OS Base Image" 28 };
        $by = FitPlain ($hf.InstalledBy) 62;
        [System.Console]::WriteLine((($cCyan) + "  " + ($id) + ($cWhite) + ($ds) + ($cGreen) + ($dt) + ($cGray) + ($by) + ($cReset)));
    }
    WaitModuleReturn;
}

function InvokeBcdBootAuditor {
    ShowModuleHeader "UEFI FIRMWARE, BCD BOOT STORE & VBS ISOLATION AUDITOR";
    $dg = Get-CimInstance -Namespace:("root/Microsoft/Windows/DeviceGuard") -ClassName:("Win32_DeviceGuard") -ErrorAction:("SilentlyContinue");
    $vbsStat = if (($dg) -and (($dg.VirtualizationBasedSecurityStatus) -eq 2)) { "RUNNING (VBS Active)" } else { "INACTIVE / DISABLED" };
    [System.Console]::WriteLine((($cYellow) + "  [ DEVICE GUARD & HYPERVISOR ENFORCED CODE INTEGRITY ]" + ($cReset)));
    [System.Console]::WriteLine((($cWhite) + "  Virtualization-Based Security : " + ($cGreen) + ($vbsStat) + ($cWhite) + "  " + ($V) + "  Secure Boot : " + ($cCyan) + ($sbEnabled) + ($cReset)));
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
    [System.Console]::WriteLine((($cYellow) + "  [ ACTIVE BCDEDIT BOOT MANAGER & OS LOADER STORE ]" + ($cReset)));

    $bcdOut = @(bcdedit /enum active);
    $shown = 0;
    for ($b = 0; (($b) -lt ($bcdOut.Count)) -and (($shown) -lt 20); $b++) {
        $ln = ($bcdOut[($b)]).TrimEnd();
        if (-not [string]::IsNullOrWhiteSpace(($ln))) {
            [System.Console]::WriteLine((($cWhite) + "  " + (FitPlain ($ln) 148) + ($cReset)));
            $shown++;
        }
    }
    WaitModuleReturn;
}

function InvokePcieBusInspector {
    ShowModuleHeader "MOTHERBOARD PCIE SYSTEM SLOTS & USB CONTROLLER TOPOLOGY";
    [System.Console]::WriteLine((($cYellow) + "  [ SMBIOS MOTHERBOARD PCIE / M.2 SYSTEM SLOTS ]" + ($cReset)));
    $slots = @(Get-CimInstance -ClassName:("Win32_SystemSlot") -ErrorAction:("SilentlyContinue"));
    for ($s = 0; (($s) -lt ($slots.Count)) -and (($s) -lt 12); $s++) {
        $sl = $slots[($s)];
        $des = FitPlain ($sl.SlotDesignation) 32;
        $st  = FitPlain ($sl.Status) 18;
        $usg = if (($sl.CurrentUsage) -eq 4) { "In Use (Populated)" } elseif (($sl.CurrentUsage) -eq 3) { "Available (Empty)" } else { "Reserved/System" };
        $uCol = if (($sl.CurrentUsage) -eq 4) { ($cGreen) } else { ($cGray) };
        [System.Console]::WriteLine((($cWhite) + "  Slot: " + ($cCyan) + ($des) + ($cWhite) + " " + ($V) + " Status: " + ($st) + " " + ($V) + " State: " + ($uCol) + ($usg) + ($cReset)));
    }
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
    [System.Console]::WriteLine((($cYellow) + "  [ ACTIVE USB HOST CONTROLLERS & ROOT HUBS ]" + ($cReset)));
    $usb = @(Get-CimInstance -ClassName:("Win32_USBController") -ErrorAction:("SilentlyContinue"));
    for ($u = 0; (($u) -lt ($usb.Count)) -and (($u) -lt 8); $u++) {
        $uc = $usb[($u)];
        [System.Console]::WriteLine((($cWhite) + "  " + (FitPlain ($uc.Name) 64) + " " + ($V) + " " + ($cGreen) + (FitPlain ($uc.Status) 14) + ($cGray) + (FitPlain ($uc.PNPDeviceID) 66) + ($cReset)));
    }
    WaitModuleReturn;
}

function InvokeProcessModulesInspector {
    ShowModuleHeader "PROCESS LOADED MODULES (DLL) & HANDLE FORENSIC INSPECTOR";
    $target = Read-Host -Prompt:("Enter Target PID or Process Name (e.g., explorer or 1234)");
    if (-not [string]::IsNullOrWhiteSpace(($target))) {
        $procObj = $null;
        $pidVal = 0;
        if ([int]::TryParse(($target.Trim()), [ref]($pidVal))) {
            $procObj = Get-Process -Id:($pidVal) -ErrorAction:("SilentlyContinue");
        } else {
            $foundProcs = @(Get-Process -Name:($target.Trim()) -ErrorAction:("SilentlyContinue"));
            if (($foundProcs.Count) -gt 0) { $procObj = $foundProcs[0]; }
        }
        if ($procObj) {
            [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
            $wsMB = [math]::Round(($procObj.WorkingSet64) / 1MB, 1);
            [System.Console]::WriteLine((($cYellow) + "  Target Process : " + ($cWhite) + ([string]($procObj.ProcessName)) + " (PID: " + ([string]($procObj.Id)) + ")  " + ($V) + "  Handles: " + ([string]($procObj.HandleCount)) + "  " + ($V) + "  Threads: " + ([string]($procObj.Threads.Count)) + "  " + ($V) + "  Working Set: " + ([string]($wsMB)) + " MB" + ($cReset)));
            [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
            [System.Console]::WriteLine((($cYellow) + "  " + ("MODULE NAME".PadRight(32)) + ("MEMORY SIZE".PadRight(16)) + ("FILE VERSION".PadRight(24)) + "FULL MODULE BINARY PATH" + ($cReset)));
            [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
            try {
                $mods = @($procObj.Modules);
                $shown = 0;
                for ($m = 0; (($m) -lt ($mods.Count)) -and (($shown) -lt 22); $m++) {
                    $mod = $mods[($m)];
                    $mName = FitPlain ($mod.ModuleName) 32;
                    $mSize = FitPlain (([string]([math]::Round(($mod.ModuleMemorySize) / 1KB))) + " KB") 16;
                    $mVer  = FitPlain ($mod.FileVersionInfo.FileVersion) 24;
                    $mPath = FitPlain ($mod.FileName) 76;
                    [System.Console]::WriteLine((($cWhite) + "  " + ($mName) + ($cCyan) + ($mSize) + ($cGreen) + ($mVer) + ($cGray) + ($mPath) + ($cReset)));
                    $shown++;
                }
                [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
                [System.Console]::WriteLine((($cGreen) + "  Total Loaded Modules in Process Address Space: " + ([string]($mods.Count)) + " (Showing top " + ([string]($shown)) + ")" + ($cReset)));
            } catch {
                [System.Console]::WriteLine((($cRed) + "  [ACCESS DENIED] Protected Ring-0 / PPL Process. Elevate console or select standard user-mode process." + ($cReset)));
            }
        } else {
            [System.Console]::WriteLine((($cRed) + "  [!] Process not found." + ($cReset)));
        }
    }
    WaitModuleReturn;
}

function InvokeScheduledTasksAuditor {
    ShowModuleHeader "THIRD-PARTY SCHEDULED TASKS & PERSISTENCE AUDITOR";
    [System.Console]::WriteLine((($cYellow) + "  " + ("TASK NAME".PadRight(36)) + ("STATE".PadRight(14)) + ("TASK PATH".PadRight(36)) + "EXECUTE ACTION / BINARY PAYLOAD" + ($cReset)));
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));

    $tasks = @(Get-ScheduledTask -ErrorAction:("SilentlyContinue"));
    $shown = 0;
    for ($i = 0; (($i) -lt ($tasks.Count)) -and (($shown) -lt 22); $i++) {
        $t = $tasks[($i)];
        $tPath = [string]($t.TaskPath);
        $tState = [string]($t.State);
        if ((($tState) -ne "Disabled") -and (($tPath) -notmatch "^\\Microsoft\\")) {
            $actStr = "Custom Handler";
            if (($t.Actions) -and (($t.Actions.Count) -gt 0)) {
                $exe = [string]($t.Actions[0].Execute);
                $arg = [string]($t.Actions[0].Arguments);
                if ($exe) { $actStr = ($exe + " " + $arg).Trim(); }
            }
            $nm = FitPlain ($t.TaskName) 36;
            $st = FitPlain ($tState) 14;
            $pt = FitPlain ($tPath) 36;
            $ac = FitPlain ($actStr) 62;
            $stCol = if (($tState) -eq "Running") { ($cGreen) } else { ($cCyan) };
            [System.Console]::WriteLine((($cWhite) + "  " + ($nm) + ($stCol) + ($st) + ($cGray) + ($pt) + ($cWhite) + ($ac) + ($cReset)));
            $shown++;
        }
    }
    if (($shown) -eq 0) {
        [System.Console]::WriteLine((($cGreen) + "  [OK] Zero active non-Microsoft scheduled tasks detected." + ($cReset)));
    }
    WaitModuleReturn;
}

function InvokeDriverDeviceAuditor {
    ShowModuleHeader "KERNEL DRIVER & PNP HARDWARE DEVICE ERROR AUDITOR";
    $errDevs = @(Get-CimInstance -ClassName:("Win32_PnPEntity") -Filter:("ConfigManagerErrorCode != 0") -ErrorAction:("SilentlyContinue"));
    [System.Console]::WriteLine((($cYellow) + "  [ PNP HARDWARE DEVICE HEALTH CHECK ]" + ($cReset)));
    if (($errDevs.Count) -gt 0) {
        for ($i = 0; ($i) -lt ($errDevs.Count); $i++) {
            $ed = $errDevs[($i)];
            [System.Console]::WriteLine((($cRed) + "  [FAULT] " + (([string]($ed.Name)).PadRight(45)) + " " + ($V) + " Error Code: " + ([string]($ed.ConfigManagerErrorCode)) + " " + ($V) + " " + ([string]($ed.DeviceID)) + ($cReset)));
        }
    } else {
        [System.Console]::WriteLine((($cGreen) + "  [OK] Zero hardware device faults detected in PnP Configuration Manager." + ($cReset)));
    }

    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
    [System.Console]::WriteLine((($cYellow) + "  [ RUNNING RING-0 KERNEL FILE SYSTEM & HARDWARE DRIVERS (SAMPLE) ]" + ($cReset)));
    [System.Console]::WriteLine((($cYellow) + "  " + ("DRIVER NAME".PadRight(24)) + ("DISPLAY NAME".PadRight(44)) + ("STATE".PadRight(14)) + ("START MODE".PadRight(16)) + "BINARY PATH" + ($cReset)));
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));

    $drvExRegex = "(?i)\\Windows\\System32\\drivers\\(" + (@("acpi","volmgr","partmgr","disk","mountmgr","fltmgr","ntfs","ksecdd","tcpip","ndis") -join ($V)) + ")\.sys";
    $kDrvs = @(Get-CimInstance -ClassName:("Win32_SystemDriver") -Filter:("State='Running'") -ErrorAction:("SilentlyContinue"));
    $shown = 0;
    for ($d = 0; (($d) -lt ($kDrvs.Count)) -and (($shown) -lt 18); $d++) {
        $drv = $kDrvs[($d)];
        $pName = [string]($drv.PathName);
        if (($pName) -notmatch ($drvExRegex)) {
            $nm = FitPlain ($drv.Name) 24;
            $dn = FitPlain ($drv.DisplayName) 44;
            $st = FitPlain ($drv.State) 14;
            $sm = FitPlain ($drv.StartMode) 16;
            $pt = FitPlain ($pName) 48;
            [System.Console]::WriteLine((($cWhite) + "  " + ($nm) + ($cCyan) + ($dn) + ($cGreen) + ($st) + ($cWhite) + ($sm) + ($cGray) + ($pt) + ($cReset)));
            $shown++;
        }
    }
    WaitModuleReturn;
}

function InvokeWorkstationBoost {
    ShowModuleHeader "WORKSTATION & GAMING LOW-LATENCY BOOST PROTOCOL";
    $osBefore = Get-CimInstance -ClassName:("Win32_OperatingSystem");
    $freeBeforeMB = [math]::Round(($osBefore.FreePhysicalMemory) / 1024.0, 1);

    [System.Console]::WriteLine((($cYellow) + "  [1/4] Activating High Performance Power Profile..." + ($cReset)));
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c;

    [System.Console]::WriteLine((($cYellow) + "  [2/4] Purging DNS Resolver & Resetting Network Buffers..." + ($cReset)));
    Clear-DnsClientCache -ErrorAction:("SilentlyContinue");

    [System.Console]::WriteLine((($cYellow) + "  [3/4] Cleaning Temporary I/O Cache Directories..." + ($cReset)));
    $tPath = [System.IO.Path]::Combine(($env:TEMP), "*");
    Remove-Item -Path:($tPath) -Recurse -Force -ErrorAction:("SilentlyContinue");

    [System.Console]::WriteLine((($cYellow) + "  [4/4] Compressing Process Working Sets via Win32 PSAPI..." + ($cReset)));
    $procs = [System.Diagnostics.Process]::GetProcesses();
    $trimmedCount = 0;
    for ($i = 0; ($i) -lt ($procs.Length); $i++) {
        try {
            $res = [Win32Mem]::EmptyWorkingSet(($procs[($i)].Handle));
            if (($res) -ne 0) { $trimmedCount++; }
        } catch {}
    }
    [System.GC]::Collect();
    [System.Threading.Thread]::Sleep(500);

    $osAfter = Get-CimInstance -ClassName:("Win32_OperatingSystem");
    $freeAfterMB = [math]::Round(($osAfter.FreePhysicalMemory) / 1024.0, 1);
    $reclaimedMB = [math]::Max(0.0, [math]::Round(($freeAfterMB) - ($freeBeforeMB), 1));

    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
    [System.Console]::WriteLine((($cGreen) + "  [BOOST COMPLETE] System tuned for maximum compute & low-latency execution." + ($cReset)));
    [System.Console]::WriteLine((($cWhite) + "  Processes Optimized : " + ([string]($trimmedCount)) + "  " + ($V) + "  Memory Reclaimed : +" + ([string]($reclaimedMB)) + " MB  " + ($V) + "  Free RAM : " + ([string]($freeAfterMB)) + " MB" + ($cReset)));
    WaitModuleReturn;
}

function InvokeDnsLatencyMatrix {
    ShowModuleHeader "GLOBAL DNS LATENCY BENCHMARK & RESOLVER SWITCHER";
    [System.Console]::WriteLine((($cYellow) + "  Testing round-trip latency across global DNS anycast nodes..." + ($cReset)));
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));

    $nodes = @(
        @{ Name = "Local Default Gateway"; IP = ($gateway) },
        @{ Name = "Cloudflare Primary DNS"; IP = "1.1.1.1" },
        @{ Name = "Cloudflare Secondary DNS"; IP = "1.0.0.1" },
        @{ Name = "Google Public DNS Primary"; IP = "8.8.8.8" },
        @{ Name = "Google Public DNS Secondary"; IP = "8.8.4.4" },
        @{ Name = "Quad9 Security DNS"; IP = "9.9.9.9" }
    );

    for ($n = 0; ($n) -lt ($nodes.Count); $n++) {
        $nd = $nodes[($n)];
        if (($nd.IP) -and (($nd.IP) -ne "N/A")) {
            $lat = GetFastLatency ($nd.IP);
            $lCol = if (($lat) -eq "OFFLINE") { ($cRed) } else { ($cGreen) };
            [System.Console]::WriteLine((($cWhite) + "  " + (($nd.Name).PadRight(32)) + " " + ($V) + " " + ($cCyan) + (($nd.IP).PadRight(18)) + ($cReset) + " " + ($V) + " Latency: " + ($lCol) + ($lat) + ($cReset)));
        }
    }

    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
    [System.Console]::WriteLine((($cCyan) + "  [1] Set Cloudflare DNS (1.1.1.1)   [2] Set Google DNS (8.8.8.8)   [3] Reset to DHCP Automatic   [Enter] Return" + ($cReset)));
    $sel = Read-Host -Prompt:("Select DNS Configuration");
    if ((($sel) -eq "1") -or (($sel) -eq "2") -or (($sel) -eq "3")) {
        $activeIf = @(Get-NetAdapter -Physical -ErrorAction:("SilentlyContinue"));
        for ($a = 0; ($a) -lt ($activeIf.Count); $a++) {
            if (($activeIf[($a)].Status) -eq "Up") {
                $ifIdx = $activeIf[($a)].ifIndex;
                if (($sel) -eq "1") {
                    Set-DnsClientServerAddress -InterfaceIndex:($ifIdx) -ServerAddresses:@("1.1.1.1","1.0.0.1") -ErrorAction:("SilentlyContinue");
                    [System.Console]::WriteLine((($cGreen) + "  [OK] Cloudflare DNS applied to interface." + ($cReset)));
                } elseif (($sel) -eq "2") {
                    Set-DnsClientServerAddress -InterfaceIndex:($ifIdx) -ServerAddresses:@("8.8.8.8","8.8.4.4") -ErrorAction:("SilentlyContinue");
                    [System.Console]::WriteLine((($cGreen) + "  [OK] Google DNS applied to interface." + ($cReset)));
                } elseif (($sel) -eq "3") {
                    Set-DnsClientServerAddress -InterfaceIndex:($ifIdx) -ResetServerAddresses -ErrorAction:("SilentlyContinue");
                    [System.Console]::WriteLine((($cGreen) + "  [OK] Interface reset to DHCP Automatic DNS." + ($cReset)));
                }
            }
        }
        Clear-DnsClientCache -ErrorAction:("SilentlyContinue");
        [System.Threading.Thread]::Sleep(1500);
    }
}

function InvokeSecurityPortAuditor {
    ShowModuleHeader "SYSTEM SECURITY POSTURE & LISTENING PORT AUDITOR";
    $sbState = try { if (Confirm-SecureBootUEFI) { "ENABLED" } else { "DISABLED" } } catch { "UNSUPPORTED / LEGACY" };
    $mpStat  = Get-MpComputerStatus -ErrorAction:("SilentlyContinue");
    $avState = if (($mpStat) -and ($mpStat.RealTimeProtectionEnabled)) { "ACTIVE (Real-Time ON)" } else { "DISABLED / THIRD-PARTY" };
    $fwProfs = @(Get-NetFirewallProfile -ErrorAction:("SilentlyContinue"));
    $fwStr   = [System.Collections.Generic.List[string]]::new();
    for ($f = 0; ($f) -lt ($fwProfs.Count); $f++) {
        $fwStr.Add((([string]($fwProfs[($f)].Name)) + ":" + ([string]($fwProfs[($f)].Enabled))));
    }

    [System.Console]::WriteLine((($cYellow) + "  [ SECURITY SUBSYSTEM STATUS ]" + ($cReset)));
    [System.Console]::WriteLine((($cWhite) + "  UEFI Secure Boot : " + ($cGreen) + ($sbState.PadRight(22)) + ($cWhite) + " " + ($V) + " Defender Engine : " + ($cCyan) + ($avState.PadRight(26)) + ($cWhite) + " " + ($V) + " Firewall : " + ([string]::Join(" / ", $fwStr)) + ($cReset)));
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
    [System.Console]::WriteLine((($cYellow) + "  " + ("LOCAL ADDRESS".PadRight(24)) + ("PORT".PadRight(12)) + ("PID".PadRight(12)) + ("PROCESS NAME".PadRight(32)) + "EXECUTABLE PATH" + ($cReset)));
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));

    $listen = @(Get-NetTCPConnection -State:("Listen") -ErrorAction:("SilentlyContinue"));
    $seenPorts = [System.Collections.Generic.HashSet[int]]::new();
    $count = 0;
    for ($i = 0; (($i) -lt ($listen.Count)) -and (($count) -lt 20); $i++) {
        $l = $listen[($i)];
        $prt = [int]($l.LocalPort);
        if (-not ($seenPorts.Contains(($prt)))) {
            $null = $seenPorts.Add(($prt));
            $pObj = Get-Process -Id:($l.OwningProcess) -ErrorAction:("SilentlyContinue");
            $pNm  = if ($pObj) { [string]($pObj.Name) } else { "System/Kernel" };
            $pPt  = try { if ($pObj.MainModule.FileName) { [string]($pObj.MainModule.FileName) } else { "Ring-0 Kernel" } } catch { "Protected Service" };
            $pPtPad = FitPlain ($pPt) 64;
            [System.Console]::WriteLine((($cWhite) + "  " + (([string]($l.LocalAddress)).PadRight(24)) + ($cCyan) + (([string]($prt)).PadRight(12)) + ($cWhite) + (([string]($l.OwningProcess)).PadRight(12)) + ($cGreen) + ($pNm.PadRight(32)) + ($cGray) + ($pPtPad) + ($cReset)));
            $count++;
        }
    }
    WaitModuleReturn;
}

function InvokeBatteryThermalReport {
    ShowModuleHeader "BATTERY WEAR LEVEL, ACPI THERMAL ZONES & POWER TELEMETRY";
    $batStatic = Get-CimInstance -Namespace:("root/WMI") -ClassName:("BatteryStaticData") -ErrorAction:("SilentlyContinue");
    $batFull   = Get-CimInstance -Namespace:("root/WMI") -ClassName:("BatteryFullChargedCapacity") -ErrorAction:("SilentlyContinue");
    $batStatus = Get-CimInstance -Namespace:("root/WMI") -ClassName:("BatteryStatus") -ErrorAction:("SilentlyContinue");

    if (($batStatic) -and ($batFull)) {
        $desCap  = [double]($batStatic.DesignedCapacity);
        $fulCap  = [double]($batFull.FullChargedCapacity);
        $health  = if (($desCap) -gt 0) { [math]::Round((($fulCap) / ($desCap)) * 100.0, 1) } else { 100.0 };
        $wear    = [math]::Max(0.0, [math]::Round(100.0 - ($health), 1));
        $volt    = if ($batStatus.Voltage) { ([string]([math]::Round(($batStatus.Voltage) / 1000.0, 2))) + " V" } else { "N/A" };
        $rate    = if ($batStatus.ChargeRate) { ([string]([math]::Round(($batStatus.ChargeRate) / 1000.0, 2))) + " W" } else { "0 W" };

        [System.Console]::WriteLine((($cYellow) + "  [ LITHIUM-ION BATTERY DIAGNOSTICS ]" + ($cReset)));
        [System.Console]::WriteLine((($cWhite) + "  Factory Design Capacity : " + ([string]($desCap)) + " mWh" + ($cReset)));
        [System.Console]::WriteLine((($cWhite) + "  Full Charge Capacity    : " + ([string]($fulCap)) + " mWh" + ($cReset)));
        [System.Console]::WriteLine((($cGreen) + "  Battery Health / Wear   : " + ([string]($health)) + "% Health (" + ([string]($wear)) + "% Wear Level)" + ($cReset)));
        [System.Console]::WriteLine((($cCyan)  + "  Live Voltage & Rate     : " + ($volt) + "  " + ($V) + "  Charge Rate: " + ($rate) + ($cReset)));
    } else {
        [System.Console]::WriteLine((($cYellow) + "  [INFO] No WMI smart battery controller detected or desktop AC mode active." + ($cReset)));
    }

    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
    [System.Console]::WriteLine((($cYellow) + "  [ ACPI THERMAL ZONE SENSORS ]" + ($cReset)));
    $tz = @(Get-CimInstance -Namespace:("root/WMI") -ClassName:("MSAcpi_ThermalZoneTemperature") -ErrorAction:("SilentlyContinue"));
    if (($tz.Count) -gt 0) {
        for ($t = 0; ($t) -lt ($tz.Count); $t++) {
            $kelvin = [double]($tz[($t)].CurrentTemperature);
            $cel    = [math]::Round((($kelvin) / 10.0) - 273.15, 1);
            [System.Console]::WriteLine((($cWhite) + "  Sensor [" + ([string]($t)) + "] (" + ([string]($tz[($t)].InstanceName)) + ") : " + ($cGreen) + ([string]($cel)) + " C" + ($cReset)));
        }
    } else {
        [System.Console]::WriteLine((($cWhite) + "  ACPI Thermal Zones managed directly by EC firmware." + ($cReset)));
    }
    WaitModuleReturn;
}

function InvokeMemoryOptimizer {
    ShowModuleHeader "PHYSICAL MEMORY & WORKING SET OPTIMIZATION ENGINE";
    $osBefore = Get-CimInstance -ClassName:("Win32_OperatingSystem");
    $freeBeforeMB = [math]::Round(($osBefore.FreePhysicalMemory) / 1024.0, 1);
    [System.Console]::WriteLine((($cYellow) + "  Available Physical Memory (Before) : " + ([string]($freeBeforeMB)) + " MB" + ($cReset)));
    [System.Console]::WriteLine((($cCyan) + "  Trimming background process working sets via Win32 PSAPI..." + ($cReset)));

    $procs = [System.Diagnostics.Process]::GetProcesses();
    $trimmedCount = 0;
    for ($i = 0; ($i) -lt ($procs.Length); $i++) {
        try {
            $res = [Win32Mem]::EmptyWorkingSet(($procs[($i)].Handle));
            if (($res) -ne 0) { $trimmedCount++; }
        } catch {}
    }
    [System.GC]::Collect();
    [System.GC]::WaitForPendingFinalizers();
    [System.Threading.Thread]::Sleep(600);

    $osAfter = Get-CimInstance -ClassName:("Win32_OperatingSystem");
    $freeAfterMB = [math]::Round(($osAfter.FreePhysicalMemory) / 1024.0, 1);
    $reclaimedMB = [math]::Max(0.0, [math]::Round(($freeAfterMB) - ($freeBeforeMB), 1));

    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
    [System.Console]::WriteLine((($cWhite) + "  Processes Trimmed                  : " + ([string]($trimmedCount)) + " Processes" + ($cReset)));
    [System.Console]::WriteLine((($cWhite) + "  Available Physical Memory (After)  : " + ([string]($freeAfterMB)) + " MB" + ($cReset)));
    [System.Console]::WriteLine((($cGreen) + "  Total Physical RAM Reclaimed       : +" + ([string]($reclaimedMB)) + " MB" + ($cReset)));
    WaitModuleReturn;
}

function InvokeGpuPowerController {
    ShowModuleHeader "GPU HARDWARE TELEMETRY & WINDOWS POWER SCHEME CONTROLLER";
    $nv = GetNvidiaMetrics;
    if ($nv.Valid) {
        [System.Console]::WriteLine((($cYellow) + "  [ NVIDIA DEDICATED GPU LIVE STATE ]" + ($cReset)));
        [System.Console]::WriteLine((($cWhite) + "  Power State (P-State) : " + ($nv.PState) + "  " + ($V) + "  Core Clock : " + ($nv.GpuClock) + "  " + ($V) + "  VRAM Clock : " + ($nv.MemClock) + "  " + ($V) + "  Temperature : " + ($nv.GpuTemp) + "  " + ($V) + "  Power : " + ($nv.GpuPwr) + ($cReset)));
        [System.Console]::WriteLine((($cWhite) + "  VRAM Allocation       : " + ([string]($nv.VramUse)) + " GB / " + ([string]($nv.VramTot)) + " GB  " + ($V) + "  Core Load : " + ([string]($nv.GpuLoad)) + "%" + ($cReset)));
    }

    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
    [System.Console]::WriteLine((($cYellow) + "  [ WINDOWS POWER SCHEMES ]" + ($cReset)));
    $pwrOut = @(powercfg /list);
    for ($p = 0; ($p) -lt ($pwrOut.Count); $p++) {
        $line = [string]($pwrOut[($p)]);
        if (($line.IndexOf("GUID")) -ge 0) {
            $col = if (($line.IndexOf("*")) -ge 0) { ($cGreen) } else { ($cWhite) };
            [System.Console]::WriteLine((($col) + "  " + ($line.Trim()) + ($cReset)));
        }
    }
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
    [System.Console]::WriteLine((($cCyan) + "  [1] Activate High Performance   [2] Activate Balanced   [3] Unlock Ultimate Performance   [Enter] Return" + ($cReset)));
    $choice = Read-Host -Prompt:("Select Power Action");
    if (($choice) -eq "1") {
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c;
        [System.Console]::WriteLine((($cGreen) + "  [OK] Switched to High Performance mode." + ($cReset)));
        [System.Threading.Thread]::Sleep(1200);
    } elseif (($choice) -eq "2") {
        powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e;
        [System.Console]::WriteLine((($cGreen) + "  [OK] Switched to Balanced mode." + ($cReset)));
        [System.Threading.Thread]::Sleep(1200);
    } elseif (($choice) -eq "3") {
        $null = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61;
        [System.Console]::WriteLine((($cGreen) + "  [OK] Ultimate Performance scheme unlocked." + ($cReset)));
        [System.Threading.Thread]::Sleep(1200);
    }
}

function InvokeSmartHealth {
    ShowModuleHeader "PHYSICAL STORAGE S.M.A.R.T. & RELIABILITY TELEMETRY";
    $pDisks = @(Get-PhysicalDisk -ErrorAction:("SilentlyContinue"));
    [System.Console]::WriteLine((($cYellow) + "  " + ("ID".PadRight(6)) + ("FRIENDLY NAME".PadRight(36)) + ("MEDIA TYPE".PadRight(16)) + ("BUS TYPE".PadRight(14)) + ("HEALTH".PadRight(16)) + ("STATUS".PadRight(18)) + "CAPACITY" + ($cReset)));
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));

    for ($i = 0; ($i) -lt ($pDisks.Count); $i++) {
        $d = $pDisks[($i)];
        $szG = ([string]([math]::Round(($d.Size) / 1GB, 1))) + " GB";
        $hStr = [string]($d.HealthStatus);
        $hCol = if (($hStr) -eq "Healthy") { ($cGreen) } else { ($cRed) };
        [System.Console]::WriteLine((($cWhite) + "  " + (([string]($d.DeviceId)).PadRight(6)) + (([string]($d.FriendlyName)).PadRight(36)) + (([string]($d.MediaType)).PadRight(16)) + (([string]($d.BusType)).PadRight(14)) + ($hCol) + ($hStr.PadRight(16)) + ($cWhite) + (([string]($d.OperationalStatus)).PadRight(18)) + ($szG) + ($cReset)));
    }
    WaitModuleReturn;
}

function InvokeStartupAudit {
    ShowModuleHeader "WINDOWS STARTUP & AUTORUN REGISTRY AUDITOR";
    $startCmds = @(Get-CimInstance -ClassName:("Win32_StartupCommand") -ErrorAction:("SilentlyContinue"));
    [System.Console]::WriteLine((($cYellow) + "  " + ("NAME".PadRight(32)) + ("USER / CONTEXT".PadRight(28)) + ("LOCATION".PadRight(24)) + "COMMAND / BINARY PATH" + ($cReset)));
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));

    for ($i = 0; ($i) -lt ($startCmds.Count); $i++) {
        $sc = $startCmds[($i)];
        $nm = FitPlain ($sc.Name) 32;
        $us = FitPlain ($sc.User) 28;
        $lc = FitPlain ($sc.Location) 24;
        $cm = FitPlain ($sc.Command) 62;
        [System.Console]::WriteLine((($cWhite) + "  " + ($nm) + ($cCyan) + ($us) + ($cGray) + ($lc) + ($cWhite) + ($cm) + ($cReset)));
    }
    WaitModuleReturn;
}

function InvokeExecutableInventory {
    ShowModuleHeader "SYSTEM EXECUTABLE INVENTORY & DEEP SEARCH";
    $query = Read-Host -Prompt:("Enter search filter (or * to list all discovered applications)");
    if (-not [string]::IsNullOrWhiteSpace(($query))) {
        [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
        $matchesFound = 0;
        for ($i = 0; ($i) -lt ($thirdPartyApps.Count); $i++) {
            $app = $thirdPartyApps[($i)];
            $aName = [string]($app["Name"]);
            $aPath = [string]($app["Path"]);
            $isMatch = (($query) -eq "*") -or (($aName.IndexOf(($query), [System.StringComparison]::OrdinalIgnoreCase)) -ge 0);
            if ($isMatch) {
                $matchesFound++;
                $stStr = [string]($app["CurrentStatus"]);
                $stCol = if (($stStr) -eq "RUNNING") { ($cGreen) } else { ($cGray) };
                $idPad = FitPlain ("[" + ($app["ID"]) + "]") 7;
                $nmPad = FitPlain ($aName) 36;
                $ptPad = FitPlain ($aPath) 90;
                [System.Console]::WriteLine((($cWhite) + " " + ($idPad) + ($nmPad) + " " + ($V) + " " + ($cGray) + ($ptPad) + " " + ($V) + " " + ($stCol) + ($stStr) + ($cReset)));
            }
        }
        [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
        if (($matchesFound) -gt 0) {
            $launchId = Read-Host -Prompt:("Enter application ID to execute (or press Enter to cancel)");
            if (-not [string]::IsNullOrWhiteSpace(($launchId))) {
                $cleanId = $launchId.Trim();
                for ($j = 0; ($j) -lt ($thirdPartyApps.Count); $j++) {
                    if (($thirdPartyApps[($j)]["ID"]) -eq ($cleanId)) {
                        Start-Process -FilePath:($thirdPartyApps[($j)]["Path"]);
                        [System.Console]::WriteLine((($cGreen) + "[OK] Launched: " + ($thirdPartyApps[($j)]["Name"]) + ($cReset)));
                        [System.Threading.Thread]::Sleep(1200);
                        break;
                    }
                }
            }
        } else {
            [System.Console]::WriteLine((($cRed) + "[!] No matching applications found." + ($cReset)));
            [System.Threading.Thread]::Sleep(1500);
        }
    }
}

function InvokeProcessTermination {
    try { [System.Console]::CursorVisible = $true; } catch {};
    [System.Console]::WriteLine("");
    [System.Console]::WriteLine((($cRed) + "[PROCESS TERMINATION] Enter Process Name or PID:" + ($cReset)));
    $target = Read-Host -Prompt:("Target");
    if (-not [string]::IsNullOrWhiteSpace(($target))) {
        $pidNum = 0;
        if ([int]::TryParse(($target), [ref]($pidNum))) {
            Stop-Process -Id:($pidNum) -Force -ErrorAction:("SilentlyContinue");
            [System.Console]::WriteLine((($cRed) + "[TERMINATED] PID: " + ($target) + ($cReset)));
        } else {
            Stop-Process -Name:($target) -Force -ErrorAction:("SilentlyContinue");
            [System.Console]::WriteLine((($cRed) + "[TERMINATED] Process Name: " + ($target) + ($cReset)));
        }
        [System.Threading.Thread]::Sleep(1500);
    }
}

function InvokeNetworkFlush {
    [System.Console]::WriteLine("");
    [System.Console]::WriteLine((($cCyan) + "[NETWORK] Flushing DNS resolver cache..." + ($cReset)));
    Clear-DnsClientCache -ErrorAction:("SilentlyContinue");
    [System.Console]::WriteLine((($cGreen) + "[OK] DNS resolver cache cleared." + ($cReset)));
    [System.Threading.Thread]::Sleep(1500);
}

function InvokeTempClean {
    [System.Console]::WriteLine("");
    [System.Console]::WriteLine((($cCyan) + "[MAINTENANCE] Cleaning temporary directory..." + ($cReset)));
    $tPath = [System.IO.Path]::Combine(($env:TEMP), "*");
    Remove-Item -Path:($tPath) -Recurse -Force -ErrorAction:("SilentlyContinue");
    [System.Console]::WriteLine((($cGreen) + "[OK] Temporary files purged." + ($cReset)));
    [System.Threading.Thread]::Sleep(1500);
}

function InvokeLogAudit {
    ShowModuleHeader "WINDOWS SYSTEM EVENT LOG AUDIT (LAST 24 HOURS - CRITICAL/ERROR)";
    $startTime = (Get-Date).AddHours(-24);
    $events = @(Get-WinEvent -FilterHashtable:@{LogName='System'; Level=1,2; StartTime=$startTime} -MaxEvents:25 -ErrorAction:("SilentlyContinue"));
    if (($events.Count) -gt 0) {
        [System.Console]::WriteLine((($cYellow) + "Showing " + ([string]($events.Count)) + " critical/error events from the last 24 hours:" + ($cReset)));
        [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
        for ($e = 0; ($e) -lt ($events.Count); $e++) {
            $ev = $events[($e)];
            $timeStr = $ev.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss");
            $prov = FitPlain ($ev.ProviderName) 28;
            $msg = ([string]($ev.Message)).Replace(($NL), " ").Replace("`r", " ").Replace("`n", " ").Trim();
            $msgClean = FitPlain ($msg) 86;
            [System.Console]::WriteLine((($cRed) + " [" + ($timeStr) + "] ID:" + (FitPlain ([string]($ev.Id)) 7) + " " + ($V) + " " + ($prov) + " " + ($V) + " " + ($cWhite) + ($msgClean) + ($cReset)));
        }
    } else {
        [System.Console]::WriteLine((($cGreen) + "  [OK] Zero critical or error events recorded in the last 24 hours." + ($cReset)));
    }
    WaitModuleReturn;
}

function InvokeDiskInspector {
    ShowModuleHeader "LOGICAL VOLUME & STORAGE INVENTORY";
    $vols = @(Get-CimInstance -ClassName:("Win32_LogicalDisk") -Filter:("DriveType=3") -ErrorAction:("SilentlyContinue"));
    [System.Console]::WriteLine((($cYellow) + "  " + ("VOLUME".PadRight(12)) + ("LABEL".PadRight(24)) + ("FILE SYSTEM".PadRight(16)) + ("TOTAL CAPACITY".PadRight(22)) + ("FREE SPACE".PadRight(22)) + ("VOLUME SERIAL".PadRight(20)) + "UTILIZATION" + ($cReset)));
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));

    for ($v = 0; ($v) -lt ($vols.Count); $v++) {
        $vol = $vols[($v)];
        $totG = [math]::Round(($vol.Size) / 1GB, 2);
        $freG = [math]::Round(($vol.FreeSpace) / 1GB, 2);
        $useG = [math]::Round(($totG) - ($freG), 2);
        $pct  = if (($totG) -gt 0) { [math]::Round((($useG) / ($totG)) * 100.0, 1) } else { 0 };
        $lbl  = if ($vol.VolumeName) { [string]($vol.VolumeName) } else { "Local Volume" };
        $ser  = if ($vol.VolumeSerialNumber) { [string]($vol.VolumeSerialNumber) } else { "N/A" };
        [System.Console]::WriteLine((($cWhite) + "  " + (([string]($vol.DeviceID)).PadRight(12)) + ($lbl.PadRight(24)) + (([string]($vol.FileSystem)).PadRight(16)) + (([string]($totG) + " GB").PadRight(22)) + (([string]($freG) + " GB").PadRight(22)) + ($ser.PadRight(20)) + ([string]($pct) + "%") + ($cReset)));
    }
    WaitModuleReturn;
}

function InvokeSystemBenchmark {
    ShowModuleHeader "CPU & MEMORY SUBSYSTEM DIAGNOSTIC BENCHMARK";
    [System.Console]::WriteLine((($cYellow) + "[1/2] Running Floating-Point Arithmetic Workload..." + ($cReset)));
    $swCpu = [System.Diagnostics.Stopwatch]::StartNew();
    $val = 0.0;
    for ($i = 1; ($i) -le 1500000; $i++) { $val += [math]::Sqrt(($i)) * [math]::Sin(($i)); }
    $swCpu.Stop();
    $cpuMs = $swCpu.ElapsedMilliseconds;
    $cpuScore = [math]::Round((1500000.0 / [math]::Max(1, ($cpuMs))) * 1.5);

    [System.Console]::WriteLine((($cYellow) + "[2/2] Running Memory Allocation & Throughput Workload..." + ($cReset)));
    $swRam = [System.Diagnostics.Stopwatch]::StartNew();
    $arr = [int[]]::new(5000000);
    for ($j = 0; ($j) -lt 5000000; $j += 10) { $arr[($j)] = ($j); }
    $swRam.Stop();
    $ramMs = $swRam.ElapsedMilliseconds;
    $ramScore = [math]::Round((5000000.0 / [math]::Max(1, ($ramMs))) * 0.5);
    $arr = $null;
    [System.GC]::Collect();

    $totalScore = ($cpuScore) + ($ramScore);
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
    [System.Console]::WriteLine((($cWhite) + "  CPU Execution Duration    : " + ([string]($cpuMs)) + " ms" + ($cReset)));
    [System.Console]::WriteLine((($cCyan)  + "  CPU Compute Index         : " + ([string]($cpuScore)) + " PTS" + ($cReset)));
    [System.Console]::WriteLine((($cWhite) + "  Memory Allocation Latency : " + ([string]($ramMs)) + " ms" + ($cReset)));
    [System.Console]::WriteLine((($cCyan)  + "  Memory Throughput Index   : " + ([string]($ramScore)) + " PTS" + ($cReset)));
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
    [System.Console]::WriteLine((($cGreen) + "  COMPOSITE SYSTEM INDEX    : " + ([string]($totalScore)) + " PTS" + ($cReset)));
    WaitModuleReturn;
}

function InvokeSocketInspector {
    ShowModuleHeader "ACTIVE TCP NETWORK CONNECTIONS (ESTABLISHED)";
    $rawConns = @(Get-NetTCPConnection -State:("Established") -ErrorAction:("SilentlyContinue"));
    $shown = 0;
    [System.Console]::WriteLine((($cYellow) + "  " + ("PROCESS NAME".PadRight(28)) + ("PID".PadRight(12)) + ("LOCAL ENDPOINT".PadRight(36)) + ("REMOTE ENDPOINT".PadRight(38)) + "STATE" + ($cReset)));
    [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));

    for ($i = 0; (($i) -lt ($rawConns.Count)) -and (($shown) -lt 25); $i++) {
        $c = $rawConns[($i)];
        $rAddr = [string]($c.RemoteAddress);
        $isLocal = ($rAddr.StartsWith("127.")) -or ($rAddr.StartsWith("0.")) -or (($rAddr) -eq "::1");
        if (-not ($isLocal)) {
            $pObj = Get-Process -Id:($c.OwningProcess) -ErrorAction:("SilentlyContinue");
            $pName = if (($pObj) -and ($pObj.Name)) { [string]($pObj.Name) } else { "System/Kernel" };
            $pNamePad = FitPlain ($pName) 28;
            $loc = FitPlain (([string]($c.LocalAddress)) + ":" + ([string]($c.LocalPort))) 36;
            $rem = FitPlain (($rAddr) + ":" + ([string]($c.RemotePort))) 38;
            [System.Console]::WriteLine((($cWhite) + "  " + ($pNamePad) + (FitPlain ([string]($c.OwningProcess)) 12) + ($loc) + ($rem) + "ESTABLISHED" + ($cReset)));
            $shown++;
        }
    }
    if (($shown) -eq 0) {
        [System.Console]::WriteLine((($cGreen) + "  [OK] No active external TCP connections detected." + ($cReset)));
    }
    WaitModuleReturn;
}

function InvokeServiceAudit {
    ShowModuleHeader "WINDOWS AUTOMATIC SERVICE STATE AUDITOR";
    $stoppedSvcs = @(Get-CimInstance -ClassName:("Win32_Service") -Filter:("StartMode='Auto' AND State!='Running'") -ErrorAction:("SilentlyContinue"));
    if (($stoppedSvcs.Count) -gt 0) {
        [System.Console]::WriteLine((($cYellow) + "Detected " + ([string]($stoppedSvcs.Count)) + " automatic services in STOPPED state:" + ($cReset)));
        [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
        for ($i = 0; ($i) -lt ($stoppedSvcs.Count); $i++) {
            $s = $stoppedSvcs[($i)];
            $dName = FitPlain ([string]($s.DisplayName)) 90;
            [System.Console]::WriteLine((($cRed) + "  [STOPPED] " + (FitPlain ([string]($s.Name)) 32) + " " + ($V) + " " + ($dName) + ($cReset)));
        }
        [System.Console]::WriteLine((($cGray) + ($hdrBorder) + ($cReset)));
        $ans = Read-Host -Prompt:("Start all stopped automatic services? (Y/N)");
        if (($ans.Trim().ToUpper()) -eq "Y") {
            for ($j = 0; ($j) -lt ($stoppedSvcs.Count); $j++) {
                $svcName = $stoppedSvcs[($j)].Name;
                Start-Service -Name:($svcName) -ErrorAction:("SilentlyContinue");
                [System.Console]::WriteLine((($cGreen) + "  [+] Service start requested: " + ($svcName) + ($cReset)));
            }
            [System.Threading.Thread]::Sleep(1500);
        }
    } else {
        [System.Console]::WriteLine((($cGreen) + "  [OK] All automatic Windows services are running." + ($cReset)));
        [System.Threading.Thread]::Sleep(1500);
    }
}

function InvokeExportReport {
    $desk = [System.Environment]::GetFolderPath("Desktop");
    $stamp = (Get-Date).ToString("yyyyMMdd_HHmmss");
    $file = [System.IO.Path]::Combine(($desk), ("WESC_Server_Audit_" + ($stamp) + ".txt"));
    $lines = [string[]]@(
        "==========================================================================",
        "          WINDOWS ENTERPRISE SERVER CONSOLE (WESC) INFRASTRUCTURE AUDIT         ",
        "==========================================================================",
        ("Report Timestamp    : " + ((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))),
        ("Operating System    : " + ($osClean) + " (Build " + ($osBuildInfo) + ")"),
        ("System UUID         : " + ($uuidStr)),
        ("System Model        : " + ($sysModelStr)),
        ("Motherboard         : " + ($moboStr) + " (S/N: " + ($moboSerial) + ")"),
        ("BIOS Version        : " + ($biosVer)),
        ("Processor           : " + ($cpuName) + " (" + ($cpuSpec) + ")"),
        ("Memory Configuration: " + ([string]($ramTotalGB)) + " GB Physical RAM @ " + ($ramSpd)),
        ("Primary Graphics    : " + ($gpu0)),
        ("Secondary Graphics  : " + ($gpu1)),
        ("Total Raw Storage   : " + ([string]($totStoreGB)) + " GB"),
        ("Active IPv4 / MAC   : " + ($ipv4) + " / " + ($mac)),
        ("Discovered 3rd-Party: " + ([string]($thirdPartyApps.Count)) + " Applications"),
        "=========================================================================="
    );
    [System.IO.File]::WriteAllLines(($file), ($lines));
    [System.Console]::WriteLine("");
    [System.Console]::WriteLine((($cGreen) + "[OK] Diagnostic report exported: " + ($file) + ($cReset)));
    [System.Threading.Thread]::Sleep(1500);
}

try { [System.Console]::CursorVisible = $false; } catch {};

# ==============================================================================
# INITIALIZE HARDWARE TOPOLOGY & STATIC KERNEL INVENTORY
# ==============================================================================
$thirdPartyApps = DiscoverThirdPartyApps;
$currentPage    = 0;

$osInfo       = Get-CimInstance -ClassName:("Win32_OperatingSystem");
$compSys      = Get-CimInstance -ClassName:("Win32_ComputerSystem");
$board        = Get-CimInstance -ClassName:("Win32_BaseBoard");
$bios         = Get-CimInstance -ClassName:("Win32_BIOS");
$cpus         = @(Get-CimInstance -ClassName:("Win32_Processor"));
$cpu          = $cpus[0];
$caches       = @(Get-CimInstance -ClassName:("Win32_CacheMemory"));
$ramArr       = @(Get-CimInstance -ClassName:("Win32_PhysicalMemory"));
$ramSlotsArr  = @(Get-CimInstance -ClassName:("Win32_PhysicalMemoryArray"));
$ramSlots     = $ramSlotsArr[0];
$netAdapters  = @(Get-CimInstance -ClassName:("Win32_NetworkAdapterConfiguration") -Filter:("IPEnabled=True"));
$netActive    = if (($netAdapters.Count) -gt 0) { $netAdapters[0] } else { $null };
$netHwList    = @(Get-CimInstance -ClassName:("Win32_NetworkAdapter") -Filter:("NetConnectionStatus=2"));
$netSpeed     = if (($netHwList.Count) -gt 0) { $netHwList[0] } else { $null };
$gpus         = @(Get-CimInstance -ClassName:("Win32_VideoController"));
$drives       = @(Get-CimInstance -ClassName:("Win32_DiskDrive"));
$sysProdArr   = @(Get-CimInstance -ClassName:("Win32_ComputerSystemProduct"));
$sysProduct   = $sysProdArr[0];
$pageFiles    = @(Get-CimInstance -ClassName:("Win32_PageFileUsage"));
$qfeList      = @(Get-CimInstance -ClassName:("Win32_QuickFixEngineering"));
$dgInfo       = Get-CimInstance -Namespace:("root/Microsoft/Windows/DeviceGuard") -ClassName:("Win32_DeviceGuard") -ErrorAction:("SilentlyContinue");
$mpInfo       = Get-MpComputerStatus -ErrorAction:("SilentlyContinue");

$idCurrent = [Security.Principal.WindowsIdentity]::GetCurrent();
$prin      = [Security.Principal.WindowsPrincipal]($idCurrent);
$isAdmin   = $prin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);
$secRole   = if ($isAdmin) { "ADMINISTRATOR (Elevated)" } else { "STANDARD USER" };

$sbEnabled   = try { if (Confirm-SecureBootUEFI) { "SecureBoot: ON" } else { "SecureBoot: OFF" } } catch { "UEFI Native" };
$osClean     = ([string]($osInfo.Caption)).Replace("Microsoft ", "").Trim();
$osBuildInfo = ([string]($osInfo.Version)) + " (" + ([string]($osInfo.OSArchitecture)) + ") " + ($V) + " " + ($sbEnabled);
$uuidStr     = if ($sysProduct.UUID) { [string]($sysProduct.UUID) } else { "N/A" };
$vbsStr      = if (($dgInfo) -and (($dgInfo.VirtualizationBasedSecurityStatus) -eq 2)) { "VBS: Running " + ($V) + " HVCI: Active" } else { "VBS: Disabled " + ($V) + " Bare-Metal" };

$cleanMfr    = ([string]($board.Manufacturer)).Replace("Micro-Star International Co., Ltd.", "MSI").Replace("ASUSTeK COMPUTER INC.", "ASUS").Replace("Gigabyte Technology Co., Ltd.", "GIGABYTE").Trim();
$sysModelStr = (([string]($compSys.Model)).Replace("Micro-Star International Co., Ltd.", "MSI")).Trim();
$moboStr     = ($cleanMfr) + " " + ([string]($board.Product)) + " (" + ($sysModelStr) + ")";
$moboSerial  = if ($board.SerialNumber) { [string]($board.SerialNumber) } else { "N/A" };
$biosDateStr = if ($bios.ReleaseDate) { $bios.ReleaseDate.ToString("yyyy-MM-dd") } else { "N/A" };
$biosVer     = ([string]($bios.SMBIOSBIOSVersion)) + " (" + ($biosDateStr) + ")";

$cpuName   = (([string]($cpu.Name)).Replace("(R)", "").Replace("(TM)", "").Replace("CPU ", "").Replace("  ", " ")).Trim();
$cpuSocket = if ($cpu.SocketDesignation) { [string]($cpu.SocketDesignation) } else { "BGA" };
$vtxState  = if ($cpu.VirtualizationFirmwareEnabled) { "VT-x: ON" } else { "VT-x: N/A" };
$cpuSpec   = ([string]($cpu.NumberOfCores)) + "C / " + ([string]($cpu.NumberOfLogicalProcessors)) + "T (" + ($cpuSocket) + " " + ($V) + " " + ($vtxState) + ")";

$l1KB = 0;
for ($c = 0; ($c) -lt ($caches.Count); $c++) {
    if (($caches[($c)].Level) -eq 3) { $l1KB += [int]($caches[($c)].MaxCacheSize); }
}
$l1Str = if (($l1KB) -gt 0) { ([string]($l1KB)) + "K" } else { "864K" };
$l2    = if ($cpu.L2CacheSize) { ([string]([math]::Round(($cpu.L2CacheSize) / 1024.0, 1))) + "M" } else { "N/A" };
$l3    = if ($cpu.L3CacheSize) { ([string]([math]::Round(($cpu.L3CacheSize) / 1024.0, 1))) + "M" } else { "N/A" };
$cpuCache = "L1:" + ($l1Str) + " " + ($V) + " L2:" + ($l2) + " " + ($V) + " L3:" + ($l3);

$ramTotalPhys = 0.0;
for ($r = 0; ($r) -lt ($ramArr.Count); $r++) { $ramTotalPhys += [double]($ramArr[($r)].Capacity); }
$ramTotalGB = [math]::Round(($ramTotalPhys) / 1GB, 1);
$ramSpd     = if ((($ramArr.Count) -gt 0) -and ($ramArr[0].Speed)) { ([string]($ramArr[0].Speed)) + " MHz" } else { "Unknown" };
$ramSlotStr = if ($ramSlots) { ([string]($ramArr.Count)) + "/" + ([string]($ramSlots.MemoryDevices)) + " Slots" } else { "N/A" };
$pfStr      = if (($pageFiles.Count) -gt 0) { ([string]($pageFiles[0].CurrentUsage)) + "MB / " + ([string]($pageFiles[0].AllocatedBaseSize)) + "MB (" + ([string]($pageFiles[0].Name)) + ")" } else { "System Managed" };

$gpu0   = if (($gpus.Count) -gt 0) { (([string]($gpus[0].Name)).Replace("NVIDIA ", "").Replace("AMD ", "").Replace("Intel(R) ", "Intel ")).Trim() } else { "None" };
$gpu1   = if (($gpus.Count) -gt 1) { (([string]($gpus[1].Name)).Replace("NVIDIA ", "").Replace("AMD ", "").Replace("Intel(R) ", "Intel ")).Trim() } else { "None" };
$gpuDrv = if (($gpus.Count) -gt 0) { ([string]($gpus[0].DriverVersion)) + " (WDDM 3.2 / DX12)" } else { "N/A" };

$disp0 = "Internal Display";
for ($g = 0; ($g) -lt ($gpus.Count); $g++) {
    if ($gpus[($g)].CurrentHorizontalResolution) {
        $disp0 = ([string]($gpus[($g)].CurrentHorizontalResolution)) + "x" + ([string]($gpus[($g)].CurrentVerticalResolution)) + " @ " + ([string]($gpus[($g)].CurrentRefreshRate)) + "Hz";
        break;
    }
}

$totStore = 0.0;
for ($d = 0; ($d) -lt ($drives.Count); $d++) { $totStore += [double]($drives[($d)].Size); }
$totStoreGB = [math]::Round(($totStore) / 1GB, 1);

$mac     = if ($netActive.MACAddress) { [string]($netActive.MACAddress) } else { "N/A" };
$ipv4    = if ($netActive.IPAddress) { [string]($netActive.IPAddress[0]) } else { "N/A" };
$gateway = if ($netActive.DefaultIPGateway) { [string]($netActive.DefaultIPGateway[0]) } else { "N/A" };
$dns     = if ($netActive.DNSServerSearchOrder) { [string]($netActive.DNSServerSearchOrder[0]) } else { "N/A" };
$linkSpd = if (($netSpeed) -and ($netSpeed.Speed)) { ([string]([math]::Round(($netSpeed.Speed) / 1000000.0))) + " Mbps" } else { "N/A" };
$netDesc = if ($netActive.Description) { (([string]($netActive.Description)).Replace("(R)", "").Replace("(TM)", "")).Trim() } else { "Disconnected" };

$avSigStr = if (($mpInfo) -and ($mpInfo.AntivirusSignatureVersion)) { "Sig: " + ([string]($mpInfo.AntivirusSignatureVersion)) + " " + ($V) + " RealTime: " + ([string]($mpInfo.RealTimeProtectionEnabled)) } else { "Defender / Custom EDR" };
$qfeStr   = ([string]($qfeList.Count)) + " Installed QFE Patches";
if (($qfeList.Count) -gt 0 -and ($qfeList[0].HotFixID)) { $qfeStr += " (Last: " + ([string]($qfeList[0].HotFixID)) + ")"; }

$boxBorder     = "+" + ("-" * 152) + "+";
$exitDashboard = $false;
$isFirstRun    = $true;

# ==============================================================================
# REAL-TIME TELEMETRY POLLING LOOP (24 SYMMETRIC ROWS x 3 COLUMNS)
# ==============================================================================
while (-not ($exitDashboard)) {
    if ($isFirstRun) {
        [System.Console]::Clear();
        $isFirstRun = $false;
    }

    $liveOs   = Get-CimInstance -ClassName:("Win32_OperatingSystem");
    $liveCpus = @(Get-CimInstance -ClassName:("Win32_Processor"));
    $liveCpu  = $liveCpus[0];

    $upT = (Get-Date) - ($osInfo.LastBootUpTime);
    $bootStr = $osInfo.LastBootUpTime.ToString("HH:mm");
    $upStr = ("{0:00}d {1:00}h {2:00}m {3:00}s (Boot: {4})" -f ($upT.Days), ($upT.Hours), ($upT.Minutes), ($upT.Seconds), ($bootStr));

    $baseMhz = [int]($cpu.MaxClockSpeed);
    $perfSys = Get-CimInstance -ClassName:("Win32_PerfFormattedData_PerfOS_System") -ErrorAction:("SilentlyContinue");
    $ctxSw   = if (($perfSys) -and ($perfSys.ContextSwitchesPersec)) { ([string]($perfSys.ContextSwitchesPersec)) + "/s" } else { "0/s" };
    $sysCall = if (($perfSys) -and ($perfSys.SystemCallsPersec)) { ([string]($perfSys.SystemCallsPersec)) + "/s" } else { "0/s" };

    $perfProc = Get-CimInstance -ClassName:("Win32_PerfFormattedData_Counters_ProcessorInformation") -Filter:("Name='_Total'") -ErrorAction:("SilentlyContinue");
    $intRate  = if (($perfProc) -and ($perfProc.InterruptsPersec)) { ([string]($perfProc.InterruptsPersec)) + "/s" } else { "0/s" };
    $cpuCurMhz = $baseMhz;
    if (($perfProc) -and ($perfProc.ProcessorFrequency) -and (($perfProc.ProcessorFrequency) -gt 0)) {
        $pctPerf = if ($perfProc.PercentProcessorPerformance) { [double]($perfProc.PercentProcessorPerformance) } else { 100.0 };
        $cpuCurMhz = [int][math]::Round(([double]($perfProc.ProcessorFrequency)) * (($pctPerf) / 100.0));
    }

    $ramFreeGB = [math]::Round(($liveOs.FreePhysicalMemory) / 1048576.0, 1);
    $ramUsedGB = [math]::Round(($ramTotalGB) - ($ramFreeGB), 1);
    $ramPct    = if (($ramTotalGB) -gt 0) { [math]::Round((($ramUsedGB) / ($ramTotalGB)) * 100.0, 1) } else { 0 };

    $commitTotGB  = [math]::Round(($liveOs.TotalVirtualMemorySize) / 1048576.0, 1);
    $commitFreeGB = [math]::Round(($liveOs.FreeVirtualMemory) / 1048576.0, 1);
    $commitUsedGB = [math]::Round(($commitTotGB) - ($commitFreeGB), 1);

    $perfMemArr   = @(Get-CimInstance -ClassName:("Win32_PerfFormattedData_PerfOS_Memory"));
    $perfMem      = if (($perfMemArr.Count) -gt 0) { $perfMemArr[0] } else { $null };
    $poolPaged    = if (($perfMem) -and ($perfMem.PoolPagedBytes)) { ([string]([math]::Round(($perfMem.PoolPagedBytes) / 1MB))) + " MB" } else { "N/A" };
    $poolNonPaged = if (($perfMem) -and ($perfMem.PoolNonpagedBytes)) { ([string]([math]::Round(($perfMem.PoolNonpagedBytes) / 1MB))) + " MB" } else { "N/A" };
    $pageFaults   = if (($perfMem) -and ($perfMem.PageFaultsPersec)) { ([string]($perfMem.PageFaultsPersec)) + "/s" } else { "0/s" };

    $perfDiskArr  = @(Get-CimInstance -ClassName:("Win32_PerfFormattedData_PerfDisk_LogicalDisk") -Filter:("Name='_Total'"));
    $perfDisk     = if (($perfDiskArr.Count) -gt 0) { $perfDiskArr[0] } else { $null };
    $diskReadKBs  = if (($perfDisk) -and ($perfDisk.DiskReadBytesPersec)) { ([string]([math]::Round(($perfDisk.DiskReadBytesPersec) / 1KB, 1))) + " KB/s" } else { "0 KB/s" };
    $diskWriteKBs = if (($perfDisk) -and ($perfDisk.DiskWriteBytesPersec)) { ([string]([math]::Round(($perfDisk.DiskWriteBytesPersec) / 1KB, 1))) + " KB/s" } else { "0 KB/s" };
    $diskIops     = if (($perfDisk) -and ($perfDisk.DiskTransfersPersec)) { ([string]($perfDisk.DiskTransfersPersec)) + " IOPS" } else { "0 IOPS" };
    $diskQueue    = if ($perfDisk) { [string]($perfDisk.CurrentDiskQueueLength) } else { "0" };

    $perfNetArr = @(Get-CimInstance -ClassName:("Win32_PerfFormattedData_Tcpip_NetworkInterface"));
    $maxNetBytes = -1.0;
    $perfNet = $null;
    for ($n = 0; ($n) -lt ($perfNetArr.Count); $n++) {
        if ([double]($perfNetArr[($n)].BytesTotalPersec) -gt ($maxNetBytes)) {
            $maxNetBytes = [double]($perfNetArr[($n)].BytesTotalPersec);
            $perfNet = $perfNetArr[($n)];
        }
    }
    $netRxKBs = if (($perfNet) -and ($perfNet.BytesReceivedPersec)) { ([string]([math]::Round(($perfNet.BytesReceivedPersec) / 1KB, 1))) + " KB/s" } else { "0 KB/s" };
    $netTxKBs = if (($perfNet) -and ($perfNet.BytesSentPersec)) { ([string]([math]::Round(($perfNet.BytesSentPersec) / 1KB, 1))) + " KB/s" } else { "0 KB/s" };

    $nvInfo = GetNvidiaMetrics;
    $vramText = if ($nvInfo.Valid) { ([string]($nvInfo.VramUse)) + "/" + ([string]($nvInfo.VramTot)) + " GB (" + ($nvInfo.GpuTemp) + " " + ($V) + " " + ($nvInfo.GpuPwr) + " " + ($V) + " " + ($nvInfo.PState) + ")" } else { ([string]([math]::Round(($gpus[0].AdapterRAM) / 1GB, 1))) + " GB" };
    $gpuClkText = if ($nvInfo.Valid) { "Core: " + ($nvInfo.GpuClock) + " " + ($V) + " Mem: " + ($nvInfo.MemClock) + " (" + ([string]($nvInfo.GpuLoad)) + "%)" } else { "Dynamic WDDM Clock" };

    $allProcs = [System.Diagnostics.Process]::GetProcesses();
    $runningProcNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase);
    $totHandles = 0;
    $totThreads = 0;
    for ($p = 0; ($p) -lt ($allProcs.Length); $p++) {
        try {
            $null = $runningProcNames.Add(($allProcs[($p)].ProcessName));
            $totHandles += $allProcs[($p)].HandleCount;
            $totThreads += $allProcs[($p)].Threads.Count;
        } catch {}
    }

    $topCpu = [System.Linq.Enumerable]::Take([System.Linq.Enumerable]::OrderByDescending(($allProcs), [Func[System.Diagnostics.Process, double]]{ param($x) try { return $x.TotalProcessorTime.TotalSeconds } catch { return 0.0 } }), 5);
    $topCpuArr = [System.Linq.Enumerable]::ToArray(($topCpu));

    $topRam = [System.Linq.Enumerable]::Take([System.Linq.Enumerable]::OrderByDescending(($allProcs), [Func[System.Diagnostics.Process, long]]{ param($x) try { return $x.WorkingSet64 } catch { return 0L } }), 5);
    $topRamArr = [System.Linq.Enumerable]::ToArray(($topRam));

    $liveVols = @(Get-CimInstance -ClassName:("Win32_LogicalDisk") -Filter:("DriveType=3"));
    $cUse = 0.0; $cTot = 0.0; $cFre = 0.0; $cPct = 0.0;
    $otherVolStr = "None";
    $otherList = [System.Collections.Generic.List[string]]::new();
    for ($lv = 0; ($lv) -lt ($liveVols.Count); $lv++) {
        $vItem = $liveVols[($lv)];
        $vT = [math]::Round(($vItem.Size) / 1GB, 1);
        $vF = [math]::Round(($vItem.FreeSpace) / 1GB, 1);
        $vU = [math]::Round(($vT) - ($vF), 1);
        $vP = if (($vT) -gt 0) { [math]::Round((($vU) / ($vT)) * 100.0, 0) } else { 0 };
        if (($vItem.DeviceID) -eq "C:") {
            $cTot = $vT; $cUse = $vU; $cFre = $vF;
            $cPct = if (($vT) -gt 0) { [math]::Round((($vU) / ($vT)) * 100.0, 1) } else { 0 };
        } else {
            $uInt = [int][math]::Round(($vU));
            $tInt = [int][math]::Round(($vT));
            $otherList.Add((([string]($vItem.DeviceID)) + ([string]($uInt)) + "/" + ([string]($tInt)) + "G(" + ([string]($vP)) + "%)"));
        }
    }
    if (($otherList.Count) -gt 0) { $otherVolStr = [string]::Join(" ", $otherList); }

    $pingMs = GetFastLatency "1.1.1.1";

    $batArr = @(Get-CimInstance -ClassName:("Win32_Battery"));
    $pwrStat = "AC Line Connected";
    if (($batArr.Count) -gt 0) {
        $bCode = [int]($batArr[0].BatteryStatus);
        $bDesc = if (($bCode) -eq 1) { "Discharging" } elseif (($bCode) -eq 2) { "AC Connected" } elseif (($bCode) -eq 3) { "Fully Charged" } else { "Charging" };
        $pwrStat = ([string]($batArr[0].EstimatedChargeRemaining)) + "% (" + ($bDesc) + ")";
    }

    $allTcp  = @(Get-NetTCPConnection -ErrorAction:("SilentlyContinue"));
    $tcpEst  = 0; $tcpList = 0; $tcpWait = 0;
    for ($t = 0; ($t) -lt ($allTcp.Count); $t++) {
        $st = $allTcp[($t)].State;
        if (($st) -eq "Established") { $tcpEst++; }
        elseif (($st) -eq "Listen") { $tcpList++; }
        elseif ((($st) -eq "TimeWait") -or (($st) -eq "CloseWait")) { $tcpWait++; }
    }

    $allSvcs = @(Get-Service -ErrorAction:("SilentlyContinue"));
    $runSvcs = 0;
    for ($s = 0; ($s) -lt ($allSvcs.Count); $s++) {
        if (($allSvcs[($s)].Status) -eq "Running") { $runSvcs++; }
    }

    $cpuLoadInt = [int]($liveCpu.LoadPercentage);
    $cpuGauge   = GetVisualGauge ($cpuLoadInt) 10;
    $ramGauge   = GetVisualGauge ($ramPct) 10;
    $diskGauge  = GetVisualGauge ($cPct) 10;

    $cpuCol = GetLoadColor ($cpuLoadInt);
    $ramCol = GetLoadColor ($ramPct);
    $dskCol = GetLoadColor ($cPct);

    # Column 1 (24 Rows | Width: 48)
    $col1 = @(
        (FormatHeader "OS & KERNEL ENVIRONMENT" 48),
        (FormatKV "OS Edition" ($osClean) 48 ($cWhite)),
        (FormatKV "Build/UEFI" ($osBuildInfo) 48 ($cWhite)),
        (FormatKV "Privilege" ($secRole) 48 ($cYellow)),
        (FormatKV "Host/User" (([string]($compSys.Name)) + " / " + ($env:USERNAME)) 48 ($cWhite)),
        (FormatKV "VBS / HVCI" ($vbsStr) 48 ($cCyan)),
        (FormatHeader "PLATFORM & SMBIOS FIRMWARE" 48),
        (FormatKV "Mainboard" ($moboStr) 48 ($cWhite)),
        (FormatKV "Serial No" ($moboSerial) 48 ($cWhite)),
        (FormatKV "BIOS Ver" ($biosVer) 48 ($cWhite)),
        (FormatKV "Sys Uptime" ($upStr) 48 ($cGreen)),
        (FormatHeader "PROCESSOR & CACHE SUBSYSTEM" 48),
        (FormatKV "CPU Model" ($cpuName) 48 ($cWhite)),
        (FormatKV "Topology" ($cpuSpec) 48 ($cWhite)),
        (FormatKV "Clock Spd" (([string]($cpuCurMhz)) + " MHz Eff / " + ([string]($baseMhz)) + " MHz Base") 48 ($cWhite)),
        (FormatKV "Cache L1-3" ($cpuCache) 48 ($cWhite)),
        (FormatKV "Sys UUID" ($uuidStr) 48 ($cWhite)),
        (FormatHeader "MEMORY & KERNEL POOL ALLOCATION" 48),
        (FormatKV "Phys RAM" (([string]($ramTotalGB)) + "G (" + ([string]($ramUsedGB)) + "G Used / " + ([string]($ramFreeGB)) + "G Free)") 48 ($cWhite)),
        (FormatKV "Commit Mem" (([string]($commitUsedGB)) + "G / " + ([string]($commitTotGB)) + "G (PgFlt: " + ($pageFaults) + ")") 48 ($cWhite)),
        (FormatKV "DIMM Slots" (($ramSlotStr) + " @ " + ($ramSpd)) 48 ($cWhite)),
        (FormatKV "Kernel Pl" ("Paged: " + ($poolPaged) + " " + ($V) + " Non-Paged: " + ($poolNonPaged)) 48 ($cWhite)),
        (FormatKV "Pagefile" ($pfStr) 48 ($cWhite)),
        (FormatKV "Win Svcs" (([string]($runSvcs)) + " Running / " + ([string]($allSvcs.Count)) + " Total Services") 48 ($cGreen))
    );

    # Column 2 (24 Rows | Width: 48)
    $col2 = @(
        (FormatHeader "GRAPHICS & WDDM SUBSYSTEM" 48),
        (FormatKV "Primary" ($gpu0) 48 ($cWhite)),
        (FormatKV "GPU State" ($vramText) 48 ($cGreen)),
        (FormatKV "GPU Clocks" ($gpuClkText) 48 ($cWhite)),
        (FormatKV "Display" (($disp0) + " (" + ($gpu1) + ")") 48 ($cWhite)),
        (FormatKV "WDDM Drv" ($gpuDrv) 48 ($cWhite)),
        (FormatHeader "STORAGE & I/O SUBSYSTEM" 48),
        (FormatKV "Phys Disks" (([string]($drives.Count)) + " Drives (" + ([string]($totStoreGB)) + " GB Total)") 48 ($cWhite)),
        (FormatKV "Volume C" (([string]($cUse)) + " GB / " + ([string]($cTot)) + " GB (" + ([string]($cPct)) + "% Used)") 48 ($cWhite)),
        (FormatKV "Other Vols" ($otherVolStr) 48 ($cWhite)),
        (FormatKV "Disk I/O" ("R: " + ($diskReadKBs) + " " + ($V) + " W: " + ($diskWriteKBs)) 48 ($cWhite)),
        (FormatKV "IOPS/Queue" (($diskIops) + " " + ($V) + " Queue Len: " + ($diskQueue)) 48 ($cWhite)),
        (FormatHeader "NETWORK INTERFACE & ROUTING" 48),
        (FormatKV "Adapter" ($netDesc) 48 ($cWhite)),
        (FormatKV "MAC Addr" ($mac) 48 ($cWhite)),
        (FormatKV "IPv4 / GW" (($ipv4) + " " + ($V) + " GW: " + ($gateway)) 48 ($cWhite)),
        (FormatKV "DNS / Net" (($dns) + " " + ($V) + " RX:" + ($netRxKBs) + " TX:" + ($netTxKBs)) 48 ($cGreen)),
        (FormatKV "Link/Ping" (($linkSpd) + " " + ($V) + " RTT: " + ($pingMs)) 48 ($cWhite)),
        (FormatHeader "RING-0 KERNEL & SOCKET STATE" 48),
        (FormatKV "Kernel Ops" ("CtxSw: " + ($ctxSw) + " " + ($V) + " SysCall: " + ($sysCall)) 48 ($cWhite)),
        (FormatKV "Interrupts" ("HW Int: " + ($intRate) + " " + ($V) + " Kernel PID: 4") 48 ($cWhite)),
        (FormatKV "TCP Active" (([string]($tcpEst)) + " Established " + ($V) + " " + ([string]($tcpList)) + " Listening") 48 ($cWhite)),
        (FormatKV "TCP Wait" (([string]($tcpWait)) + " TimeWait/CloseWait Sockets") 48 ($cWhite)),
        (FormatKV "App Matrix" (([string]($thirdPartyApps.Count)) + " Indexed 3rd-Party Binaries") 48 ($cCyan))
    );

    $c0Time = try { [math]::Round(($topCpuArr[0].TotalProcessorTime.TotalSeconds), 1) } catch { 0 };
    $c1Time = try { [math]::Round(($topCpuArr[1].TotalProcessorTime.TotalSeconds), 1) } catch { 0 };
    $c2Time = try { [math]::Round(($topCpuArr[2].TotalProcessorTime.TotalSeconds), 1) } catch { 0 };
    $c3Time = try { [math]::Round(($topCpuArr[3].TotalProcessorTime.TotalSeconds), 1) } catch { 0 };
    $c4Time = try { [math]::Round(($topCpuArr[4].TotalProcessorTime.TotalSeconds), 1) } catch { 0 };

    $r0Mem = [math]::Round(($topRamArr[0].WorkingSet64) / 1MB);
    $r1Mem = [math]::Round(($topRamArr[1].WorkingSet64) / 1MB);
    $r2Mem = [math]::Round(($topRamArr[2].WorkingSet64) / 1MB);
    $r3Mem = [math]::Round(($topRamArr[3].WorkingSet64) / 1MB);
    $r4Mem = [math]::Round(($topRamArr[4].WorkingSet64) / 1MB);

    # Column 3 (24 Rows | Width: 48)
    $col3 = @(
        (FormatHeader "RESOURCE UTILIZATION & HANDLES" 48),
        (FormatKV "CPU Load" (($cpuGauge) + " " + ([string]($cpuLoadInt)) + "% (" + ([string]($allProcs.Length)) + " Procs)") 48 ($cpuCol)),
        (FormatKV "RAM Load" (($ramGauge) + " " + ([string]($ramPct)) + "% (" + ([string]($ramUsedGB)) + "G Used)") 48 ($ramCol)),
        (FormatKV "Vol C Use" (($diskGauge) + " " + ([string]($cPct)) + "% (" + ([string]($cFre)) + "G Free)") 48 ($dskCol)),
        (FormatKV "Threads" (([string]($totThreads)) + " Active Kernel/User Threads") 48 ($cWhite)),
        (FormatKV "Handles" (([string]($totHandles)) + " Open Object Handles") 48 ($cWhite)),
        (FormatHeader "TOP CPU CONSUMERS (PROCESS / PID / TIME)" 48),
        (FormatProc "1" ($topCpuArr[0].ProcessName) ($topCpuArr[0].Id) (([string]($c0Time)) + " s") 48),
        (FormatProc "2" ($topCpuArr[1].ProcessName) ($topCpuArr[1].Id) (([string]($c1Time)) + " s") 48),
        (FormatProc "3" ($topCpuArr[2].ProcessName) ($topCpuArr[2].Id) (([string]($c2Time)) + " s") 48),
        (FormatProc "4" ($topCpuArr[3].ProcessName) ($topCpuArr[3].Id) (([string]($c3Time)) + " s") 48),
        (FormatProc "5" ($topCpuArr[4].ProcessName) ($topCpuArr[4].Id) (([string]($c4Time)) + " s") 48),
        (FormatHeader "TOP MEMORY CONSUMERS (PROCESS / PID / WS)" 48),
        (FormatProc "1" ($topRamArr[0].ProcessName) ($topRamArr[0].Id) (([string]($r0Mem)) + " MB") 48),
        (FormatProc "2" ($topRamArr[1].ProcessName) ($topRamArr[1].Id) (([string]($r1Mem)) + " MB") 48),
        (FormatProc "3" ($topRamArr[2].ProcessName) ($topRamArr[2].Id) (([string]($r2Mem)) + " MB") 48),
        (FormatProc "4" ($topRamArr[3].ProcessName) ($topRamArr[3].Id) (([string]($r3Mem)) + " MB") 48),
        (FormatProc "5" ($topRamArr[4].ProcessName) ($topRamArr[4].Id) (([string]($r4Mem)) + " MB") 48),
        (FormatHeader "POWER, SECURITY & KERNEL STATE" 48),
        (FormatKV "Power Src" ($pwrStat) 48 ($cGreen)),
        (FormatKV "Security" (($sbEnabled) + " " + ($V) + " Integrity: High") 48 ($cCyan)),
        (FormatKV "Defender" ($avSigStr) 48 ($cWhite)),
        (FormatKV "OS Patches" ($qfeStr) 48 ($cWhite)),
        (FormatKV "System PID" "PID 4 (ntoskrnl.exe - NT Kernel)" 48 ($cWhite))
    );

    $sb = [System.Text.StringBuilder]::new(36864);

    $bannerText = "WINDOWS ENTERPRISE SERVER CONSOLE (WESC) - LIVE TELEMETRY: 3s";
    $bannerFormatted = FitPlain (($bannerText.PadLeft(76 + [int](($bannerText.Length) / 2)))) 152;

    $null = $sb.AppendLine((($cCyan) + ($boxBorder) + ($cReset)));
    $null = $sb.AppendLine((($cCyan) + ($V) + ($cReset) + ($cWhite) + ($bannerFormatted) + ($cReset) + ($cCyan) + ($V) + ($cReset)));
    $null = $sb.AppendLine((($cCyan) + ($boxBorder) + ($cReset)));

    for ($idx = 0; ($idx) -lt 24; $idx++) {
        $rowLine = ($cCyan) + ($V) + ($cReset) + " " + ($col1[($idx)]) + " " + ($cGray) + ($V) + ($cReset) + " " + ($col2[($idx)]) + " " + ($cGray) + ($V) + ($cReset) + " " + ($col3[($idx)]) + " " + ($cCyan) + ($V) + ($cReset);
        $null = $sb.AppendLine(($rowLine));
    }

    $null = $sb.AppendLine((($cGray) + ($boxBorder) + ($cReset)));
    $evBanner = FitPlain " [ SYSTEM EVENT LOG STREAM : CRITICAL / ERROR / WARNING ]" 152;
    $null = $sb.AppendLine((($cCyan) + ($V) + ($cReset) + ($cYellow) + ($evBanner) + ($cReset) + ($cCyan) + ($V) + ($cReset)));

    $liveEvents = @(Get-WinEvent -FilterHashtable:@{LogName='System'; Level=1,2,3} -MaxEvents:(4) -ErrorAction:("SilentlyContinue"));

    if (($liveEvents.Count) -gt 0) {
        for ($eIdx = 0; ($eIdx) -lt ($liveEvents.Count); $eIdx++) {
            $ev = $liveEvents[($eIdx)];
            $evTime = "[" + ($ev.TimeCreated.ToString("HH:mm:ss")) + "]";
            $evLevelStr = "[INFO ] ";
            $evColor = ($cGray);
            if (($ev.Level) -eq 1) { $evLevelStr = "[CRIT ] "; $evColor = ($cRed); }
            elseif (($ev.Level) -eq 2) { $evLevelStr = "[ERROR] "; $evColor = ($cRed); }
            elseif (($ev.Level) -eq 3) { $evLevelStr = "[WARN ] "; $evColor = ($cYellow); }

            $evId = FitPlain ("ID:" + ([string]($ev.Id))) 9;
            $evSrc = [string]($ev.ProviderName);
            if (($evSrc.Length) -gt 28) { $evSrc = ($evSrc.Substring(0, 26)) + ".."; }
            $evSrcPadded = FitPlain ($evSrc) 28;

            $rawMsg = ([string]($ev.Message)).Replace(($NL), " ").Replace("`r", " ").Replace("`n", " ").Trim();
            if (($rawMsg.Length) -gt 90) { $rawMsg = ($rawMsg.Substring(0, 88)) + ".."; }
            $evMsgPadded = FitPlain ($rawMsg) 91;

            $evLine = ($cCyan) + ($V) + ($cReset) + " " + ($cCyan) + ($evTime) + ($cReset) + " " + ($evColor) + ($evLevelStr) + ($cReset) + ($cCyan) + ($evId) + ($cReset) + " " + ($cWhite) + ($evSrcPadded) + ($cReset) + " " + ($cGray) + ($V) + ($cReset) + " " + ($cWhite) + ($evMsgPadded) + ($cReset) + ($cCyan) + ($V) + ($cReset);
            $null = $sb.AppendLine(($evLine));
        }
    } else {
        $cleanMsg = FitPlain " [00:00:00] [OK] No recent critical, error, or warning events in System log." 152;
        $null = $sb.AppendLine((($cCyan) + ($V) + ($cReset) + ($cGreen) + ($cleanMsg) + ($cReset) + ($cCyan) + ($V) + ($cReset)));
    }

    $totalApps  = $thirdPartyApps.Count;
    $totalPages = [math]::Max(1, [int][math]::Ceiling(($totalApps) / 12.0));
    if (($currentPage) -ge ($totalPages)) { $currentPage = 0; }

    for ($aIdx = 0; ($aIdx) -lt ($totalApps); $aIdx++) {
        $appItem = $thirdPartyApps[($aIdx)];
        $isRun   = $runningProcNames.Contains(([string]($appItem["ProcessName"])));
        $appItem["CurrentStatus"] = if ($isRun) { "RUNNING" } else { "STOPPED" };
        $appItem["StatusColor"]   = if ($isRun) { ($cGreen) } else { ($cGray) };
    }

    $null = $sb.AppendLine((($cGray) + ($boxBorder) + ($cReset)));
    $appHdrStr = " [ DISCOVERED 3RD-PARTY APPLICATIONS (PAGE " + ([string](($currentPage) + 1)) + "/" + ([string]($totalPages)) + " - TOTAL: " + ([string]($totalApps)) + " BINARIES) ]";
    $appBanner = FitPlain ($appHdrStr) 152;
    $null = $sb.AppendLine((($cCyan) + ($V) + ($cReset) + ($cYellow) + ($appBanner) + ($cReset) + ($cCyan) + ($V) + ($cReset)));

    $pageStart = ($currentPage) * 12;
    for ($row = 0; ($row) -lt 4; $row++) {
        $idx1 = ($pageStart) + ($row);
        $idx2 = ($pageStart) + ($row) + 4;
        $idx3 = ($pageStart) + ($row) + 8;

        $cell1 = "".PadRight(48);
        if (($idx1) -lt ($totalApps)) {
            $a1 = $thirdPartyApps[($idx1)];
            $n1 = [string]($a1["Name"]);
            if (($n1.Length) -gt 26) { $n1 = ($n1.Substring(0, 24)) + ".."; }
            $lbl1 = FitPlain ("[" + ($a1["ID"]) + "] " + ($n1)) 32;
            $st1  = FitPlain ("State: " + ($a1["CurrentStatus"])) 15;
            $cell1 = ($cWhite) + ($lbl1) + ($cReset) + " " + ($a1["StatusColor"]) + ($st1) + ($cReset);
        }

        $cell2 = "".PadRight(48);
        if (($idx2) -lt ($totalApps)) {
            $a2 = $thirdPartyApps[($idx2)];
            $n2 = [string]($a2["Name"]);
            if (($n2.Length) -gt 26) { $n2 = ($n2.Substring(0, 24)) + ".."; }
            $lbl2 = FitPlain ("[" + ($a2["ID"]) + "] " + ($n2)) 32;
            $st2  = FitPlain ("State: " + ($a2["CurrentStatus"])) 15;
            $cell2 = ($cWhite) + ($lbl2) + ($cReset) + " " + ($a2["StatusColor"]) + ($st2) + ($cReset);
        }

        $cell3 = "".PadRight(48);
        if (($idx3) -lt ($totalApps)) {
            $a3 = $thirdPartyApps[($idx3)];
            $n3 = [string]($a3["Name"]);
            if (($n3.Length) -gt 26) { $n3 = ($n3.Substring(0, 24)) + ".."; }
            $lbl3 = FitPlain ("[" + ($a3["ID"]) + "] " + ($n3)) 32;
            $st3  = FitPlain ("State: " + ($a3["CurrentStatus"])) 15;
            $cell3 = ($cWhite) + ($lbl3) + ($cReset) + " " + ($a3["StatusColor"]) + ($st3) + ($cReset);
        }

        $appRow = ($cCyan) + ($V) + ($cReset) + " " + ($cell1) + " " + ($cGray) + ($V) + ($cReset) + " " + ($cell2) + " " + ($cGray) + ($V) + ($cReset) + " " + ($cell3) + " " + ($cCyan) + ($V) + ($cReset);
        $null = $sb.AppendLine(($appRow));
    }

    # ==============================================================================
    # STRICT 6-SUBCOLUMN SYMMETRIC COMMAND MATRIX (6 ROWS x 6 SUBCOLUMNS = 36 OPS)
    # ==============================================================================
    $null = $sb.AppendLine((($cGray) + ($boxBorder) + ($cReset)));

    $mR1C1 = FormatCmdPair "[ID#] Launch App"      "[P] Next App Page"      ($cWhite)   ($cWhite);
    $mR1C2 = FormatCmdPair "[R] Rescan Apps"       "[S] Deep App Search"    ($cWhite)   ($cWhite);
    $mR1C3 = FormatCmdPair "[Z] Gaming/WS Boost"   "[M] Optimize RAM"       ($cGreen)   ($cGreen);

    $mR2C1 = FormatCmdPair "[G] GPU & Power Mode"  "[A] Battery & Thermals" ($cCyan)    ($cCyan);
    $mR2C2 = FormatCmdPair "[I] DNS & Ping Matrix" "[V] Security & Ports"   ($cCyan)    ($cCyan);
    $mR2C3 = FormatCmdPair "[H] Disk SMART Health" "[U] Startup Auditor"    ($cCyan)    ($cCyan);

    $mR3C1 = FormatCmdPair "[L] 24h Event Audit"   "[D] Volume Inventory"   ($cYellow)  ($cYellow);
    $mR3C2 = FormatCmdPair "[W] Service Auditor"   "[N] Active TCP Sockets" ($cYellow)  ($cYellow);
    $mR3C3 = FormatCmdPair "[X] Kernel Drv Audit"  "[B] System Benchmark"   ($cYellow)  ($cYellow);

    $mR4C1 = FormatCmdPair "[O] Process DLL Audit" "[J] Scheduled Tasks"    ($cMagenta) ($cMagenta);
    $mR4C2 = FormatCmdPair "[FI] SHA256 & Signer"  "[HO] ARP & Hosts Audit" ($cMagenta) ($cMagenta);
    $mR4C3 = FormatCmdPair "[SH] SMB Share Audit"  "[US] User & Token Priv" ($cMagenta) ($cMagenta);

    $mR5C1 = FormatCmdPair "[FW] Firewall Rules"   "[WU] QFE Hotfix Audit"  ($cCyan)    ($cCyan);
    $mR5C2 = FormatCmdPair "[BC] UEFI & BCD Store" "[PE] PCIe & USB Buses"  ($cCyan)    ($cCyan);
    $mR5C3 = FormatCmdPair "[K] Terminate PID"     "[E] Export Audit Log"   ($cWhite)   ($cWhite);

    $mR6C1 = FormatCmdPair "[F] Flush DNS Cache"   "[C] Purge Temp Cache"   ($cWhite)   ($cWhite);
    $mR6C2 = FormatCmdPair "[T] Task Manager"      "[Y] Resource Monitor"   ($cWhite)   ($cWhite);
    $mR6C3 = FormatCmdPair "[EV] Event Viewer GUI" "[Q] Exit Console"       ($cWhite)   ($cRed);

    $cmdLine1 = ($cCyan) + ($V) + ($cReset) + " " + ($mR1C1) + " " + ($cGray) + ($V) + ($cReset) + " " + ($mR1C2) + " " + ($cGray) + ($V) + ($cReset) + " " + ($mR1C3) + " " + ($cCyan) + ($V) + ($cReset);
    $cmdLine2 = ($cCyan) + ($V) + ($cReset) + " " + ($mR2C1) + " " + ($cGray) + ($V) + ($cReset) + " " + ($mR2C2) + " " + ($cGray) + ($V) + ($cReset) + " " + ($mR2C3) + " " + ($cCyan) + ($V) + ($cReset);
    $cmdLine3 = ($cCyan) + ($V) + ($cReset) + " " + ($mR3C1) + " " + ($cGray) + ($V) + ($cReset) + " " + ($mR3C2) + " " + ($cGray) + ($V) + ($cReset) + " " + ($mR3C3) + " " + ($cCyan) + ($V) + ($cReset);
    $cmdLine4 = ($cCyan) + ($V) + ($cReset) + " " + ($mR4C1) + " " + ($cGray) + ($V) + ($cReset) + " " + ($mR4C2) + " " + ($cGray) + ($V) + ($cReset) + " " + ($mR4C3) + " " + ($cCyan) + ($V) + ($cReset);
    $cmdLine5 = ($cCyan) + ($V) + ($cReset) + " " + ($mR5C1) + " " + ($cGray) + ($V) + ($cReset) + " " + ($mR5C2) + " " + ($cGray) + ($V) + ($cReset) + " " + ($mR5C3) + " " + ($cCyan) + ($V) + ($cReset);
    $cmdLine6 = ($cCyan) + ($V) + ($cReset) + " " + ($mR6C1) + " " + ($cGray) + ($V) + ($cReset) + " " + ($mR6C2) + " " + ($cGray) + ($V) + ($cReset) + " " + ($mR6C3) + " " + ($cCyan) + ($V) + ($cReset);

    $null = $sb.AppendLine(($cmdLine1));
    $null = $sb.AppendLine(($cmdLine2));
    $null = $sb.AppendLine(($cmdLine3));
    $null = $sb.AppendLine(($cmdLine4));
    $null = $sb.AppendLine(($cmdLine5));
    $null = $sb.AppendLine(($cmdLine6));
    $null = $sb.AppendLine((($cCyan) + ($boxBorder) + ($cReset)));
    $null = $sb.AppendLine((($cGray) + "[ TELEMETRY ENGINE ACTIVE " + ($V) + " PRESS ANY KEY TO OPEN COMMAND PROMPT ]" + ($cReset)));

    try { [System.Console]::SetCursorPosition(0, 0); } catch {};
    [System.Console]::Write(($sb.ToString()));

    $timer = 30;
    $action = $null;

    while (($timer) -gt 0) {
        if ([System.Console]::KeyAvailable) {
            $null = [System.Console]::ReadKey($true);
            try { [System.Console]::CursorVisible = $true; } catch {};
            [System.Console]::Write((($NL) + ($cYellow) + "Command> " + ($cReset)));
            $action = Read-Host;
            $isFirstRun = $true;
            try { [System.Console]::CursorVisible = $false; } catch {};
            break;
        }
        [System.Threading.Thread]::Sleep(100);
        $timer--;
    }

    if ($action) {
        $cmd = ($action.Trim()).ToUpper();
        if (($cmd) -eq "Q") { $exitDashboard = $true; }
        elseif (($cmd) -eq "P") { $currentPage = (($currentPage) + 1) % ($totalPages); }
        elseif (($cmd) -eq "R") {
            [System.Console]::WriteLine((($cCyan) + "[SYSTEM] Rescanning installed 3rd-party applications across drives..." + ($cReset)));
            $thirdPartyApps = DiscoverThirdPartyApps;
            $currentPage = 0;
        }
        elseif (($cmd) -eq "FI") { InvokeAuthenticodeVerifier; }
        elseif (($cmd) -eq "HO") { InvokeArpHostsAuditor; }
        elseif (($cmd) -eq "SH") { InvokeSmbShareAuditor; }
        elseif (($cmd) -eq "US") { InvokeUserSessionAuditor; }
        elseif (($cmd) -eq "FW") { InvokeFirewallAuditor; }
        elseif (($cmd) -eq "WU") { InvokeHotfixAuditor; }
        elseif (($cmd) -eq "BC") { InvokeBcdBootAuditor; }
        elseif (($cmd) -eq "PE") { InvokePcieBusInspector; }
        elseif (($cmd) -eq "O")  { InvokeProcessModulesInspector; }
        elseif (($cmd) -eq "J")  { InvokeScheduledTasksAuditor; }
        elseif (($cmd) -eq "X")  { InvokeDriverDeviceAuditor; }
        elseif (($cmd) -eq "Z")  { InvokeWorkstationBoost; }
        elseif (($cmd) -eq "I")  { InvokeDnsLatencyMatrix; }
        elseif (($cmd) -eq "V")  { InvokeSecurityPortAuditor; }
        elseif (($cmd) -eq "A")  { InvokeBatteryThermalReport; }
        elseif (($cmd) -eq "M")  { InvokeMemoryOptimizer; }
        elseif (($cmd) -eq "G")  { InvokeGpuPowerController; }
        elseif (($cmd) -eq "H")  { InvokeSmartHealth; }
        elseif (($cmd) -eq "U")  { InvokeStartupAudit; }
        elseif (($cmd) -eq "S")  { InvokeExecutableInventory; }
        elseif (($cmd) -eq "K")  { InvokeProcessTermination; }
        elseif (($cmd) -eq "F")  { InvokeNetworkFlush; }
        elseif (($cmd) -eq "C")  { InvokeTempClean; }
        elseif (($cmd) -eq "L")  { InvokeLogAudit; }
        elseif (($cmd) -eq "D")  { InvokeDiskInspector; }
        elseif (($cmd) -eq "B")  { InvokeSystemBenchmark; }
        elseif (($cmd) -eq "N")  { InvokeSocketInspector; }
        elseif (($cmd) -eq "W")  { InvokeServiceAudit; }
        elseif (($cmd) -eq "E")  { InvokeExportReport; }
        elseif (($cmd) -eq "T")  { Start-Process -FilePath:("taskmgr.exe"); }
        elseif (($cmd) -eq "Y")  { Start-Process -FilePath:("resmon.exe"); }
        elseif (($cmd) -eq "EV") { Start-Process -FilePath:("eventvwr.msc"); }
        else {
            $choices = $cmd.Split(" ");
            for ($cIdx = 0; ($cIdx) -lt ($choices.Length); $cIdx++) {
                $ch = ($choices[($cIdx)]).Trim();
                for ($pIdx = 0; ($pIdx) -lt ($thirdPartyApps.Count); $pIdx++) {
                    $selApp = $thirdPartyApps[($pIdx)];
                    if (($selApp["ID"]) -eq ($ch)) {
                        Start-Process -FilePath:($selApp["Path"]);
                        [System.Console]::WriteLine((($cGreen) + "[+] Launched: " + ($selApp["Name"]) + ($cReset)));
                        [System.Threading.Thread]::Sleep(1000);
                    }
                }
            }
        }
    }
}

try { [System.Console]::CursorVisible = $true; } catch {};
[System.Console]::Clear();
[System.Console]::WriteLine((($cGreen) + "WESC Server Console Session Terminated." + ($cReset)));

# [WESC_TITLE_RESTORE] Restore normal PowerShell 7 window title upon exit
try {
    $ isAdm = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $Host.UI.RawUI.WindowTitle = if ($isAdm) { "Administrator: PowerShell " + $PSVersionTable.PSVersion.ToString() } else { "PowerShell " + $PSVersionTable.PSVersion.ToString() }
} catch {}
