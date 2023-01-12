param(
    [switch]$Cleanup
)
docker compose down --remove-orphans

if($Cleanup) {
    .\docker\clean.ps1
}