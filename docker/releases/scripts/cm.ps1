Write-Host "Preparing to deploy packages to the website"
if(Test-Path -Path "C:\temp") {
    Remove-Item -Path "C:\temp" -Recurse -Force
}
New-Item -Path "C:\temp\packages\" -ItemType Directory > $null
New-Item -Path "C:\temp\extract\" -ItemType Directory > $null

Write-Host "- Copying packages from release directory"
Copy-Item -Path "C:\releases\*.zip" -Destination "C:\temp\packages\"
$archives = Get-ChildItem -Path "C:\temp\packages\*.zip"

foreach($archive in $archives) {
    Get-ChildItem -Path "C:\temp\extract\*" -Recurse | Remove-Item -Recurse -Force

    if($archive.Name.EndsWith(".scwdp.zip")) {
        Write-Host " - Extracting webdeploy archive contents for $($archive.Name)"
        $archive | Expand-Archive -DestinationPath "C:\temp\extract"
    } elseif($archive.Name.EndsWith(".zip")) {
        Write-Host " - Extracting archive contents for $($archive.Name)"
        $archive | Expand-Archive -DestinationPath "C:\temp\extract\Content\Website"
    }
    
    Write-Host " - Copying files to the website"
    Copy-Item -Path "C:\temp\extract\Content\Website\*" -Destination "C:\inetpub\wwwroot" -Recurse -Force
    
    Write-Host " - Applying transforms"
    $transforms = Get-ChildItem -Path "C:\inetpub\wwwroot\App_Data\" -Include "*.xdt" -Recurse
    foreach($transform in $transforms) {
        . C:\tools\scripts\Invoke-XdtTransform.ps1 -Path "C:\inetpub\wwwroot" -XdtPath $transform.Directory
    }
}