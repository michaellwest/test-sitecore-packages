$releases = Join-Path -Path $PSScriptRoot -ChildPath "docker\releases"

$sat = Join-Path -Path $releases -ChildPath "sat"
if(-not (Test-Path -Path $sat)) {
    New-Item -Path $sat -ItemType Directory > $null
}

$satConfig = Get-ChildItem -Path $releases -Filter "configuration.json" | 
    Get-Content | ConvertFrom-Json | Select-Object -ExpandProperty "SitecoreAzureToolkit"

$satPackage = Join-Path -Path $sat -ChildPath $satConfig.Filename
if(-not (Test-Path -Path $satPackage)) {
    Get-ChildItem -Path $sat -Recurse | Remove-Item -Recurse

    Write-Host "Downloading $($satConfig.Filename)"
    $webClient = New-Object System.Net.WebClient
    $webClient.Downloadfile($satConfig.Url, $satPackage)
    
    Write-Host "Unblocking $($satConfig.Filename)"
    Unblock-File -Path $satPackage

    Expand-Archive -Path $satPackage -DestinationPath $sat
}

Import-Module -Name (Join-Path -Path $sat -ChildPath "tools\Sitecore.Cloud.Cmdlets.dll")

$packages = Get-ChildItem -Path $releases -Filter "*.zip" | 
    Where-Object { $_.Extension -ne ".scwdp.zip" } | 
    Select-Object -ExpandProperty FullName

$destination = "$($releases)\"

function Test-ValidModulePackage {
    param(
        [string]$Path
    )

    $isModulePackage = $false
    Add-Type -AssemblyName "System.IO.Compression.FileSystem"
    $zip = [System.IO.Compression.ZipFile]::Open($Path, [System.IO.Compression.ZipArchiveMode]::Read)
    $packageZipEntry = $zip.Entries | Where-Object { $_.Name -eq "package.zip" }

    if($packageZipEntry) {
        $isModulePackage = $true
    }
    $zip.Dispose()

    $isModulePackage
}

foreach($package in $packages) {
    if(-not (Test-ValidModulePackage -Path $package)) {
        continue
    }

    Write-Host "Converting $([System.IO.Path]::GetFileNameWithoutExtension($package))"
    $wdpPath = ConvertTo-SCModuleWebDeployPackage -Path $package  -Destination $destination -DisableDacPacOptions '*' -Force
    
    Write-Host ""
}

docker compose up -d

docker exec --user ContainerAdministrator test-mssql-1 powershell C:\releases\sql.ps1
docker exec --user ContainerAdministrator test-cm-1 powershell C:\releases\cm.ps1