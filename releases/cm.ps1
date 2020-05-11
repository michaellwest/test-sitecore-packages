Write-Host "Preparing to deploy packages to the website"
if(Test-Path -Path "C:\temp") {
    Remove-Item -Path "C:\temp" -Recurse -Force
}
New-Item -Path "C:\temp\packages\" -ItemType Directory

Write-Host "- Extracting packages"
Copy-Item -Path "C:\releases\*.scwdp.zip" -Destination "C:\temp\packages\"
Expand-Archive -Path "C:\temp\packages\*.zip" -DestinationPath "C:\temp"

Write-Host "- Copying files to the website"
Copy-Item -Path "C:\temp\Content\Website\*" -Destination "C:\inetpub\wwwroot" -Recurse -Force