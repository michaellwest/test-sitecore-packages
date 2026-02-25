<#
    .SYNOPSIS
        Tears down the Sitecore Docker environment.

    .PARAMETER Cleanup
        When specified, clears data volumes and build artefacts after stopping containers.

    .PARAMETER IncludeSpe
        Must match the flags used when up.ps1 was called so that SPE overlay services
        are properly included in the down operation.

    .PARAMETER IncludeSxa
        Must match the flags used when up.ps1 was called so that SXA overlay services
        are properly included in the down operation.
#>
[CmdletBinding()]
param(
    [switch]$Cleanup,
    [switch]$IncludeSpe,
    [switch]$IncludeSxa
)

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

docker $composeArgs down --remove-orphans

if ($Cleanup) {
    & (Join-Path -Path $PSScriptRoot -ChildPath "clean.ps1")
}
