Write-Host "Installing packaged releases to containers..." -ForegroundColor Green
docker exec --user ContainerAdministrator test-mssql-1 powershell C:\releases\sql.ps1
docker exec --user ContainerAdministrator test-cm-1 powershell C:\releases\cm.ps1