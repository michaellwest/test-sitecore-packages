Write-Host "Preparing to deploy packages to the database"
if(Test-Path -Path "C:\temp") {
    Remove-Item -Path "C:\temp" -Recurse -Force
}
New-Item -Path "C:\temp\packages\" -ItemType Directory > $null
New-Item -Path "C:\temp\extract\" -ItemType Directory > $null

Write-Host "- Copying packages from release directory"
Copy-Item -Path "C:\releases\*.scwdp.zip" -Destination "C:\temp\packages\"
$archives = Get-ChildItem -Path "C:\temp\packages\*.zip"

foreach($archive in $archives) {
    Get-ChildItem -Path "C:\temp\extract\*" -Recurse | Remove-Item -Recurse -Force
    Write-Host "- Extracting archive contents for $($archive.Name)"
    $archive | Expand-Archive -DestinationPath "C:\temp\extract"
    Write-Host "- Pushing database changes to the database for $($archive.Name)"
    $modulePath = "C:\temp\extract"
    $sqlPackageExePath = Get-Item -Path "C:\Program Files\Microsoft SQL Server\*\DAC\bin\SqlPackage.exe" | Select-Object -Last 1 -ExpandProperty FullName
    $textInfo = (Get-Culture).TextInfo
    
    Get-ChildItem -Path $modulePath -Include "core.dacpac", "master.dacpac" -Recurse | ForEach-Object {
        $dacpacPath = $_.FullName
        $databaseName = "Sitecore.$($textInfo.ToTitleCase($_.BaseName))"

        & $sqlPackageExePath /a:Publish /sf:$dacpacPath /tdn:$databaseName /tsn:$env:ComputerName /q
    }
}