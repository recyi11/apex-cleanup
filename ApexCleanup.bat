@echo off
setlocal

set "APEX_CLEANUP_BAT=%~f0"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator rights...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:APEX_CLEANUP_BAT -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$script = Get-Content -LiteralPath $env:APEX_CLEANUP_BAT -Raw; Invoke-Expression ([regex]::Split($script, '(?m)^:# POWERSHELL #\r?$', 2)[1])"
set "EXITCODE=%errorlevel%"
echo.
pause
exit /b %EXITCODE%

:# POWERSHELL #
$ErrorActionPreference = "Continue"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-ClientPaths {
    param([string[]]$Names)

    $paths = @()
    foreach ($name in $Names) {
        $paths += Get-Process -Name $name -ErrorAction SilentlyContinue |
            Where-Object { $_.Path -and $_.Path -notmatch "\\compatibility32\\" } |
            Select-Object -ExpandProperty Path
    }

    $paths | Select-Object -Unique
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

function Get-BlockingLeftovers {
    Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -match "^(r5apex|r5apex_dx12|EasyAntiCheat|EasyAntiCheat_EOS|EAAntiCheat)$"
    }
}

Write-Host "Apex cleanup tool"
Write-Host "This closes stuck Apex, EA App, Steam, and anti-cheat leftovers. It does not bypass anti-cheat."

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
$leftovers = @(Get-BlockingLeftovers)
if ($leftovers.Count -eq 0) {
    Write-Host "Done. Apex and anti-cheat leftovers are closed." -ForegroundColor Green
    exit 0
}

$leftovers | Select-Object Id, ProcessName, Responding, Path | Format-Table -AutoSize
Write-Host ""
Write-Host "Some Apex / anti-cheat entries are still visible." -ForegroundColor Yellow
Write-Host "If taskkill says there is no running instance, Windows is holding a dead process object."
Write-Host "That state is normally cleared by restarting Windows."
exit 2
