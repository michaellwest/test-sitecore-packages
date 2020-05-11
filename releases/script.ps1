# Start-Process msiexec.exe -ArgumentList '/i', 'C:\releases\WebDeploy_amd64_en-US.msi', '/quiet', '/norestart' -NoNewWindow -Wait 
<#
$argumentList = @(
    '-verb:sync', 
    '-source:package=C:\releases\Sitecore.PowerShell.Extensions-6.1.1.scwdp.zip', 
    '-dest:archiveDir="C:\inetpub\wwwroot\"', 
    '-setParam:"Application Path"="Default Web Site"', 
    '-setParam:"Core Admin Connection String"="$($env:SITECORE_CONNECTIONSTRINGS_CORE)"',
    '-setParam:"Master Admin Connection String"="$($env:SITECORE_CONNECTIONSTRINGS_MASTER)"',
    '-enableRule:DoNotDeleteRule'
)

Start-Process "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe" -ArgumentList $argumentList -NoNewWindow -Wait
#>
New-Item -Path "C:\Temp\packages\" -ItemType Directory
Copy-Item -Path "C:\releases\Sitecore.PowerShell.Extensions-6.1.1.scwdp.zip" -Destination "C:\temp\packages\"
Expand-Archive -Path "C:\temp\packages\*.zip" -DestinationPath "C:\temp"
Copy-Item -Path "C:\temp\Content\Website\*" -Destination "C:\inetpub\wwwroot" -Recurse -Force