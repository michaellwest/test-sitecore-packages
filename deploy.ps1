<#
    .SYNOPSIS
        Installs packages from .\docker\releases\ into the running containers.

    .DESCRIPTION
        Runs the sql.ps1 and cm.ps1 release scripts that are volume-mounted inside
        the mssql and cm containers respectively.  Uses 'docker compose exec' so
        the service is referenced by its Compose service name rather than the
        auto-generated container name, which makes this robust against project
        renames and replica scaling.

        Requires the containers to be running (run up.ps1 first).
#>
[CmdletBinding()]
param()

$composeArgs = @("compose", "-f", ".\docker-compose.yml")

if (Test-Path -Path (Join-Path $PSScriptRoot "docker-compose.override.yml")) {
    $composeArgs += "-f", ".\docker-compose.override.yml"
}

Write-Host "Installing packaged releases to containers..." -ForegroundColor Green
docker $composeArgs exec --user ContainerAdministrator mssql powershell C:\releases\scripts\sql.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Error "SQL release script failed, see errors above."
}

docker $composeArgs exec --user ContainerAdministrator cm powershell C:\releases\scripts\cm.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Error "CM release script failed, see errors above."
}

Write-Host "Package deployment complete." -ForegroundColor Green
