Write-Host "Preparing to deploy packages to the database"
if(Test-Path -Path "C:\temp") {
    Remove-Item -Path "C:\temp" -Recurse -Force
}
New-Item -Path "C:\temp\packages\" -ItemType Directory

Write-Host "- Extracting packages"
Copy-Item -Path "C:\releases\*.scwdp.zip" -Destination "C:\temp\packages\"
Expand-Archive -Path "C:\temp\packages\*.zip" -DestinationPath "C:\temp"

Write-Host "- Pushing database changes to the database"
$modulePath = "C:\temp\"
$sqlPackageExePath = Get-Item -Path "C:\Program Files\Microsoft SQL Server\*\DAC\bin\SqlPackage.exe" | Select-Object -Last 1 -ExpandProperty FullName
$textInfo = (Get-Culture).TextInfo

Get-ChildItem -Path $modulePath -Include "core.dacpac", "master.dacpac" -Recurse | ForEach-Object {
    $dacpacPath = $_.FullName
    $databaseName = "Sitecore.$($textInfo.ToTitleCase($_.BaseName))"

    & $sqlPackageExePath /a:Publish /sf:$dacpacPath /tdn:$databaseName /tsn:$env:ComputerName /q
}