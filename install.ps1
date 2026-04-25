<#
  pulseboard-desktop - one-shot Windows installer
  Usage:  Run from an ELEVATED (Admin) PowerShell:
          .\install.ps1
  What it does:
    1. winget install: Ookla Speedtest CLI, Wireshark, Sysinternals (PsTools)
    2. Manual download + extract: iperf3 (ar51an Win build) -> C:\iperf3\
    3. Manual download + run: Npcap installer (with WinPcap-compat flag)
    4. Verifies each tool with --version / -D / equivalent
    5. Prints next-step: "now run .\diag.ps1 -PreflightOnly -Tag smoke"
  Idempotent: skips anything that's already installed.
#>
[CmdletBinding()]
param(
  [string]$Iperf3Url   = "https://github.com/ar51an/iperf3-win-builds/releases/latest/download/iperf3.18_win64.zip",
  [string]$Iperf3Dest  = "C:\iperf3",
  [string]$NpcapUrl    = "https://npcap.com/dist/npcap-1.79.exe",
  [string]$NpcapTmp    = "$env:TEMP\npcap-installer.exe"
)

$ErrorActionPreference = "Stop"

function Test-IsAdmin {
  $user = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($user)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Step { param($Msg) Write-Host "[*] $Msg" -ForegroundColor Cyan }
function Write-OK   { param($Msg) Write-Host "[OK] $Msg" -ForegroundColor Green }
function Write-Skip { param($Msg) Write-Host "[--] $Msg" -ForegroundColor DarkGray }
function Write-Warn { param($Msg) Write-Host "[!!] $Msg" -ForegroundColor Yellow }

if (-not (Test-IsAdmin)) {
  Write-Warn "This installer must be run as Administrator (Npcap requires it)."
  Write-Warn "Right-click PowerShell -> Run as administrator, then re-run install.ps1."
  exit 1
}

Write-Host ""
Write-Host "=== pulseboard-desktop installer ===" -ForegroundColor White
Write-Host ""

# ---- 1. winget packages --------------------------------------------------
$wingetPackages = @(
  @{ Id="Ookla.Speedtest.CLI";           Name="Ookla Speedtest CLI" },
  @{ Id="WiresharkFoundation.Wireshark"; Name="Wireshark (provides tshark.exe)" },
  @{ Id="Microsoft.Sysinternals.PsTools";Name="Sysinternals PsTools (PsPing etc)" }
)

foreach ($pkg in $wingetPackages) {
  Write-Step "winget install $($pkg.Id) ($($pkg.Name))"
  $check = winget list --id $pkg.Id -e 2>&1
  if ($LASTEXITCODE -eq 0 -and $check -match $pkg.Id) {
    Write-Skip "Already installed: $($pkg.Name)"
  } else {
    & winget install --id $pkg.Id -e --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -eq 0) { Write-OK "Installed $($pkg.Name)" }
    else { Write-Warn "winget install failed for $($pkg.Id) (exit $LASTEXITCODE) - install manually if needed" }
  }
  Write-Host ""
}

# ---- 2. iperf3 (manual download from ar51an) -----------------------------
Write-Step "iperf3 (ar51an Windows build) -> $Iperf3Dest"
if (Test-Path "$Iperf3Dest\iperf3.exe") {
  Write-Skip "Already present at $Iperf3Dest\iperf3.exe"
} else {
  New-Item -ItemType Directory -Force -Path $Iperf3Dest | Out-Null
  $tmp = "$env:TEMP\iperf3.zip"
  Write-Host "    Downloading $Iperf3Url ..."
  try {
    Invoke-WebRequest -Uri $Iperf3Url -OutFile $tmp -UseBasicParsing
  } catch {
    Write-Warn "iperf3 download failed: $_"
    Write-Warn "Manual fallback: download a Windows build from https://github.com/ar51an/iperf3-win-builds/releases/latest"
    Write-Warn "Extract iperf3.exe + cygwin1.dll to $Iperf3Dest"
  }
  if (Test-Path $tmp) {
    Expand-Archive -Path $tmp -DestinationPath $Iperf3Dest -Force
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    if (Test-Path "$Iperf3Dest\iperf3.exe") {
      Write-OK "iperf3 extracted to $Iperf3Dest"
    } else {
      # Some zips have a nested folder - flatten if so
      $nested = Get-ChildItem $Iperf3Dest -Recurse -Filter "iperf3.exe" | Select-Object -First 1
      if ($nested) {
        Get-ChildItem $nested.Directory | Move-Item -Destination $Iperf3Dest -Force
        Write-OK "iperf3 extracted (flattened nested folder)"
      } else {
        Write-Warn "Couldn't find iperf3.exe after extraction. Check $Iperf3Dest manually."
      }
    }
  }
}
# Add to PATH for current user (idempotent)
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$Iperf3Dest*") {
  [Environment]::SetEnvironmentVariable("Path", "$userPath;$Iperf3Dest", "User")
  $env:Path = "$env:Path;$Iperf3Dest"
  Write-OK "Added $Iperf3Dest to user PATH (effective in new PowerShell windows)"
}
Write-Host ""

# ---- 3. Npcap (manual download + GUI installer) --------------------------
Write-Step "Npcap (Wireshark capture driver)"
$svc = Get-Service -Name npcap -EA SilentlyContinue
if ($svc) {
  Write-Skip "Npcap service already present (status=$($svc.Status))"
  if ($svc.Status -ne "Running") {
    Start-Service -Name npcap -EA SilentlyContinue
    Write-OK "Started Npcap service"
  }
} else {
  Write-Host "    Downloading $NpcapUrl ..."
  try {
    Invoke-WebRequest -Uri $NpcapUrl -OutFile $NpcapTmp -UseBasicParsing
    Write-OK "Downloaded Npcap installer to $NpcapTmp"
    Write-Warn ""
    Write-Warn "Npcap requires a few clicks in its installer GUI. Launching now..."
    Write-Warn "  IMPORTANT: in the installer, check both:"
    Write-Warn "    [x] Install Npcap in WinPcap API-compatible Mode"
    Write-Warn "    [x] Support raw 802.11 traffic (optional but useful)"
    Write-Warn ""
    Read-Host "Press Enter to launch the Npcap installer"
    Start-Process -FilePath $NpcapTmp -Wait
    $svc2 = Get-Service -Name npcap -EA SilentlyContinue
    if ($svc2 -and $svc2.Status -eq "Running") { Write-OK "Npcap installed and running" }
    else { Write-Warn "Npcap installer finished but the npcap service is not running. Re-check the installer choices." }
  } catch {
    Write-Warn "Npcap download/install failed: $_"
    Write-Warn "Manual fallback: download from https://npcap.com/ and run the installer."
  }
}
Write-Host ""

# ---- 4. Verification -----------------------------------------------------
Write-Step "Verifying installations"
$verifyOk = $true
function Test-Tool {
  param($Name, $TestCmd)
  try {
    $null = & cmd /c "$TestCmd" 2>&1
    if ($LASTEXITCODE -eq 0) { Write-OK "$Name -> OK"; return $true }
    else { Write-Warn "$Name -> failed ($LASTEXITCODE)"; return $false }
  } catch {
    Write-Warn "$Name -> not found ($_)"
    return $false
  }
}

$verifyOk = (Test-Tool "speedtest" "speedtest --version") -and $verifyOk
$verifyOk = (Test-Tool "iperf3"    "$Iperf3Dest\iperf3.exe --version") -and $verifyOk
$tsharkPath = "C:\Program Files\Wireshark\tshark.exe"
if (Test-Path $tsharkPath) { Write-OK "tshark -> $tsharkPath" } else { Write-Warn "tshark not at default path"; $verifyOk = $false }
$verifyOk = (Test-Tool "pathping" "pathping -h 2 1.1.1.1 > nul") -and $verifyOk

Write-Host ""
if ($verifyOk) {
  Write-Host "=== All tools verified. ===" -ForegroundColor Green
  Write-Host ""
  Write-Host "Next step: run a 3-5 min preflight smoke test:"
  Write-Host "  .\diag.ps1 -PreflightOnly -Tag smoke" -ForegroundColor White
  Write-Host ""
  Write-Host "Then read PREFLIGHT.txt in the output folder."
} else {
  Write-Host "=== Some tools failed verification. See warnings above. ===" -ForegroundColor Yellow
  Write-Host "After fixing, re-run install.ps1 (it's idempotent)."
}
