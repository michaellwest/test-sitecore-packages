Write-Host "Importing DockerToolsLite..." -ForegroundColor Green
Import-Module .\tools\DockerToolsLite
$envPath = Join-Path -Path $PSScriptRoot -ChildPath ".env"
$composeProjectName = Get-EnvFileVariable -Variable "COMPOSE_PROJECT_NAME" -Path $envPath

Write-Host "Installing packaged releases to containers..." -ForegroundColor Green
docker exec --user ContainerAdministrator "$($composeProjectName)-mssql-1" powershell C:\releases\sql.ps1
docker exec --user ContainerAdministrator "$($composeProjectName)-cm-1" powershell C:\releases\cm.ps1