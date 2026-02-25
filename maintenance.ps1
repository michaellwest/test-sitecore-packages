<#
    .SYNOPSIS
        Runs post-startup Sitecore maintenance tasks via the Sitecore CLI.

    .DESCRIPTION
        Populates the Solr managed schema, publishes content from master to web,
        and rebuilds all search indexes.

        Requires an active Sitecore CLI session (run login.ps1 first).

    .PARAMETER SkipSchemaPopulate
        Skips the Solr managed schema population step.

    .PARAMETER SkipPublish
        Skips the content publish step.

    .PARAMETER SkipIndexRebuild
        Skips the search index rebuild step.
#>
[CmdletBinding()]
param(
    [switch]$SkipSchemaPopulate,
    [switch]$SkipPublish,
    [switch]$SkipIndexRebuild
)

$ErrorActionPreference = "Stop"

if (-not $SkipSchemaPopulate) {
    Write-Host "Populating Solr managed schema..." -ForegroundColor Green
    dotnet sitecore index schema-populate
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Populating Solr managed schema failed, see errors above."
    }
}

if (-not $SkipPublish) {
    Write-Host "Publishing content..." -ForegroundColor Green
    dotnet sitecore publish
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Content publish failed, see errors above."
    }
}

if (-not $SkipIndexRebuild) {
    Write-Host "Rebuilding indexes..." -ForegroundColor Green
    dotnet sitecore index rebuild
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Index rebuild failed, see errors above."
    }
}

Write-Host "Maintenance complete." -ForegroundColor Green
