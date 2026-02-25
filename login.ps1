<#
    .SYNOPSIS
        Restores the Sitecore CLI and logs into the running Sitecore environment.

    .DESCRIPTION
        Ensures the Sitecore NuGet source is registered, restores the dotnet tool
        manifest (Sitecore CLI and plugins), then opens a browser-based login flow
        against the running Identity Server.

        Run this after up.ps1 has confirmed the CM is healthy, or any time you need
        to refresh the CLI session (e.g. after a token expires).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$nugetSource = dotnet nuget list source --format short | Where-Object { $_ -like "*sitecore*" }
if (!$nugetSource) {
    Write-Host "Adding Sitecore NuGet source..." -ForegroundColor Green
    dotnet nuget add source -n Sitecore https://nuget.sitecore.com/resources/v3/index.json
}

Write-Host "Restoring Sitecore CLI..." -ForegroundColor Green
dotnet tool restore

Write-Host "Installing Sitecore CLI plugins..." -ForegroundColor Green
dotnet sitecore --help | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Unexpected error installing Sitecore CLI plugins"
}

Import-Module (Join-Path $PSScriptRoot "tools\DockerToolsLite")
$envPath = Join-Path $PSScriptRoot ".env"
$cmHost = Get-EnvFileVariable -Variable "CM_HOST" -Path $envPath
$idHost = Get-EnvFileVariable -Variable "ID_HOST" -Path $envPath

Write-Host "Logging into Sitecore (a browser window will open)..." -ForegroundColor Green
dotnet sitecore login --cm "https://$cmHost" --allow-write true --auth "https://$idHost"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Unable to log into Sitecore. Did the environment start correctly? Check CM container logs."
}

Write-Host "Logged in. Opening CM..." -ForegroundColor Green
Start-Process "https://$cmHost/sitecore"
