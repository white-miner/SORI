# Maps Windows User/Process public-data keys to flutter --dart-define.
# Never prints key values.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Find-Key([string]$name) {
  foreach ($scope in @('Process', 'User', 'Machine')) {
    $v = [Environment]::GetEnvironmentVariable($name, $scope)
    if (-not [string]::IsNullOrEmpty($v)) { return $v }
  }
  return $null
}

$aliases = @(
  'PUBLIC_DATA_SERVICE_KEY',
  'DATA_GO_KR_SERVICE_KEY',
  'SBIZ_STORE_SERVICE_KEY',
  'SERVICE_KEY',
  'PUBLIC_DATA_API_KEY'
)

$defines = @()
$found = $false
foreach ($n in $aliases) {
  $val = Find-Key $n
  if ($val) {
    $defines += "--dart-define=$n=$val"
    $found = $true
    Write-Host ("configured {0} PRESENT length={1}" -f $n, $val.Length)
    break
  }
}
$demo = Find-Key 'USE_DEMO_MARKET_DATA'
if ($demo) { $defines += "--dart-define=USE_DEMO_MARKET_DATA=$demo" }

if (-not $found) {
  Write-Host 'public_data configured=false (Edge proxy may still serve LIVE)'
}

$cmd = $args
if ($cmd.Count -eq 0) {
  $cmd = @('test', 'test/public_data_client_test.dart', 'test/target_revenue_calc_test.dart', 'test/market_diagnosis_engine_test.dart', 'test/market_strategy_flow_test.dart')
}
& flutter @cmd @defines
exit $LASTEXITCODE
