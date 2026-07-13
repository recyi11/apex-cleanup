param(
    [switch]$RestartIfStuck
)

$ErrorActionPreference = "Continue"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Stop-ByName {
    param(
        [string[]]$Names,
        [string]$Label
    )

    Write-Step "Closing $Label"
    foreach ($name in $Names) {
        $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
        foreach ($proc in $procs) {
            Write-Host "Stopping $($proc.ProcessName) pid=$($proc.Id)"
            try {
                Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            } catch {
                Write-Host "Stop-Process failed for pid=$($proc.Id): $($_.Exception.Message)" -ForegroundColor Yellow
                & taskkill.exe /PID $proc.Id /T /F | Out-Host
            }

            Start-Sleep -Milliseconds 300
            if (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue) {
                Write-Host "Process pid=$($proc.Id) is still visible; trying taskkill."
                & taskkill.exe /PID $proc.Id /T /F | Out-Host
            }
        }
    }
}

function Stop-ServiceIfRunning {
    param([string[]]$Patterns)

    Write-Step "Stopping anti-cheat services if they are still running"
    $services = Get-Service -ErrorAction SilentlyContinue | Where-Object {
        $service = $_
        $Patterns | Where-Object {
            $service.Name -like $_ -or $service.DisplayName -like $_
        }
    }

    foreach ($svc in $services) {
        Write-Host "$($svc.DisplayName) [$($svc.Name)] is $($svc.Status)"
        if ($svc.Status -eq "Running") {
            try {
                Stop-Service -Name $svc.Name -Force -ErrorAction Stop
            } catch {
                Write-Host "Could not stop service $($svc.Name): $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
}

function Get-ClientPaths {
    param([string[]]$Names)

    $paths = @()
    foreach ($name in $Names) {
        $paths += Get-Process -Name $name -ErrorAction SilentlyContinue |
            Where-Object { $_.Path } |
            Select-Object -ExpandProperty Path
    }

    $paths | Select-Object -Unique
}

function Start-Clients {
    param(
        [string[]]$Paths,
        [string]$Label
    )

    if (-not $Paths -or $Paths.Count -eq 0) {
        return
    }

    Write-Step "Restarting $Label"
    foreach ($path in ($Paths | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $path) {
            Write-Host "Starting $path"
            try {
                Start-Process -FilePath $path
            } catch {
                Write-Host "Could not start ${path}: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "Skipped missing client path: $path" -ForegroundColor Yellow
        }
    }
}

function Get-ApexLeftovers {
    Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -match "^(r5apex|r5apex_dx12|EasyAntiCheat|EasyAntiCheat_EOS|EAAntiCheat|EACefSubProcess|EADesktop|steam|steamwebhelper|GameOverlayUI)$"
    }
}

if (-not (Test-Admin)) {
    Write-Host "This tool needs Administrator rights to close stuck Apex / anti-cheat processes."
    Write-Host "Right-click apex-cleanup.cmd and choose Run as administrator."
    exit 1
}

Write-Host "Apex cleanup tool"
Write-Host "This only closes stuck game, EA App, and anti-cheat leftovers. It does not bypass anti-cheat."

$eaClientPaths = @(Get-ClientPaths -Names @("EADesktop", "EALauncher"))
$steamClientPaths = @(Get-ClientPaths -Names @("steam"))

Stop-ByName -Names @("r5apex", "r5apex_dx12") -Label "Apex"
Start-Sleep -Seconds 1

Stop-ByName -Names @("EADesktop", "EALauncher", "EABackgroundService", "EACefSubProcess") -Label "EA App leftovers"
Start-Sleep -Seconds 1

Stop-ByName -Names @("steam", "steamwebhelper", "GameOverlayUI") -Label "Steam leftovers"
Start-Sleep -Seconds 1

Stop-ByName -Names @("EasyAntiCheat", "EasyAntiCheat_EOS", "EAAntiCheat.GameServiceLauncher", "EAAntiCheat.Installer") -Label "anti-cheat process leftovers"
Stop-ServiceIfRunning -Patterns @("*EasyAntiCheat*", "*Easy Anti-Cheat*", "*EAAntiCheat*", "*EA Anti*")

Start-Clients -Paths $steamClientPaths -Label "Steam"
Start-Clients -Paths $eaClientPaths -Label "EA App"

Write-Step "Final check"
$leftovers = @(Get-ApexLeftovers)
if ($leftovers.Count -eq 0) {
    Write-Host "Done. Apex / EA / anti-cheat leftovers are closed." -ForegroundColor Green
    exit 0
}

$leftovers | Select-Object Id, ProcessName, Responding, Path | Format-Table -AutoSize
Write-Host ""
Write-Host "Some entries are still visible. If taskkill says there is no running instance, Windows is holding a dead process object." -ForegroundColor Yellow
Write-Host "That state is normally cleared by a reboot."

if ($RestartIfStuck) {
    Write-Host "RestartIfStuck was set; restarting in 15 seconds. Press Ctrl+C to cancel." -ForegroundColor Yellow
    shutdown.exe /r /t 15 /c "Restarting to clear stuck Apex / anti-cheat process"
} else {
    Write-Host "Run this to reboot automatically if leftovers remain:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\apex-cleanup.ps1 -RestartIfStuck"
}

exit 2
