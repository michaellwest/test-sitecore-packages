<#
    .SYNOPSIS
        Spins up the containers.

    .PARAMETER SkipBuild
        Specifies that the images should not be built prior to starting up.

    .PARAMETER IncludeSps
        Species that the Sitecore Publishing Service should be included.

    .PARAMETER IncludeSpe
        Specifies that the Sitecore PowerShell Extensions module should be included.

    .PARAMETER IncludeSxa
        Specifies that the Sitecore Exerience Accelerator modules should be included.

    .PARAMETER IncludePackages
        Specifies that custom packages should be included during the build and/or after startup.

        Packages contained within .\docker\build\releases will be included in the built images.
        Packages contained within .\docker\releases will be deployed after the containers startup.
#>

[CmdletBinding()]
param(
    [switch]$IncludeSps,
    [switch]$IncludeSpe,
    [switch]$IncludeSxa,
    [switch]$IncludePackages,
    [switch]$SkipBuild,
    [switch]$SkipIndexing
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
    if (-not (Test-ValidModulePackage -Path $package)) {
        continue
    }

    $packageName = [System.IO.Path]::GetFileNameWithoutExtension($package)    
    Write-Host "Converting $($packageName)"
    try {
        $convertedFilename = Join-Path -Path $destination -ChildPath "$($packageName).scwdp.zip"
        if (Test-Path -Path $convertedFilename) {
            Remove-Item -Path $convertedFilename
        }
        $wdpPath = ConvertTo-SCModuleWebDeployPackage -Path $package  -Destination $destination #-DisableDacPacOptions * -Force
    } catch {
        $PSItem.Exception
        Write-Warning "Verify that Microsoft® SQL Server® Data-Tier Application Framework is installed."    
        Write-Host "Tip: Use Process Monitor to identify which libraries are missing."
        Write-Host "https://support.sitecore.com/kb?id=kb_article_view&sysparm_article=KB0019579"
        exit
    }
    
    Write-Host ""
}

if (-not (docker ps)) {
    Write-Host "Please verify Docker is running and try again." -ForegroundColor Red
    break
}


$composeArgs = @("compose", "-f", ".\docker-compose.yml")

if(Test-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "docker-compose.override.yml")) {
    $composeArgs += "-f"
    $composeArgs += ".\docker-compose.override.yml"
}

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

if(-not $SkipBuild) {
    Write-Host "Build Sitecore images..." -ForegroundColor Green
    $parameters = $PSBoundParameters
    $parameters.Remove("SkipBuild") > $null
    $parameters.Remove("SkipIndexing") > $null
    & (Join-Path -Path $PSScriptRoot -ChildPath "build.ps1") @parameters

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Container build failed, see errors above."
    }
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

Write-Host "Restoring Sitecore CLI..." -ForegroundColor Green
dotnet tool restore
Write-Host "Installing Sitecore CLI Plugins..."
dotnet sitecore --help | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Unexpected error installing Sitecore CLI Plugins"
}

Import-Module .\tools\DockerToolsLite
$envPath = Join-Path -Path $PSScriptRoot -ChildPath ".env"
$cmHost = Get-EnvFileVariable -Variable "CM_HOST" -Path $envPath
$idHost = Get-EnvFileVariable -Variable "ID_HOST" -Path $envPath

Write-Host "Logging into Sitecore..." -ForegroundColor Green
dotnet sitecore login --cm https://$cmHost --allow-write true --auth https://$idHost

if ($LASTEXITCODE -ne 0) {
    Write-Error "Unable to log into Sitecore, did the Sitecore environment start correctly? See logs above."
}

if (-not $SkipIndexing) {
    # Populate Solr managed schemas to avoid errors during item deploy
    Write-Host "Populating Solr managed schema..." -ForegroundColor Green
    dotnet sitecore index schema-populate
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Populating Solr managed schema failed, see errors above."
    }

    # Rebuild indexes
    Write-Host "Rebuilding indexes ..." -ForegroundColor Green
    dotnet sitecore index rebuild
}

Write-Host "Good luck!" -ForegroundColor Green

Write-Host "Opening site..." -ForegroundColor Green
Start-Process "https://$($cmHost)/sitecore"