<#
    .SYNOPSIS
        Shows the health status of all running Sitecore containers.

    .DESCRIPTION
        Queries 'docker compose ps' and displays a per-container health summary.
        By default it runs once and exits. Use -Watch to poll continuously until
        all containers are healthy or the timeout is reached.

    .PARAMETER Watch
        Polls every 5 seconds until all containers report a healthy or running
        state, or until -TimeoutSeconds is exceeded.

    .PARAMETER TimeoutSeconds
        Maximum time in seconds to wait when -Watch is specified. Defaults to 600.

    .PARAMETER IncludeSpe
        Must match the flags used when up.ps1 was called.

    .PARAMETER IncludeSxa
        Must match the flags used when up.ps1 was called.
#>
[CmdletBinding()]
param(
    [switch]$Watch,
    [int]$TimeoutSeconds = 600,
    [switch]$IncludeSpe,
    [switch]$IncludeSxa
)

$composeArgs = @("compose", "-f", ".\docker-compose.yml")

if (Test-Path -Path (Join-Path $PSScriptRoot "docker-compose.override.yml")) {
    $composeArgs += "-f", ".\docker-compose.override.yml"
}
if ($IncludeSpe -or $IncludeSxa) {
    $composeArgs += "-f", ".\docker-compose.spe.yml"
}
if ($IncludeSxa) {
    $composeArgs += "-f", ".\docker-compose.sxa.yml"
}

function Write-StatusTable {
    $rows = docker $composeArgs ps --format json 2>$null | ForEach-Object { $_ | ConvertFrom-Json }

    if (-not $rows) {
        Write-Host "No containers found. Has up.ps1 been run?" -ForegroundColor Yellow
        return $false
    }

    $allHealthy = $true
    $width = ($rows | ForEach-Object { $_.Service.Length } | Measure-Object -Maximum).Maximum + 2

    Write-Host ""
    Write-Host ("{0,-$width} {1,-12} {2}" -f "Service", "State", "Health") -ForegroundColor White
    Write-Host ("-" * 60) -ForegroundColor DarkGray

    foreach ($row in $rows | Sort-Object Service) {
        $health = if ($row.Health) { $row.Health } else { "-" }
        $state  = $row.State

        $colour = switch ($health) {
            "healthy"  { "Green" }
            "starting" { "Yellow" }
            "unhealthy" { "Red" }
            default {
                switch ($state) {
                    "running"  { "Green" }
                    "exited"   { "Red" }
                    default    { "Yellow" }
                }
            }
        }

        Write-Host ("{0,-$width} {1,-12} {2}" -f $row.Service, $state, $health) -ForegroundColor $colour

        if ($health -notin @("healthy", "-") -or $state -notin @("running", "exited")) {
            $allHealthy = $false
        }
        if ($state -eq "exited") { $allHealthy = $false }
    }

    Write-Host ""
    return $allHealthy
}

if (-not $Watch) {
    Write-StatusTable | Out-Null
    exit 0
}

$start = Get-Date
Write-Host "Watching container health (Ctrl+C to stop, timeout ${TimeoutSeconds}s)..." -ForegroundColor Cyan

do {
    $elapsed = [int]((Get-Date) - $start).TotalSeconds
    Write-Host "[$($elapsed)s] $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor DarkGray
    $done = Write-StatusTable

    if ($done) {
        Write-Host "All containers healthy." -ForegroundColor Green
        exit 0
    }

    Start-Sleep -Seconds 5
} while ($start.AddSeconds($TimeoutSeconds) -gt (Get-Date))

Write-Host "Timed out after ${TimeoutSeconds}s waiting for all containers to become healthy." -ForegroundColor Red
exit 1
