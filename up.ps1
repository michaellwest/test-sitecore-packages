docker-compose up -d
docker exec test-sitecore-packages_sql_1 powershell C:\releases\sql.ps1
docker exec test-sitecore-packages_cm_1 powershell C:\releases\cm.ps1