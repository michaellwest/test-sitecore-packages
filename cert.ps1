<#
    .SYNOPSIS
        Creates or renews the Traefik TLS development certificate used by the local Docker environment.

    .DESCRIPTION
        Downloads certz if not already present, then either generates a new self-signed certificate
        or renews an existing one. After the certificate operation the PFX is installed into the
        Windows Local Machine > Trusted Root Certification Authorities store so the browser trusts it.

        Run this script once during initial setup (via init.ps1) and again whenever the certificate
        is approaching expiry (default lifetime is 5 years / 1825 days).

    .PARAMETER HostName
        The base hostname used to build the Subject Alternative Name wildcard, e.g. "dev.local"
        produces a SAN of "*.dev.local". Defaults to "dev.local".

    .PARAMETER Renew
        When specified, runs `certz renew` against the existing PFX rather than generating a new one.
        Use this for annual or pre-expiry renewal without changing the certificate files.

    .PARAMETER CertDir
        Path to the directory that holds the certificate files. Defaults to the
        "docker\traefik\certs" sub-directory relative to this script.

    .PARAMETER Days
        Validity period in days for a newly created certificate. Ignored during renewal (certz
        re-uses the original validity window unless the tool overrides it). Defaults to 1825 (5 years).

    .EXAMPLE
        .\New-DevCert.ps1
        Creates a new certificate for *.dev.local and installs it.

    .EXAMPLE
        .\New-DevCert.ps1 -Renew
        Renews the existing certificate and re-installs it.

    .EXAMPLE
        .\New-DevCert.ps1 -HostName "myproject.local" -Days 365
        Creates a one-year certificate scoped to *.myproject.local.

    .NOTES
        Requires Windows and PowerShell 5.1+. The install step requires an elevated (Administrator)
        shell because it writes to the Local Machine certificate store.

        certz binary:
          Version : 0.3
          URL     : https://github.com/michaellwest/certz/releases/download/0.3/certz.exe
          SHA-256 : 68F80D2E26B93DD6F503D005B401E5BDFC5DD8D3C78CD77488786AB92B7480AD
#>
[CmdletBinding(SupportsShouldProcess)]
Param (
    [string]$HostName = "dev.local",

    [switch]$Renew,

    [string]$CertDir = (Join-Path $PSScriptRoot "docker\traefik\certs"),

    [int]$Days = 1825
)

$ErrorActionPreference = "Stop"

###############################################################################
# Constants
###############################################################################
$CertzVersion  = "0.3"
$CertzUrl      = "https://github.com/michaellwest/certz/releases/download/$CertzVersion/certz.exe"
$CertzHash     = "68F80D2E26B93DD6F503D005B401E5BDFC5DD8D3C78CD77488786AB92B7480AD"

$PfxFile      = Join-Path $CertDir "devcert.pfx"
$CerFile      = Join-Path $CertDir "devcert.cer"
$KeyFile      = Join-Path $CertDir "devcert.key"
$PasswordFile = Join-Path $CertDir "devcert.password.txt"

###############################################################################
# Resolve certz executable
###############################################################################
Push-Location $CertDir
try {
    $certz = Join-Path $CertDir "certz.exe"

    if ($null -ne (Get-Command certz.exe -ErrorAction SilentlyContinue)) {
        $certz = "certz"
        Write-Host "Using certz found in PATH." -ForegroundColor Cyan
    } elseif (Test-Path $certz) {
        Write-Host "Using certz found in $CertDir." -ForegroundColor Cyan
    } else {
        Write-Host "Downloading certz $CertzVersion..." -ForegroundColor Green
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($CertzUrl, $certz)

        $actualHash = (Get-FileHash -Path $certz -Algorithm SHA256).Hash
        if ($actualHash -ne $CertzHash) {
            Remove-Item $certz -Force
            throw "certz.exe hash mismatch. Expected: $CertzHash  Got: $actualHash"
        }
        Write-Host "certz downloaded and verified." -ForegroundColor Green
    }

    ###########################################################################
    # Create or renew
    ###########################################################################
    if ($Renew) {
        Write-Host "Renewing Traefik TLS certificate..." -ForegroundColor Green
        & $certz renew --f $PfxFile --password-file $PasswordFile --days $Days
    } else {
        Write-Host "Generating Traefik TLS certificate for *.$HostName..." -ForegroundColor Green
        & $certz create `
            --f $PfxFile `
            --san "*.$HostName" "localhost" `
            --password-file $PasswordFile `
            --c $CerFile `
            --k $KeyFile `
            --days $Days
    }

    if ($LASTEXITCODE -ne 0) {
        throw "certz exited with code $LASTEXITCODE"
    }

    ###########################################################################
    # Install into Local Machine Trusted Root store
    ###########################################################################
    Write-Host "Installing certificate into Local Machine Trusted Root store..." -ForegroundColor Green
    & $certz install --f $PfxFile --password-file $PasswordFile --sl localmachine --sn root

    if ($LASTEXITCODE -ne 0) {
        throw "certz install exited with code $LASTEXITCODE"
    }

    Write-Host "Certificate operation complete." -ForegroundColor Green
}
catch {
    Write-Host "Certificate error: $_" -ForegroundColor Red
    throw
}
finally {
    Pop-Location
}
