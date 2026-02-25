<#
    .SYNOPSIS
        Builds images and starts the Sitecore Docker environment.

    .PARAMETER SkipBuild
        Specifies that the images should not be built prior to starting up.

    .PARAMETER IncludeSpe
        Specifies that the Sitecore PowerShell Extensions module should be included.

    .PARAMETER IncludeSxa
        Specifies that the Sitecore Experience Accelerator modules should be included.

    .PARAMETER IncludePackages
        Specifies that custom packages should be deployed after the containers start.

        Packages contained within .\docker\build\packages will be included in the built images.
        Packages contained within .\docker\releases will be deployed after the containers start up.

    .PARAMETER ForceConvert
        Forces re-conversion of all module packages in .\docker\releases\ to WDP format even when
        an up-to-date .scwdp.zip already exists. By default conversion is skipped when the output
        file is newer than the source .zip.

    .NOTES
        After the environment is up, run login.ps1 to authenticate the Sitecore CLI.
        For first-time index and publishing setup run maintenance.ps1.
#>

[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$IncludeSpe,
    [switch]$IncludeSxa,
    [switch]$IncludePackages,
    [switch]$ForceConvert
)

$releases = Join-Path -Path $PSScriptRoot -ChildPath "docker\releases"
$destination = "$($releases)\"

Add-Type -AssemblyName "System.IO.Compression"
Add-Type -AssemblyName "System.IO.Compression.FileSystem"
function Test-ValidModulePackage {
    param([string]$Path)
    $zip = [System.IO.Compression.ZipFile]::Open($Path, [System.IO.Compression.ZipArchiveMode]::Read)
    $isModule = $null -ne ($zip.Entries | Where-Object { $_.Name -eq "package.zip" })
    $zip.Dispose()
    $isModule
}

# Identify which .zip packages in docker\releases actually need WDP conversion.
# Conversion is skipped when a .scwdp.zip already exists and is at least as new
# as the source .zip.  Use -ForceConvert to override this check.
$packagesToConvert = Get-ChildItem -Path $releases -Filter "*.zip" |
    Where-Object { $_.Extension -ne ".scwdp.zip" } |
    Where-Object { Test-ValidModulePackage -Path $_.FullName } |
    Where-Object {
        $wdp = Join-Path $destination "$($_.BaseName).scwdp.zip"
        if (-not $ForceConvert -and (Test-Path $wdp) -and (Get-Item $wdp).LastWriteTime -ge $_.LastWriteTime) {
            Write-Host "Skipping $($_.BaseName) - up-to-date .scwdp.zip exists (use -ForceConvert to rebuild)" -ForegroundColor DarkGray
            return $false
        }
        return $true
    }

if ($packagesToConvert.Count -gt 0) {
    # SAT is only required when at least one package needs converting.
    $sat = Join-Path -Path $releases -ChildPath "sat"
    if (-not (Test-Path -Path $sat)) {
        New-Item -Path $sat -ItemType Directory > $null
    }

    $satConfig = Get-ChildItem -Path $releases -Filter "configuration.json" |
        Get-Content | ConvertFrom-Json | Select-Object -ExpandProperty "SitecoreAzureToolkit"

    $satModuleLibrary = Join-Path -Path $sat -ChildPath "tools\Sitecore.Cloud.Cmdlets.dll"
    if (-not (Test-Path -Path $satModuleLibrary)) {
        $satPackage = Join-Path -Path $sat -ChildPath $satConfig.Filename
        if (-not (Test-Path -Path $satPackage)) {
            $link = "$([char]27)]8;;$($satConfig.Url)$([char]27)\$($satConfig.Url)$([char]27)]8;;$([char]27)\"
            Write-Host ""
            Write-Host "Sitecore Azure Toolkit package not found." -ForegroundColor Yellow
            Write-Host "Download $($satConfig.Filename) from the Sitecore Developer Portal (login required) and place it at:" -ForegroundColor Yellow
            Write-Host "  $satPackage" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  $link" -ForegroundColor Cyan
            Write-Host ""
            exit 1
        }
        Expand-Archive -Path $satPackage -DestinationPath $sat
    }
    Import-Module -Name (Join-Path -Path $sat -ChildPath "tools\Sitecore.Cloud.Cmdlets.dll")

    foreach ($package in $packagesToConvert) {
        Write-Host "Converting $($package.BaseName)..." -ForegroundColor Green
        try {
            ConvertTo-SCModuleWebDeployPackage -Path $package.FullName -Destination $destination | Out-Null
        } catch {
            $PSItem.Exception
            Write-Warning "Verify that Microsoft® SQL Server® Data-Tier Application Framework is installed."
            Write-Host "Tip: Use Process Monitor to identify which libraries are missing."
            Write-Host "https://support.sitecore.com/kb?id=kb_article_view&sysparm_article=KB0019579"
            exit
        }
        Write-Host ""
    }
}

if (-not (docker ps)) {
    Write-Host "Please verify Docker is running and try again." -ForegroundColor Red
    break
}

$composeArgs = @("compose", "-f", ".\docker-compose.yml")

if (Test-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "docker-compose.override.yml")) {
    $composeArgs += "-f"
    $composeArgs += ".\docker-compose.override.yml"
}

if ($IncludeSpe -or $IncludeSxa) {
    $composeArgs += "-f"
    $composeArgs += ".\docker-compose.spe.yml"
}

if ($IncludeSxa) {
    $composeArgs += "-f"
    $composeArgs += ".\docker-compose.sxa.yml"
}

if (-not $SkipBuild) {
    Write-Host "Building Sitecore images..." -ForegroundColor Green
    $buildParams = $PSBoundParameters
    $buildParams.Remove("SkipBuild") > $null
    & (Join-Path -Path $PSScriptRoot -ChildPath "build.ps1") @buildParams

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Container build failed, see errors above."
    }
}

Write-Host "Starting Sitecore environment..." -ForegroundColor Green
docker $composeArgs up -d

Write-Host "Waiting for CM to become available (this typically takes 5-10 minutes)..." -ForegroundColor Green
$startTime = Get-Date
$timeoutSeconds = 600
do {
    Start-Sleep -Seconds 5
    $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
    Write-Host "  [$($elapsed)s / $($timeoutSeconds)s] Waiting for CM..." -ForegroundColor DarkGray
    try {
        $status = Invoke-RestMethod "http://localhost:8079/api/http/routers/cm-secure@docker"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -ne "404") {
            $containers = docker ps -a --format "table {{.Names}}"
            $container = $containers | ConvertFrom-Csv | Where-Object { $_.NAMES -match "-cm" } | Select-Object -First 1 -ExpandProperty NAMES
            docker exec $container curl http://cm
            throw
        }
    }
} while ($status.status -ne "enabled" -and $startTime.AddSeconds($timeoutSeconds) -gt (Get-Date))
if ($status.status -ne "enabled") {
    $status
    Write-Error "Timeout waiting for Sitecore CM to become available via Traefik proxy. Check CM container logs."
}

if ($IncludePackages) {
    & (Join-Path -Path $PSScriptRoot -ChildPath "deploy.ps1")
}

Write-Host ""
Write-Host "Environment is up. Next steps:" -ForegroundColor Green
Write-Host "  .\login.ps1        - Authenticate the Sitecore CLI" -ForegroundColor Cyan
Write-Host "  .\maintenance.ps1  - Populate Solr schema, publish content, rebuild indexes" -ForegroundColor Cyan
