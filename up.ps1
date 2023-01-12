[CmdletBinding()]
param(
    [switch]$Build,
    [switch]$IncludeSps,
    [switch]$IncludeSpe,
    [switch]$IncludeSxa,
    [switch]$IncludePackages
)

$releases = Join-Path -Path $PSScriptRoot -ChildPath "docker\releases"

$sat = Join-Path -Path $releases -ChildPath "sat"
if(-not (Test-Path -Path $sat)) {
    New-Item -Path $sat -ItemType Directory > $null
}

$satConfig = Get-ChildItem -Path $releases -Filter "configuration.json" | 
    Get-Content | ConvertFrom-Json | Select-Object -ExpandProperty "SitecoreAzureToolkit"

$satPackage = Join-Path -Path $sat -ChildPath $satConfig.Filename
if(-not (Test-Path -Path $satPackage)) {
    Get-ChildItem -Path $sat -Recurse | Remove-Item -Recurse

    Write-Host "Downloading $($satConfig.Filename)"
    $webClient = New-Object System.Net.WebClient
    $webClient.Downloadfile($satConfig.Url, $satPackage)
    
    Write-Host "Unblocking $($satConfig.Filename)"
    Unblock-File -Path $satPackage

    Expand-Archive -Path $satPackage -DestinationPath $sat
}

Import-Module -Name (Join-Path -Path $sat -ChildPath "tools\Sitecore.Cloud.Cmdlets.dll")

$packages = Get-ChildItem -Path $releases -Filter "*.zip" | 
    Where-Object { $_.Extension -ne ".scwdp.zip" } | 
    Select-Object -ExpandProperty FullName

$destination = "$($releases)\"

Add-Type -AssemblyName "System.IO.Compression"
Add-Type -AssemblyName "System.IO.Compression.FileSystem"
function Test-ValidModulePackage {
    param(
        [string]$Path
    )

    $isModulePackage = $false
    $zip = [System.IO.Compression.ZipFile]::Open($Path, [System.IO.Compression.ZipArchiveMode]::Read)
    $packageZipEntry = $zip.Entries | Where-Object { $_.Name -eq "package.zip" }

    if($packageZipEntry) {
        $isModulePackage = $true
    }
    $zip.Dispose()

    $isModulePackage
}

foreach($package in $packages) {
    if(-not (Test-ValidModulePackage -Path $package)) {
        continue
    }

    Write-Host "Converting $([System.IO.Path]::GetFileNameWithoutExtension($package))"
    try {
        $wdpPath = ConvertTo-SCModuleWebDeployPackage -Path $package  -Destination $destination -DisableDacPacOptions * -Force
    } catch {
        $Error[0]
        exit
    }
    
    Write-Host ""
}

if (-not (docker ps)) {
    Write-Host "Please verify Docker is running and try again." -ForegroundColor Red
    break
}


$composeArgs = @("compose", "-f", ".\docker-compose.yml", "-f", ".\docker-compose.override.yml")

if($IncludeSps) {
    $composeArgs += "-f"
    $composeArgs += ".\docker-compose.sps.yml"
}

if($IncludeSpe -or $IncludeSxa) {
    $composeArgs += "-f"
    $composeArgs += ".\docker-compose.spe.yml"
}

if($IncludeSxa) {
    $composeArgs += "-f"
    $composeArgs += ".\docker-compose.sxa.yml"
}

if($Build) {
    Write-Host "Build Sitecore images..." -ForegroundColor Green
    $parameters = $PSBoundParameters
    $parameters.Remove("Build") > $null
    & (Join-Path -Path $PSScriptRoot -ChildPath "build.ps1") @parameters
}

Write-Host "Starting Sitecore environment..." -ForegroundColor Green
docker $composeArgs up -d

Write-Host "Waiting for CM to become available..." -ForegroundColor Green
$startTime = Get-Date
do {
    Start-Sleep -Milliseconds 100
    try {
        $status = Invoke-RestMethod "http://localhost:8079/api/http/routers/cm-secure@docker"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -ne "404") {
            throw
        }
    }
} while ($status.status -ne "enabled" -and $startTime.AddSeconds(15) -gt (Get-Date))
if (-not $status.status -eq "enabled") {
    $status
    Write-Error "Timeout waiting for Sitecore CM to become available via Traefik proxy. Check CM container logs."
}

if($IncludePackages) {
    & (Join-Path -Path $PSScriptRoot -ChildPath "deploy.ps1")
}

Write-Host "Good luck!" -ForegroundColor Green