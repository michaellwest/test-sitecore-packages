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
    Copy-Item ".\docker\.env.example" ".env"
}
if (-not (Test-Path "docker-compose.override.yml")) {
    Write-Host "Copying new docker-compose.override.yml" -ForegroundColor Green
    Copy-Item ".\docker\docker-compose.override.yml.example" "docker-compose.override.yml"
}

##################################
# Configure TLS/HTTPS certificates
##################################

Write-Host "Creating Traefik TLS certificate..." -ForegroundColor Green
& "$PSScriptRoot\cert.ps1" -HostName $HostName

Write-Host "Importing DockerToolsLite..." -ForegroundColor Green
Import-Module .\tools\DockerToolsLite

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
Set-EnvFileVariable "TELERIK_ENCRYPTION_KEY" -Value (Get-RandomString 128 -DisallowSpecial)

# MEDIA_REQUEST_PROTECTION_SHARED_SECRET
Set-EnvFileVariable "MEDIA_REQUEST_PROTECTION_SHARED_SECRET" -Value (Get-RandomString 64 -DisallowSpecial)

# SITECORE_IDSECRET = random 64 chars
Set-EnvFileVariable "SITECORE_IDSECRET" -Value (Get-RandomString 64 -DisallowSpecial)

# SITECORE_ID_CERTIFICATE
$certificatePath = Resolve-Path -Path ".\docker\traefik\certs\devcert.pfx"
$certificatePassword = Get-Content -Path (Resolve-Path -Path ".\docker\traefik\certs\devcert.password.txt") -Raw
$certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList $certificatePath, $certificatePassword, ([System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet)
$certificateBytes = $certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $Password)
$certificateBase64String = [System.Convert]::ToBase64String($certificateBytes)
Set-EnvFileVariable "SITECORE_ID_CERTIFICATE" -Value $certificateBase64String

# SITECORE_ID_CERTIFICATE_PASSWORD
Set-EnvFileVariable "SITECORE_ID_CERTIFICATE_PASSWORD" -Value $certificatePassword

# SITECORE_LICENSE_LOCATION and SITECORE_LICENSE_PATH
$licensePath = Get-EnvFileVariable -Variable "SITECORE_LICENSE_LOCATION" -Path $envPath
if([string]::IsNullOrEmpty($licensePath)) {
    Set-EnvFileVariable "SITECORE_LICENSE_LOCATION" -Value $LicenseXmlPath
    Set-EnvFileVariable "SITECORE_LICENSE_PATH" -Value ([System.IO.Path]::GetDirectoryName($LicenseXmlPath))
}

Write-Host "Next try running up.ps1" -ForegroundColor Green