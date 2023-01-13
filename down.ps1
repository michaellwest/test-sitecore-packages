param(
    [switch]$Cleanup
)
docker compose down --remove-orphans

if($Cleanup) {
    .\clean.ps1
}