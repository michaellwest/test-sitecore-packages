[CmdletBinding()]
param(
    [switch]$IncludeSps,
    [switch]$IncludeSpe,
    [switch]$IncludeSxa,
    [switch]$IncludePackages
)

$releases = Join-Path -Path $PSScriptRoot -ChildPath ".\docker\build\releases"
$extract = Join-Path -Path $releases -ChildPath "extract"
$content = Join-Path -Path $PSScriptRoot -ChildPath ".\docker\build\cm\content"
$db = Join-Path -Path $PSScriptRoot -ChildPath ".\docker\build\mssql-init\db"

if(-not (Test-Path -Path $extract)) {
    New-Item -Path $extract -ItemType Directory > $null
}

Remove-Item -Path "$($content)\*" -Recurse
Remove-Item -Path "$($db)\*" -Recurse

if($IncludePackages) {
    $counter = 0
    $archives = Get-ChildItem -Path "$($releases)\*.zip"
    foreach($archive in $archives) {
        Remove-Item -Path "$($extract)\*" -Recurse
        if($archive.Name.EndsWith(".scwdp.zip")) {
            $archive | Expand-Archive -DestinationPath $extract -Force
            Copy-Item -Path "$($extract)\Content\Website\*" -Destination $content -Recurse -Force
        } elseif($archive.Name.EndsWith(".zip")) {
            $archive | Expand-Archive -DestinationPath $extract -Force
            Copy-Item -Path "$($extract)\*" -Destination $content -Recurse -Force
        }

        $dacpacs = Get-ChildItem -Path $extract -Filter "*.dacpac"
        if($dacpacs) {
            $databaseDirectory = Join-Path -Path $db -ChildPath "$($counter.ToString('D2'))"
            New-Item -Path $databaseDirectory -ItemType Directory > $null
            if (Test-Path("$($extract)\core.dacpac")) {
                Copy-Item -Path "$($extract)\core.dacpac" -Destination $databaseDirectory -PassThru
                Rename-Item -Path "$($databaseDirectory)\core.dacpac" -NewName "Sitecore.Core.dacpac"
            }
            
            if (Test-Path("$($extract)\master.dacpac")) {
                Copy-Item -Path "$($extract)\master.dacpac" -Destination $databaseDirectory -PassThru
                Rename-Item -Path "$($databaseDirectory)\master.dacpac" -NewName "Sitecore.Master.dacpac"
            }
        }

        $counter++
    }
}

$composeArgs = @("compose", "-f", ".\docker-compose.yml")

if(Test-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "docker-compose.override.yml")) {
    $composeArgs += "-f"
    $composeArgs += ".\docker-compose.override.yml"
}

$composeArgs += "-f"
$composeArgs += ".\docker-compose.build.yml"

if($IncludeSps) {
    $composeArgs += "-f"
    $composeArgs += ".\docker-compose.sps.yml"
}

if($IncludeSpe -or $IncludeSxa) {
    $composeArgs += "-f"
    $composeArgs += ".\docker-compose.spe.yml"
}

if($IncludeSxa) {
    $composeArgs += "-f"
    $composeArgs += ".\docker-compose.sxa.yml"
}

Write-Host Building
docker $composeArgs build