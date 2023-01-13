<#
    .SYNOPSIS
        Performs the initial setup procedures required for the containers.
        
    .PARAMETER LicenseXmlPath
        Specifies the fully-qualified path to the Sitecore license xml file.
#>
[CmdletBinding()]
Param (
    [ValidateScript({return ![string]::IsNullOrEmpty($_)})]
    [string]
    $LicenseXmlPath = "C:\License\license.xml",

    [string]
    $HostName = "dev.local",
    
    # We do not need to use [SecureString] here since the value will be stored unencrypted in .env,
    # and used only for transient local example environment.
    [string]
    $SitecoreAdminPassword = "Password12345",
    
    # We do not need to use [SecureString] here since the value will be stored unencrypted in .env,
    # and used only for transient local example environment.
    [string]
    $SqlSaPassword = "Password12345"
)

$ErrorActionPreference = "Stop";

if (-not (Test-Path $LicenseXmlPath)) {
    throw "Did not find $LicenseXmlPath"
}
if (-not (Test-Path $LicenseXmlPath -PathType Leaf)) {
    throw "$LicenseXmlPath is not a file"
}
if (-not (Test-Path ".env")) {
    Write-Host "Copying new .env" -ForegroundColor Green
    Copy-Item ".\docker\.env" ".env"
}

# Check for Sitecore Gallery
Import-Module PowerShellGet
$SitecoreGallery = Get-PSRepository | Where-Object { $_.SourceLocation -eq "https://sitecore.myget.org/F/sc-powershell/api/v2" }
if (-not $SitecoreGallery) {
    Write-Host "Adding Sitecore PowerShell Gallery..." -ForegroundColor Green 
    Register-PSRepository -Name SitecoreGallery -SourceLocation https://sitecore.myget.org/F/sc-powershell/api/v2 -InstallationPolicy Trusted
    $SitecoreGallery = Get-PSRepository -Name SitecoreGallery
}
# Install and Import SitecoreDockerTools 
$dockerToolsVersion = "10.2.7"
Remove-Module SitecoreDockerTools -ErrorAction SilentlyContinue
if (-not (Get-InstalledModule -Name SitecoreDockerTools -RequiredVersion $dockerToolsVersion -ErrorAction SilentlyContinue)) {
    Write-Host "Installing SitecoreDockerTools..." -ForegroundColor Green
    Install-Module SitecoreDockerTools -RequiredVersion $dockerToolsVersion -Scope CurrentUser -Repository $SitecoreGallery.Name
}
Write-Host "Importing SitecoreDockerTools..." -ForegroundColor Green
Import-Module SitecoreDockerTools -RequiredVersion $dockerToolsVersion
Write-SitecoreDockerWelcome

###############################
# Populate the environment file
###############################
$envPath = Join-Path -Path $PSScriptRoot -ChildPath ".env"

Write-Host "Populating required .env file variables..." -ForegroundColor Green

# SITECORE_ADMIN_PASSWORD
Set-EnvFileVariable "SITECORE_ADMIN_PASSWORD" -Value $SitecoreAdminPassword

# SQL_SA_PASSWORD
Set-EnvFileVariable "SQL_SA_PASSWORD" -Value $SqlSaPassword

# CM_HOST
$cmHost = Get-EnvFileVariable -Variable "CM_HOST" -Path $envPath
if([string]::IsNullOrEmpty($cmHost)) {
    $cmHost = "cm.$($HostName)"
    Set-EnvFileVariable "CM_HOST" -Value $cmHost
}

# ID_HOST
$idHost = Get-EnvFileVariable -Variable "ID_HOST" -Path $envPath
if([string]::IsNullOrEmpty($idHost)) {
    $idHost = "id.$($HostName)"
    Set-EnvFileVariable "ID_HOST" -Value $idHost
}

# TELERIK_ENCRYPTION_KEY = random 64-128 chars
Set-EnvFileVariable "TELERIK_ENCRYPTION_KEY" -Value (Get-SitecoreRandomString 128 -DisallowSpecial)

# MEDIA_REQUEST_PROTECTION_SHARED_SECRET
Set-EnvFileVariable "MEDIA_REQUEST_PROTECTION_SHARED_SECRET" -Value (Get-SitecoreRandomString 64 -DisallowSpecial)

# SITECORE_IDSECRET = random 64 chars
Set-EnvFileVariable "SITECORE_IDSECRET" -Value (Get-SitecoreRandomString 64 -DisallowSpecial)

# SITECORE_ID_CERTIFICATE
$idCertPassword = Get-SitecoreRandomString 12 -DisallowSpecial
Set-EnvFileVariable "SITECORE_ID_CERTIFICATE" -Value (Get-SitecoreCertificateAsBase64String -DnsName "localhost" -Password (ConvertTo-SecureString -String $idCertPassword -Force -AsPlainText))

# SITECORE_ID_CERTIFICATE_PASSWORD
Set-EnvFileVariable "SITECORE_ID_CERTIFICATE_PASSWORD" -Value $idCertPassword

# SITECORE_LICENSE_LOCATION and SITECORE_LICENSE_PATH
$licensePath = Get-EnvFileVariable -Variable "SITECORE_LICENSE_LOCATION" -Path $envPath
if([string]::IsNullOrEmpty($licensePath)) {
    Set-EnvFileVariable "SITECORE_LICENSE_LOCATION" -Value $LicenseXmlPath
    Set-EnvFileVariable "SITECORE_LICENSE_PATH" -Value ([System.IO.Path]::GetDirectoryName($LicenseXmlPath))
}

##################################
# Configure TLS/HTTPS certificates
##################################

Push-Location docker\traefik\certs
try {
    $certz = Join-Path -Path (Get-Location) -ChildPath "certz.exe"
    if ($null -ne (Get-Command certz.exe -ErrorAction SilentlyContinue)) {
        # certz installed in PATH
        $certz = "certz"
    } elseif (-not (Test-Path $certz)) {
        Write-Host "Downloading and installing certz certificate tool..." -ForegroundColor Green
        $url = "https://github.com/michaellwest/certz/releases/download/0.2/certz-0.2-win64.exe"
        $webClient = New-Object System.Net.WebClient
        $webClient.Downloadfile($url, $certz)
        
        $currentHash = Get-FileHash -Path $certz -Algorithm SHA256 | Select-Object -Expand Hash
        if ($currentHash -ne "D4625A4B55709DB1854DA8E1A2B93A3DF25C6F4E8FB5C0424A905029BB1FA2B6") {
            Remove-Item $certz -Force
            throw "Invalid certz.exe file"
        }
    }
    Write-Host "Generating Traefik TLS certificate..." -ForegroundColor Green
    & $certz create --f devcert.pfx --san "*.$($HostName)" --p changeit --c devcert.cer --k devcert.key --days 1825
    & $certz install --f devcert.pfx --p changeit --sl localmachine --sn root
}
catch {
    Write-Host "An error occurred while attempting to generate TLS certificate: $_" -ForegroundColor Red
}
finally {
    Pop-Location
}

Write-Host "Done!" -ForegroundColor Green