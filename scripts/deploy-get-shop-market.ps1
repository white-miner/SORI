# Deploy get-shop-market Edge Function (run from anywhere).
# Usage:
#   $env:SUPABASE_ACCESS_TOKEN = "<token>"
#   .\scripts\deploy-get-shop-market.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path "$root\supabase\functions\get-shop-market\index.ts")) {
  Write-Error "Missing function file under $root\supabase\functions\get-shop-market\index.ts"
}

$sb = "$env:USERPROFILE\.local\bin\supabase.exe"
if (-not (Test-Path $sb)) {
  $sb = "supabase"
}

if (-not $env:SUPABASE_ACCESS_TOKEN) {
  Write-Error "Set SUPABASE_ACCESS_TOKEN first (Dashboard → Account → Access Tokens). Do not paste the token into chat."
}

Write-Host "Deploying from: $root"
& $sb functions deploy get-shop-market `
  --project-ref tieojdbzmqcmlwyqltrk `
  --workdir $root `
  --use-api
