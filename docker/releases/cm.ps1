Write-Host "Preparing to deploy packages to the website"
if(Test-Path -Path "C:\temp") {
    Remove-Item -Path "C:\temp" -Recurse -Force
}
New-Item -Path "C:\temp\packages\" -ItemType Directory
New-Item -Path "C:\temp\extract\" -ItemType Directory

Write-Host "- Copying packages from release directory"
Copy-Item -Path "C:\releases\*.zip" -Destination "C:\temp\packages\"
$archives = Get-ChildItem -Path "C:\temp\packages\*.zip"

foreach($archive in $archives) {
    Get-ChildItem -Path "C:\temp\extract\*" -Recurse | Remove-Item -Recurse -Force

    Write-Host " - Extracting archive contents for $($archive.Name)"
    if($archive.Extension -eq ".scwdp.zip") {
        $archive | Expand-Archive -DestinationPath "C:\temp\extract"
    } elseif($archive.Extension -eq ".zip") {
        $archive | Expand-Archive -DestinationPath "C:\temp\extract\Content\Website\"
    } else{
        Write-Host "- Skipping extraction as contents not expected"
    }
    
    Write-Host " - Copying files to the website"
    Copy-Item -Path "C:\temp\extract\Content\Website\*" -Destination "C:\inetpub\wwwroot" -Recurse -Force
    
    Write-Host " - Applying transforms"
    $transforms = Get-ChildItem -Path "C:\inetpub\wwwroot\App_Data\" -Include "*.xdt" -Recurse
    foreach($transform in $transforms) {
        . C:\tools\scripts\Invoke-XdtTransform.ps1 -Path "C:\inetpub\wwwroot" -XdtPath $transform.Directory
    }
}