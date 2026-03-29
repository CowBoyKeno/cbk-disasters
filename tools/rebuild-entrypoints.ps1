$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

function Join-ContentFiles {
    param(
        [string[]]$Paths
    )

    return (($Paths | ForEach-Object {
        Get-Content -LiteralPath (Join-Path $repoRoot $_) -Raw
    }) -join "`r`n`r`n")
}

$sharedFiles = @(
    'shared/config.lua',
    'shared/disasters.lua',
    'shared/config/heatwave.lua',
    'shared/config/thunderstorm.lua',
    'shared/config/tornado.lua',
    'shared/config/blizzard.lua',
    'shared/config/duststorm.lua',
    'shared/config/wildfire_smoke.lua'
)

$clientFiles = @(
    'client/modules/core.lua',
    'client/modules/effects.lua',
    'client/modules/hazards.lua'
)

$clientMainTail = Get-Content -LiteralPath (Join-Path $repoRoot 'client/main.lua') -Raw
$clientMarker = 'CreateThread(function()'
$clientIndex = $clientMainTail.IndexOf($clientMarker)
if ($clientIndex -lt 0) {
    throw 'Unable to find the client main runtime marker.'
}

$clientRuntime = $clientMainTail.Substring($clientIndex)
$clientCompatibilityShim = @"
function waitForClientModules()
    return true
end
"@
$clientBundle = @(
    Join-ContentFiles -Paths $sharedFiles
    Join-ContentFiles -Paths $clientFiles
    $clientCompatibilityShim
    $clientRuntime
) -join "`r`n`r`n"

Set-Content -LiteralPath (Join-Path $repoRoot 'client/main.lua') -Value $clientBundle

$serverConfigFiles = @(
    'server/config.lua'
)

$serverFiles = @(
    'server/modules/bootstrap.lua',
    'server/modules/panel.lua',
    'server/modules/core.lua'
)

$serverMainTail = Get-Content -LiteralPath (Join-Path $repoRoot 'server/main.lua') -Raw
$serverMarker = "RegisterNetEvent('cbk_disasters:server:requestState', function()"
$serverIndex = $serverMainTail.IndexOf($serverMarker)
if ($serverIndex -lt 0) {
    throw 'Unable to find the server main runtime marker.'
}

$serverRuntime = $serverMainTail.Substring($serverIndex)
$serverBundle = @(
    Join-ContentFiles -Paths $sharedFiles
    Join-ContentFiles -Paths $serverConfigFiles
    Join-ContentFiles -Paths $serverFiles
    $serverRuntime
) -join "`r`n`r`n"

Set-Content -LiteralPath (Join-Path $repoRoot 'server/main.lua') -Value $serverBundle

Write-Host 'Rebuilt client/main.lua and server/main.lua from module sources.'
