Write-Host "Performing file cleanup" -ForegroundColor Yellow

# Clean data folders
Write-Host "- Cleaning data folders"
Get-ChildItem -Path (Join-Path $PSScriptRoot "\data") -Directory | ForEach-Object {
    $dataPath = $_.FullName

    Get-ChildItem -Path $dataPath -Exclude ".gitkeep" -Recurse | Remove-Item -Force -Recurse
}

# Clean deploy folders
Write-Host "- Cleaning deploy folders"
Get-Item -Path (Join-Path $PSScriptRoot "\deploy\*") -Exclude ".gitkeep" | Remove-Item -Force -Recurse

# Clean build folders
Write-Host "- Cleaning build folders"
Get-Item -Path (Join-Path $PSScriptRoot "\build\cm\content\*") -Exclude ".gitkeep" | Remove-Item -Force -Recurse
Get-Item -Path (Join-Path $PSScriptRoot "\build\mssql-init\db\*") -Exclude ".gitkeep" | Remove-Item -Force -Recurse