local currentState = nil
local lastReminder = 0
local weatherAppliedAt = 0
local stateStartedAtMs = 0
local panelData = nil
local panelOpen = false
local activeSmokeHandles = {}
local activeFireHandles = {}
local wildfireAnchor = nil
local wildfireSignature = nil
local lastAlertSeq = nil
local tornadoFxHandles = {}
local tornadoFunnelFxHandles = {}
local tornadoFunnelFxNodes = {}
local tornadoFxSignature = nil
local nextTornadoDebrisAt = 0
local nextTornadoFunnelRefreshAt = 0
local tornadoFunnelGroundZ = nil
local tornadoFunnelGroundRefreshAt = 0
local blizzardSnowParticles = {}
local lastAppliedWeatherType = nil
local lastAppliedWeatherTransition = nil
local lastAppliedRainLevel = nil
local lastAppliedWindSpeed = nil
local lastAppliedTimecycle = nil
local lastAppliedTimecycleStrength = nil
local lastAppliedSnowPass = nil
local lastAppliedSnowLevel = nil
local lastAppliedVehicleTrails = nil
local lastAppliedPedTracks = nil
local forcedTornadoZone = nil
local forcedTornadoZoneUpdatedAt = 0
local forcedTornadoZonePredictionWindowMs = 0
local forcedTornadoZoneVelocityX = 0.0
local forcedTornadoZoneVelocityY = 0.0
local forcedTornadoZoneVelocityZ = 0.0
local tornadoDebugEnabled = false
local tornadoInteractionLastAudioVolume = -1.0
local tornadoInteractionLastShakeAt = 0
local tornadoInteractionLastDamageAt = 0
local tornadoLiftEntityStates = {}
local tornadoDebrisPool = {}
local tornadoDebrisModelCycle = 1
local zoneRadiusBlip = nil
local zoneCenterBlip = nil
local getSmokeDensity
local getZoneIntensity
local getStateIntensity
local removeSmoke
local stopTornadoFx
local cleanupTornadoDebrisPool
local clearTornadoLiftEntityStates
local setTornadoWindAudio
local ensurePtfxAsset

local smokeOffsets = {
    { x = 0.0, y = 0.0 },
    { x = 7.0, y = 4.0 },
    { x = -6.5, y = 5.5 },
    { x = 8.5, y = -4.5 },
    { x = -7.5, y = -5.5 },
    { x = 3.5, y = -8.5 },
}

local function getStateHazard(state)
    if not state then
        return nil
    end

    local hazard = state.hazard
    if type(hazard) == 'string' and hazard ~= '' then
        return hazard
    end

    if state.context and type(state.context.hazard) == 'string' and state.context.hazard ~= '' then
        return state.context.hazard
    end

    if type(state.key) == 'string' and state.key ~= '' then
        return state.key
    end

    return nil
end

local function getCurrentUnixTime()
    local cloudTime = GetCloudTimeAsInt()
    if type(cloudTime) == 'number' and cloudTime > 0 then
        return cloudTime
    end

    return 0
end

local function getDisasterProgress(state)
    if not state then
        return 0.0
    end

    local duration = tonumber(state.durationSeconds) or 0
    if duration <= 0 then
        return 1.0
    end

    local unixTime = getCurrentUnixTime()
    if unixTime > 0 and state.startedAt then
        return math.max(0.0, math.min(1.0, (unixTime - state.startedAt) / duration))
    end

    if stateStartedAtMs > 0 then
        local elapsedSec = (GetGameTimer() - stateStartedAtMs) / 1000.0
        return math.max(0.0, math.min(1.0, elapsedSec / duration))
    end

    return 0.0
end

local function notify(message, playSound)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(playSound == true, false)
end

local function nearlyEqual(a, b, epsilon)
    local left = tonumber(a)
    local right = tonumber(b)
    if left == nil or right == nil then
        return left == right
    end

    return math.abs(left - right) <= (epsilon or 0.001)
end

local function getBlizzardWindState(cfg, intensity)
    local nowSec = GetGameTimer() / 1000.0
    local gust = math.sin(nowSec * (cfg.windGustSpeed or 0.70)) * (cfg.windGustAmplitude or 0.34)
    local microGust = math.cos(nowSec * (cfg.windMicroGustSpeed or 1.85)) * (cfg.windMicroGustAmplitude or 0.12)
    local swing = gust + microGust
    local directionDegrees = (cfg.windBaseDirection or 235.0) + (swing * (cfg.windSwingDegrees or 44.0))
    local baseWindSpeed = cfg.windBaseSpeed or 1.10
    local maxWindSpeed = math.max(baseWindSpeed, cfg.windMaxSpeed or 1.95)
    local windSpeed = math.min(
        maxWindSpeed,
        baseWindSpeed + ((maxWindSpeed - baseWindSpeed) * intensity) + math.max(0.0, gust * 0.35)
    )

    return gust, directionDegrees, math.rad(directionDegrees), windSpeed
end

local function stopBlizzardFx()
    blizzardSnowParticles = {}

    if SetWindDirection then
        pcall(SetWindDirection, 0.0)
    end
end

local function getBlizzardVisualIntensity(zone)
    if zone and zone.coords then
        return getZoneIntensity(zone)
    end

    return getStateIntensity(currentState)
end

local function updateBlizzardFx(zone)
    local intensity = getBlizzardVisualIntensity(zone)
    if intensity <= 0.0 then
        stopBlizzardFx()
        return
    end

    local cfg = Config.ClientFx.blizzard or {}
    local _, _, directionRad, windSpeed = getBlizzardWindState(cfg, intensity)
    if SetWindDirection then
        pcall(SetWindDirection, directionRad)
    end
    SetWindSpeed(windSpeed)

    if cfg.enableGlobalSnowCover == true then
        if cfg.forceSnowPass ~= false and ForceSnowPass then
            pcall(ForceSnowPass, true)
        end

        if _SET_SNOW_LEVEL then
            local minSnowLevel = cfg.snowLevelMin or 0.40
            local maxSnowLevel = math.max(minSnowLevel, cfg.snowLevelMax or 1.00)
            local snowLevel = minSnowLevel + ((maxSnowLevel - minSnowLevel) * intensity)
            pcall(_SET_SNOW_LEVEL, snowLevel)
        end
    end
end

local function respawnBlizzardSnowParticle(index, cfg, intensity, topOnly, windX, windY)
    local radius = (cfg.particleRadius or 28.0) * (0.90 + (intensity * 0.35))
    local minHeight = cfg.particleHeightMin or 3.0
    local maxHeight = math.max(minHeight + 1.0, cfg.particleHeightMax or 26.0)
    local particleX
    local particleY

    if topOnly and windX and windY then
        local rightX = -windY
        local rightY = windX
        local lateral = ((math.random() * 2.0) - 1.0) * radius
        local upwindDistance = radius * (0.72 + (math.random() * 0.18))
        local jitter = radius * 0.10
        particleX = (-windX * upwindDistance) + (rightX * lateral) + (((math.random() * 2.0) - 1.0) * jitter)
        particleY = (-windY * upwindDistance) + (rightY * lateral) + (((math.random() * 2.0) - 1.0) * jitter)
    else
        local angle = math.random() * math.pi * 2.0
        local nearBias = math.max(1.0, tonumber(cfg.particleNearBias) or 1.45)
        local distance = (math.random() ^ nearBias) * radius
        particleX = math.cos(angle) * distance
        particleY = math.sin(angle) * distance
    end

    blizzardSnowParticles[index] = {
        x = particleX,
        y = particleY,
        z = topOnly and maxHeight or (minHeight + (math.random() * (maxHeight - minHeight))),
        fallSpeed = (cfg.particleFallSpeedMin or 14.0) + (math.random() * ((cfg.particleFallSpeedMax or 26.0) - (cfg.particleFallSpeedMin or 14.0))),
        driftScale = 0.75 + (math.random() * 0.55),
        trailLength = (cfg.particleTrailMin or 0.18) + (math.random() * ((cfg.particleTrailMax or 0.42) - (cfg.particleTrailMin or 0.18))),
        flutterPhase = math.random() * math.pi * 2.0,
        flutterSpeed = 2.4 + (math.random() * 2.8),
        flutterAmount = 0.015 + (math.random() * 0.055),
        alphaScale = 0.72 + (math.random() * 0.28)
    }
end

local function updateBlizzardSnow(zone)
    local intensity = getBlizzardVisualIntensity(zone)
    if intensity <= 0.0 then
        blizzardSnowParticles = {}
        return
    end

    local cfg = Config.ClientFx.blizzard or {}
    local minCount = math.max(24, math.floor(cfg.particleCountMin or 90))
    local maxCount = math.max(minCount, math.floor(cfg.particleCountMax or 180))
    local targetCount = math.floor(minCount + ((maxCount - minCount) * math.max(0.92, intensity)))
    local _, _, directionRad, windSpeed = getBlizzardWindState(cfg, intensity)
    local windX = math.cos(directionRad)
    local windY = math.sin(directionRad)
    local dt = math.max(0.001, GetFrameTime())
    local playerCoords = GetEntityCoords(PlayerPedId())
    local radius = (cfg.particleRadius or 28.0) * (0.90 + (intensity * 0.35))
    local minHeight = cfg.particleHeightMin or 3.0
    local maxHeight = math.max(minHeight + 1.0, cfg.particleHeightMax or 26.0)
    local driftScale = cfg.particleWindDriftScale or 13.0
    local color = cfg.particleColor or { r = 240, g = 245, b = 255 }
    local alpha = math.min(255, math.max(40, math.floor((cfg.particleAlpha or 200) * (0.75 + (0.25 * intensity)))))
    local timeSec = GetGameTimer() / 1000.0
    local rightX = -windY
    local rightY = windX

    for i = #blizzardSnowParticles + 1, targetCount do
        respawnBlizzardSnowParticle(i, cfg, intensity, false, windX, windY)
    end

    for i = #blizzardSnowParticles, targetCount + 1, -1 do
        blizzardSnowParticles[i] = nil
    end

    for i = 1, targetCount do
        local particle = blizzardSnowParticles[i]
        if not particle then
            respawnBlizzardSnowParticle(i, cfg, intensity, false, windX, windY)
            particle = blizzardSnowParticles[i]
        end

        particle.x = particle.x + (windX * windSpeed * driftScale * particle.driftScale * dt)
        particle.y = particle.y + (windY * windSpeed * driftScale * particle.driftScale * dt)
        particle.z = particle.z - (particle.fallSpeed * dt)

        local radialDistance = math.sqrt((particle.x * particle.x) + (particle.y * particle.y))
        if particle.z <= minHeight or radialDistance > (radius * 1.15) then
            respawnBlizzardSnowParticle(i, cfg, intensity, true, windX, windY)
            particle = blizzardSnowParticles[i]
        end

        local worldX = playerCoords.x + particle.x
        local worldY = playerCoords.y + particle.y
        local worldZ = playerCoords.z + particle.z
        local flutterWave = math.sin((timeSec * particle.flutterSpeed) + particle.flutterPhase)
        local flutterAmount = particle.flutterAmount * (0.45 + (0.55 * intensity))
        local flutterX = rightX * flutterWave * flutterAmount
        local flutterY = rightY * flutterWave * flutterAmount
        local flutterZ = math.cos((timeSec * (particle.flutterSpeed * 0.8)) + particle.flutterPhase) * flutterAmount * 0.22
        local flakeX = worldX + flutterX
        local flakeY = worldY + flutterY
        local flakeZ = worldZ + flutterZ
        local trailLength = particle.trailLength * (0.48 + (0.20 * intensity))
        local streakAlpha = math.max(10, math.floor(alpha * particle.alphaScale * 0.82))
        local tailLength = trailLength * 0.40

        DrawLine(
            flakeX,
            flakeY,
            flakeZ,
            flakeX - (windX * trailLength * 0.20) + (rightX * flutterAmount * 0.12),
            flakeY - (windY * trailLength * 0.20) + (rightY * flutterAmount * 0.12),
            flakeZ + (trailLength * 0.28),
            color.r,
            color.g,
            color.b,
            streakAlpha
        )

        DrawLine(
            flakeX + (rightX * flutterAmount * 0.20),
            flakeY + (rightY * flutterAmount * 0.20),
            flakeZ - (trailLength * 0.03),
            flakeX - (windX * tailLength * 0.14) - (rightX * flutterAmount * 0.08),
            flakeY - (windY * tailLength * 0.14) - (rightY * flutterAmount * 0.08),
            flakeZ + (tailLength * 0.18),
            color.r,
            color.g,
            color.b,
            math.max(6, math.floor(streakAlpha * 0.22))
        )
    end
end

RegisterNetEvent('cbk_disasters:client:notify', function(message, playSound)
    notify(message, playSound)
end)

local function closePanel()
    if not panelOpen then return end
    panelOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hidePanel' })
    TriggerServerEvent('cbk_disasters:server:panelClosed')
end

local function openPanel(data)
    if data ~= nil then
        panelData = data
    end

    if panelOpen then
        SendNUIMessage({ action = 'setData', data = panelData })
        return
    end

    panelOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'showPanel' })
    SendNUIMessage({ action = 'setData', data = panelData })
end

RegisterNUICallback('closePanel', function(_, cb)
    closePanel()
    cb('ok')
end)

RegisterNUICallback('requestPanelData', function(_, cb)
    TriggerServerEvent('cbk_disasters:server:requestPanelData')
    cb('ok')
end)

RegisterNetEvent('cbk_disasters:client:updatePanel', function(data)
    panelData = data
    if panelOpen then
        SendNUIMessage({ action = 'setData', data = panelData })
    end
end)

RegisterNetEvent('cbk_disasters:client:openPanel', function(data)
    openPanel(data)
end)

RegisterNUICallback('startDisaster', function(data, cb)
    if data and type(data.key) == 'string' then
        TriggerServerEvent('cbk_disasters:server:startDisasterFromPanel', { key = data.key })
    end
    cb('ok')
end)

RegisterNUICallback('stopDisaster', function(_, cb)
    TriggerServerEvent('cbk_disasters:server:stopDisasterFromPanel')
    cb('ok')
end)

RegisterNUICallback('updateDisasterTimes', function(data, cb)
    if data and type(data.key) == 'string' then
        TriggerServerEvent('cbk_disasters:server:updateDisasterTimesFromPanel', data)
    end
    cb('ok')
end)

local function resetWeather()
    StopGameplayCamShaking(true)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetRainLevel(0.0)
    SetWindSpeed(0.0)
    if ForceSnowPass then
        pcall(ForceSnowPass, false)
    end
    if _SET_SNOW_LEVEL then
        pcall(_SET_SNOW_LEVEL, 0.0)
    end
    if SetWindDirection then
        pcall(SetWindDirection, 0.0)
    end
    SetForceVehicleTrails(false)
    SetForcePedFootstepsTracks(false)
    SetTimecycleModifier('default')
    SetTimecycleModifierStrength(0.0)
    StopAllScreenEffects()
    lastAppliedWeatherType = nil
    lastAppliedWeatherTransition = nil
    lastAppliedRainLevel = nil
    lastAppliedWindSpeed = nil
    lastAppliedTimecycle = nil
    lastAppliedTimecycleStrength = nil
    lastAppliedSnowPass = nil
    lastAppliedSnowLevel = nil
    lastAppliedVehicleTrails = nil
    lastAppliedPedTracks = nil
end

local function getTimecycleModifier(key)
    return DisasterTimecycles[key] or DisasterTimecycles.default
end

local function removeZoneBlips()
    if zoneRadiusBlip and DoesBlipExist(zoneRadiusBlip) then
        RemoveBlip(zoneRadiusBlip)
    end

    if zoneCenterBlip and DoesBlipExist(zoneCenterBlip) then
        RemoveBlip(zoneCenterBlip)
    end

    zoneRadiusBlip = nil
    zoneCenterBlip = nil
end

local function updateZoneBlips(state)
    removeZoneBlips()

    local cfg = Config.ClientFx.zoneBlip or {}
    local zone = state and state.context and state.context.zone
    if cfg.enabled == false or not zone then
        return
    end

    local radius = (zone.radius * (cfg.radiusMultiplier or 1.0)) + 0.0
    zoneRadiusBlip = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, radius)
    SetBlipColour(zoneRadiusBlip, cfg.radiusColor or 1)
    SetBlipAlpha(zoneRadiusBlip, cfg.radiusAlpha or 96)
    SetBlipHighDetail(zoneRadiusBlip, true)
    SetBlipAsShortRange(zoneRadiusBlip, cfg.shortRange == true)

    zoneCenterBlip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
    SetBlipSprite(zoneCenterBlip, cfg.centerSprite or 161)
    SetBlipColour(zoneCenterBlip, cfg.centerColor or cfg.radiusColor or 1)
    SetBlipScale(zoneCenterBlip, cfg.centerScale or 1.0)
    SetBlipAsShortRange(zoneCenterBlip, cfg.shortRange == true)
    SetBlipDisplay(zoneCenterBlip, 4)

    if cfg.flashes ~= false then
        SetBlipFlashes(zoneCenterBlip, true)
        SetBlipFlashTimer(zoneCenterBlip, cfg.flashTimerMs or 15000)
    end

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('%s Area'):format(state.label or Config.Locale.fallbackEventName))
    EndTextCommandSetBlipName(zoneCenterBlip)
end

local function syncZoneBlipPosition(zone)
    if not zone or not zone.coords then
        return
    end

    if zoneRadiusBlip and DoesBlipExist(zoneRadiusBlip) then
        SetBlipCoords(zoneRadiusBlip, zone.coords.x, zone.coords.y, zone.coords.z)
    end

    if zoneCenterBlip and DoesBlipExist(zoneCenterBlip) then
        SetBlipCoords(zoneCenterBlip, zone.coords.x, zone.coords.y, zone.coords.z)
    end
end

local function applyDisasterWeather(state)
    if not state then
        resetWeather()
        return
    end

    local hazard = getStateHazard(state)
    local targetWeather = state.weather
    local blizzardAccumulation = 0.0
    local blizzardCfg = Config.ClientFx.blizzard or {}
    if hazard == 'blizzard' then
        local progress = getDisasterProgress(state)
        local zoneIntensity = getStateIntensity(state)
        local allowGlobalSnowCover = blizzardCfg.enableGlobalSnowCover == true
        local fogStrength = math.max(0.0, math.min(1.0, tonumber(blizzardCfg.fogStrength) or 0.0))
        local buildupThreshold = 0.02 + (0.22 * fogStrength)
        local snowCoverThreshold = math.max(blizzardCfg.snowCoverThreshold or 0.10, 0.12 + (0.68 * fogStrength))
        blizzardAccumulation = math.max(0.0, math.min(1.0, (progress * 0.72) + (zoneIntensity * 0.28)))

        if allowGlobalSnowCover and blizzardAccumulation >= snowCoverThreshold then
            targetWeather = blizzardCfg.snowCoverWeather or 'XMAS'
        elseif blizzardAccumulation >= buildupThreshold then
            targetWeather = blizzardCfg.buildupWeather or 'SNOW'
        else
            targetWeather = blizzardCfg.earlyWeather or 'SNOWLIGHT'
        end

        local showTracks = blizzardAccumulation >= (blizzardCfg.trackThreshold or 0.02)
        if lastAppliedVehicleTrails ~= showTracks then
            SetForceVehicleTrails(showTracks)
            lastAppliedVehicleTrails = showTracks
        end
        if lastAppliedPedTracks ~= showTracks then
            SetForcePedFootstepsTracks(showTracks)
            lastAppliedPedTracks = showTracks
        end

        local shouldForceSnowPass = allowGlobalSnowCover and blizzardCfg.forceSnowPass ~= false
        if ForceSnowPass and lastAppliedSnowPass ~= shouldForceSnowPass then
            pcall(ForceSnowPass, shouldForceSnowPass)
            lastAppliedSnowPass = shouldForceSnowPass
        end

        if allowGlobalSnowCover and _SET_SNOW_LEVEL then
            local minSnowLevel = blizzardCfg.snowLevelMin or 0.40
            local maxSnowLevel = math.max(minSnowLevel, blizzardCfg.snowLevelMax or 1.00)
            local snowLevel = minSnowLevel + ((maxSnowLevel - minSnowLevel) * blizzardAccumulation)
            if not nearlyEqual(lastAppliedSnowLevel, snowLevel, 0.01) then
                pcall(_SET_SNOW_LEVEL, snowLevel)
                lastAppliedSnowLevel = snowLevel
            end
        elseif ForceSnowPass then
            if lastAppliedSnowPass ~= false then
                pcall(ForceSnowPass, false)
                lastAppliedSnowPass = false
            end
            if _SET_SNOW_LEVEL then
                if not nearlyEqual(lastAppliedSnowLevel, 0.0, 0.01) then
                    pcall(_SET_SNOW_LEVEL, 0.0)
                    lastAppliedSnowLevel = 0.0
                end
            end
        end
    else
        if ForceSnowPass and lastAppliedSnowPass ~= false then
            pcall(ForceSnowPass, false)
            lastAppliedSnowPass = false
        end
        if _SET_SNOW_LEVEL then
            if not nearlyEqual(lastAppliedSnowLevel, 0.0, 0.01) then
                pcall(_SET_SNOW_LEVEL, 0.0)
                lastAppliedSnowLevel = 0.0
            end
        end
        if lastAppliedVehicleTrails ~= false then
            SetForceVehicleTrails(false)
            lastAppliedVehicleTrails = false
        end
        if lastAppliedPedTracks ~= false then
            SetForcePedFootstepsTracks(false)
            lastAppliedPedTracks = false
        end
    end

    local weatherTransition = hazard == 'blizzard' and (blizzardCfg.weatherTransitionSeconds or 4.0) or 30.0
    if lastAppliedWeatherType ~= targetWeather or not nearlyEqual(lastAppliedWeatherTransition, weatherTransition, 0.01) then
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        SetWeatherTypeOvertimePersist(targetWeather, weatherTransition)
        SetWeatherTypeNowPersist(targetWeather)
        SetWeatherTypePersist(targetWeather)
        lastAppliedWeatherType = targetWeather
        lastAppliedWeatherTransition = weatherTransition
    end

    local rainLevel = state.rainLevel or 0.0
    if not nearlyEqual(lastAppliedRainLevel, rainLevel, 0.01) then
        SetRainLevel(rainLevel)
        lastAppliedRainLevel = rainLevel
    end

    local windSpeed = state.windSpeed or 0.0
    if hazard == 'blizzard' then
        local baseWind = math.max(state.windSpeed or 0.0, blizzardCfg.weatherWindBase or 1.05)
        windSpeed = baseWind + (blizzardAccumulation * (blizzardCfg.weatherWindExtra or 0.80))
    end

    if not nearlyEqual(lastAppliedWindSpeed, windSpeed, 0.01) then
        SetWindSpeed(windSpeed)
        lastAppliedWindSpeed = windSpeed
    end

    local tc = getTimecycleModifier(state.timecycle)
    if tc then
        local intensity = getStateIntensity(state)
        local strength = 0.22 + (intensity * 0.45)
        if hazard == 'wildfire_smoke' and state.context and state.context.zone and getSmokeDensity then
            strength = 0.45 + (getSmokeDensity(state.context.zone) * 0.55)
        elseif hazard == 'tornado' then
            strength = 0.28 + (intensity * 0.62)
        elseif hazard == 'blizzard' then
            strength = 0.28 + (blizzardAccumulation * 0.72) + ((blizzardCfg.timecycleBoost or 0.14) * intensity) + (blizzardCfg.fogStrength or 0.0)
        elseif state.context and state.context.zone then
            strength = 0.18 + (intensity * 0.55)
        end

        if lastAppliedTimecycle ~= tc then
            SetTimecycleModifier(tc)
            lastAppliedTimecycle = tc
            lastAppliedTimecycleStrength = nil
        end
        if not nearlyEqual(lastAppliedTimecycleStrength, strength, 0.01) then
            SetTimecycleModifierStrength(strength)
            lastAppliedTimecycleStrength = strength
        end
    else
        if lastAppliedTimecycle ~= 'default' then
            SetTimecycleModifier('default')
            lastAppliedTimecycle = 'default'
            lastAppliedTimecycleStrength = nil
        end
        if not nearlyEqual(lastAppliedTimecycleStrength, 0.0, 0.01) then
            SetTimecycleModifierStrength(0.0)
            lastAppliedTimecycleStrength = 0.0
        end
    end
end

local function playAlertTone()
    local cfg = Config.ClientFx.alertSound or {}
    if cfg.enabled == false then
        return
    end

    if cfg.useNuiSiren ~= false then
        SendNUIMessage({
            action = 'playAlertTone',
            config = {
                durationMs = cfg.sirenDurationMs or 2600,
                volume = cfg.sirenVolume or 0.18,
                mode = cfg.mode or 'bulletin',
                bulletinLowHz = cfg.bulletinLowHz or 853,
                bulletinHighHz = cfg.bulletinHighHz or 960,
                bulletinOnMs = cfg.bulletinOnMs or 950,
                bulletinOffMs = cfg.bulletinOffMs or 260,
                bulletinCycles = cfg.bulletinCycles or 4,
                bulletinStaticMs = cfg.bulletinStaticMs or 120
            }
        })
    end

    if cfg.useFrontendFallback == true then
        local pulses = math.max(1, tonumber(cfg.pulses) or 1)
        local intervalMs = math.max(75, tonumber(cfg.intervalMs) or 180)
        local baseName = cfg.name or '5_SEC_WARNING'
        local baseSet = cfg.set or 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS'

        for i = 1, pulses do
            SetTimeout((i - 1) * intervalMs, function()
                PlaySoundFrontend(-1, baseName, baseSet, true)
            end)
        end

        if cfg.finalName and cfg.finalName ~= '' then
            SetTimeout(pulses * intervalMs, function()
                PlaySoundFrontend(-1, cfg.finalName, cfg.finalSet or baseSet, true)
            end)
        end
    end
end

local function setState(state)
    if state then
        local hazard = getStateHazard(state)
        if hazard then
            state.hazard = hazard
            state.context = state.context or {}
            state.context.hazard = state.context.hazard or hazard
        end
    end

    currentState = state
    weatherAppliedAt = 0
    if state then
        stateStartedAtMs = GetGameTimer()
        local hazard = getStateHazard(state)
        if hazard ~= 'tornado' then
            forcedTornadoZone = nil
            forcedTornadoZoneUpdatedAt = 0
            forcedTornadoZonePredictionWindowMs = 0
            forcedTornadoZoneVelocityX = 0.0
            forcedTornadoZoneVelocityY = 0.0
            forcedTornadoZoneVelocityZ = 0.0
        end
        if hazard ~= 'blizzard' then
            stopBlizzardFx()
        end
    else
        stateStartedAtMs = 0
        forcedTornadoZone = nil
        forcedTornadoZoneUpdatedAt = 0
        forcedTornadoZonePredictionWindowMs = 0
        forcedTornadoZoneVelocityX = 0.0
        forcedTornadoZoneVelocityY = 0.0
        forcedTornadoZoneVelocityZ = 0.0
    end
    updateZoneBlips(currentState)

    if currentState then
        local alertSeq = currentState.seq or currentState.startedAt or currentState.key
        if lastAlertSeq ~= alertSeq then
            playAlertTone()
            lastAlertSeq = alertSeq
        end
        notify(currentState.announcement, Config.Announcements.useFeedSound)
    else
        lastAlertSeq = nil
        removeZoneBlips()
        stopBlizzardFx()
        stopTornadoFx()
        cleanupTornadoDebrisPool()
        clearTornadoLiftEntityStates()
        setTornadoWindAudio(0.0, {})
        removeSmoke()
        resetWeather()
        return
    end
end

local function getPredictedForcedTornadoZone()
    if not forcedTornadoZone or not forcedTornadoZone.coords then
        return nil
    end

    local maxPredictionMs = math.max(0, math.floor(forcedTornadoZonePredictionWindowMs or 0))
    if maxPredictionMs <= 0 then
        return forcedTornadoZone
    end

    local elapsedMs = GetGameTimer() - (forcedTornadoZoneUpdatedAt or 0)
    if elapsedMs <= 0 then
        return forcedTornadoZone
    end

    local clampedElapsedMs = math.min(elapsedMs, maxPredictionMs)
    if clampedElapsedMs <= 0 then
        return forcedTornadoZone
    end

    local dt = clampedElapsedMs / 1000.0
    return {
        name = forcedTornadoZone.name,
        radius = forcedTornadoZone.radius,
        coords = {
            x = forcedTornadoZone.coords.x + (forcedTornadoZoneVelocityX * dt),
            y = forcedTornadoZone.coords.y + (forcedTornadoZoneVelocityY * dt),
            z = forcedTornadoZone.coords.z + (forcedTornadoZoneVelocityZ * dt)
        }
    }
end

local function getActiveTornadoZone()
    local stateHazard = getStateHazard(currentState)
    local predictedForcedZone = getPredictedForcedTornadoZone()
    if stateHazard == 'tornado' and predictedForcedZone and predictedForcedZone.coords then
        return predictedForcedZone
    end

    if currentState and stateHazard == 'tornado' and currentState.context and currentState.context.zone and currentState.context.zone.coords then
        return currentState.context.zone
    end

    return nil
end

local function distanceBetween(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

getZoneIntensity = function(zone, radiusOverride)
    if not zone or not zone.coords then
        return 0.0
    end

    local pedCoords = GetEntityCoords(PlayerPedId())
    local radius = radiusOverride or zone.radius or 0.0
    if radius <= 0.0 then
        return 0.0
    end

    local dist = distanceBetween(pedCoords, zone.coords)
    if dist > radius then
        return 0.0
    end

    local intensityConfig = Config.Intensity or {}
    local minimum = intensityConfig.zoneMinimum or 0.12
    local exponent = intensityConfig.curveExponent or 0.80
    local raw = 1.0 - (dist / radius)
    local shaped = raw ^ exponent
    return math.max(minimum, math.min(1.0, shaped))
end

getStateIntensity = function(state)
    if not state then
        return 0.0
    end

    if state.context and state.context.zone then
        return getZoneIntensity(state.context.zone)
    end

    return 1.0
end

getSmokeDensity = function(zone)
    local cfg = Config.ClientFx.wildfireSmoke or {}
    local radius = cfg.maxDistance or (zone and zone.radius) or 400.0
    return getZoneIntensity(zone, radius)
end

local function drawDebugTextLine(x, y, text, r, g, b, a, scale)
    SetTextFont(0)
    SetTextProportional(true)
    SetTextScale(scale or 0.31, scale or 0.31)
    SetTextColour(r or 255, g or 255, b or 255, a or 220)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end

local function drawTornadoDebugHud()
    local zone = getActiveTornadoZone()
    local pedCoords = GetEntityCoords(PlayerPedId())
    local hasCurrent = currentState and 'yes' or 'no'
    local hazard = getStateHazard(currentState) or 'nil'
    local hasForced = (forcedTornadoZone and forcedTornadoZone.coords) and 'yes' or 'no'
    local zoneLine = 'zone: nil'
    local distLine = 'dist/intensity: n/a'

    if zone and zone.coords then
        local dist = distanceBetween(pedCoords, zone.coords)
        local intensity = getZoneIntensity(zone)
        zoneLine = ('zone: x=%.1f y=%.1f z=%.1f r=%.1f'):format(zone.coords.x + 0.0, zone.coords.y + 0.0, zone.coords.z + 0.0, (zone.radius or 0.0) + 0.0)
        distLine = ('dist/intensity: %.1f / %.3f'):format(dist, intensity)

        DrawMarker(28, zone.coords.x, zone.coords.y, zone.coords.z + 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.6, 2.6, 2.6, 0, 255, 80, 220, false, false, 2, false, nil, nil, false)
        DrawMarker(1, zone.coords.x, zone.coords.y, zone.coords.z - 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, (zone.radius or 1.0) * 2.0, (zone.radius or 1.0) * 2.0, 3.0, 0, 200, 255, 90, false, false, 2, false, nil, nil, false)
        DrawLine(pedCoords.x, pedCoords.y, pedCoords.z + 0.5, zone.coords.x, zone.coords.y, zone.coords.z + 2.0, 0, 255, 255, 255)
    end

    local lines = {
        '[CBK Tornado Debug]',
        ('currentState: %s | hazard: %s'):format(hasCurrent, hazard),
        ('forcedZone: %s'):format(hasForced),
        zoneLine,
        distLine,
        ('fx handles: core=%d funnel=%d'):format(#tornadoFxHandles, #tornadoFunnelFxHandles),
        ('refreshMs: %d'):format(math.max(0, nextTornadoFunnelRefreshAt - GetGameTimer()))
    }

    local startX = 0.02
    local startY = 0.16
    for i = 1, #lines do
        drawDebugTextLine(startX, startY + ((i - 1) * 0.022), lines[i], 255, 255, 255, 230, 0.31)
    end
end

removeSmoke = function()
    for i = 1, #activeSmokeHandles do
        local handle = activeSmokeHandles[i]
        if handle then
            StopParticleFxLooped(handle, 0)
        end
    end

    for i = 1, #activeFireHandles do
        local handle = activeFireHandles[i]
        if handle and handle ~= 0 then
            RemoveScriptFire(handle)
        end
    end

    activeSmokeHandles = {}
    activeFireHandles = {}
    wildfireAnchor = nil
    wildfireSignature = nil
end

local function getGroundPosition(x, y, fallbackZ)
    local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, fallbackZ + 50.0, false)
    if foundGround then
        return groundZ
    end

    return fallbackZ
end


cleanupTornadoDebrisPool = function()
    for i = 1, #tornadoDebrisPool do
        local entry = tornadoDebrisPool[i]
        if entry and entry.entity and DoesEntityExist(entry.entity) then
            SetEntityAsMissionEntity(entry.entity, true, true)
            DeleteEntity(entry.entity)
        end
    end

    tornadoDebrisPool = {}
end

setTornadoWindAudio = function(volume, cfg)
    if volume < 0.0 then
        volume = 0.0
    elseif volume > 1.0 then
        volume = 1.0
    end

    if tornadoInteractionLastAudioVolume >= 0.0 and math.abs(tornadoInteractionLastAudioVolume - volume) <= 0.015 then
        return
    end

    tornadoInteractionLastAudioVolume = volume
    SendNUIMessage({
        action = 'setTornadoWindAudio',
        config = {
            volume = volume,
            lowpassHz = cfg.lowpassHz,
            highpassHz = cfg.highpassHz
        }
    })
end

local function getTornadoInteractionIntensity(zone, maxDistance)
    if not zone or not zone.coords then
        return 0.0, 99999.0
    end

    local pedCoords = GetEntityCoords(PlayerPedId())
    local dist = distanceBetween(pedCoords, zone.coords)
    local radius = math.max(1.0, maxDistance or zone.radius or 0.0)
    if dist > radius then
        return 0.0, dist
    end

    local raw = 1.0 - math.min(dist / radius, 1.0)
    local shaped = raw * raw
    return shaped, dist
end

local function getDebrisPoolTargetCount(dist, cfg)
    if dist <= 65.0 then
        return math.max(1, math.floor(cfg.poolSizeNear or 16))
    elseif dist <= 95.0 then
        return math.max(1, math.floor(cfg.poolSizeMid or 10))
    elseif dist <= (cfg.maxDistance or 120.0) then
        return math.max(1, math.floor(cfg.poolSizeFar or 6))
    end

    return 0
end

local function getTornadoDebrisModelSpec(entry)
    if type(entry) == 'string' and entry ~= '' then
        return entry, 'object'
    end

    if type(entry) ~= 'table' then
        return nil, nil
    end

    local modelName = entry.name or entry.modelName or entry.model
    if type(modelName) ~= 'string' or modelName == '' then
        return nil, nil
    end

    local entityType = entry.entityType
    if entityType ~= 'ped' then
        entityType = 'object'
    end

    return modelName, entityType
end

local function chooseTornadoDebrisModel(cfg)
    local names = cfg.modelNames or {}
    if #names == 0 then
        return nil, nil
    end

    for _ = 1, #names do
        local index = ((tornadoDebrisModelCycle - 1) % #names) + 1
        tornadoDebrisModelCycle = tornadoDebrisModelCycle + 1
        local modelName, entityType = getTornadoDebrisModelSpec(names[index])
        if modelName then
            local model = joaat(modelName)
            local isPedModel = IsModelAPed and IsModelAPed(model)
            if IsModelInCdimage(model) and IsModelValid(model) and (entityType ~= 'ped' or IsModelAPed == nil or isPedModel) then
                return model, entityType
            end
        end
    end

    return nil, nil
end

local function ensureDebrisEntry(index, zone, cfg)
    local entry = tornadoDebrisPool[index]
    if entry and entry.entity and DoesEntityExist(entry.entity) then
        return entry
    end

    local model, entityType = chooseTornadoDebrisModel(cfg)
    if not model then
        return nil
    end

    RequestModel(model)
    local deadline = GetGameTimer() + 500
    while not HasModelLoaded(model) and GetGameTimer() < deadline do
        Wait(0)
    end

    if not HasModelLoaded(model) then
        return nil
    end

    local entity
    if entityType == 'ped' then
        entity = CreatePed(28, model, zone.coords.x, zone.coords.y, zone.coords.z + 2.0, math.random() * 360.0, false, false)
        if entity ~= 0 and DoesEntityExist(entity) and SetBlockingOfNonTemporaryEvents then
            SetBlockingOfNonTemporaryEvents(entity, true)
        end
    else
        entity = CreateObjectNoOffset(model, zone.coords.x, zone.coords.y, zone.coords.z + 2.0, false, false, false)
    end

    if entity == 0 or not DoesEntityExist(entity) then
        SetModelAsNoLongerNeeded(model)
        return nil
    end

    SetEntityAsMissionEntity(entity, true, false)
    FreezeEntityPosition(entity, true)
    SetEntityInvincible(entity, true)
    SetEntityDynamic(entity, false)
    SetEntityCollision(entity, cfg.collision == true, cfg.collision == true)
    if SetEntityCompletelyDisableCollision then
        SetEntityCompletelyDisableCollision(entity, cfg.collision ~= true, cfg.collision ~= true)
    end
    SetEntityAlpha(entity, 210, false)

    entry = {
        entity = entity,
        model = model,
        entityType = entityType,
        angle = math.rad(math.random(0, 359)),
        radius = 2.0 + (math.random() * math.max(3.0, cfg.spawnRadius or 40.0)),
        height = (cfg.minHeight or 2.0) + (math.random() * math.max(0.5, (cfg.maxHeight or 24.0) - (cfg.minHeight or 2.0))),
        spin = ((math.random() * 2.0) - 1.0) * 120.0
    }

    tornadoDebrisPool[index] = entry
    SetModelAsNoLongerNeeded(model)
    return entry
end

local function updateTornadoDebrisPool(zone)
    local cfg = (Config.ClientFx.tornadoInteraction or {}).debrisPool or {}
    if cfg.enabled == false then
        cleanupTornadoDebrisPool()
        return
    end

    local intensity, dist = getTornadoInteractionIntensity(zone, cfg.maxDistance or 120.0)
    local targetCount = getDebrisPoolTargetCount(dist, cfg)
    if intensity <= 0.0 or targetCount <= 0 then
        cleanupTornadoDebrisPool()
        return
    end

    local orbitSpeed = cfg.orbitSpeed or 1.8
    local riseSpeed = cfg.riseSpeed or 6.8
    local despawnHeight = cfg.despawnHeight or 32.0
    local nowSec = GetGameTimer() / 1000.0

    for i = 1, targetCount do
        local entry = ensureDebrisEntry(i, zone, cfg)
        if entry and entry.entity and DoesEntityExist(entry.entity) then
            entry.angle = entry.angle + ((orbitSpeed + (i * 0.03)) * 0.08)
            entry.height = entry.height + ((riseSpeed * (0.040 + (intensity * 0.020))) * 0.15)
            entry.radius = math.max(1.2, entry.radius - (0.020 + (intensity * 0.018)))

            if entry.height >= despawnHeight or entry.radius <= 1.25 then
                entry.angle = math.rad(math.random(0, 359))
                entry.radius = 4.0 + (math.random() * math.max(4.0, cfg.spawnRadius or 40.0))
                entry.height = (cfg.minHeight or 2.0) + (math.random() * math.max(0.5, (cfg.maxHeight or 24.0) - (cfg.minHeight or 2.0)))
            end

            local wobble = math.sin(nowSec + i) * 0.45
            local x = zone.coords.x + (math.cos(entry.angle) * (entry.radius + wobble))
            local y = zone.coords.y + (math.sin(entry.angle) * (entry.radius + wobble))
            local z = zone.coords.z + entry.height
            SetEntityCoordsNoOffset(entry.entity, x, y, z, false, false, false)
            SetEntityRotation(entry.entity, (nowSec * 120.0) % 360.0, (nowSec * 95.0) % 360.0, (math.deg(entry.angle) + (entry.spin * nowSec)) % 360.0, 2, true)
        end
    end

    for i = #tornadoDebrisPool, targetCount + 1, -1 do
        local entry = tornadoDebrisPool[i]
        if entry and entry.entity and DoesEntityExist(entry.entity) then
            SetEntityAsMissionEntity(entry.entity, true, true)
            DeleteEntity(entry.entity)
        end
        tornadoDebrisPool[i] = nil
    end
end

local function updateTornadoInteraction(zone)
    local interactionCfg = Config.ClientFx.tornadoInteraction or {}
    if interactionCfg.enabled == false or not zone or not zone.coords then
        setTornadoWindAudio(0.0, interactionCfg.sound or {})
        StopGameplayCamShaking(true)
        return
    end

    local soundCfg = interactionCfg.sound or {}
    local cameraCfg = interactionCfg.camera or {}
    local intensity, dist = getTornadoInteractionIntensity(zone, interactionCfg.maxDistance or 260.0)

    if soundCfg.enabled ~= false then
        local maxDistance = math.max(1.0, soundCfg.maxDistance or interactionCfg.maxDistance or 260.0)
        local proximity = 1.0 - math.min(dist / maxDistance, 1.0)
        local centerBoostDistance = math.max(10.0, soundCfg.centerBoostDistance or 70.0)
        local centerBoost = 1.0 - math.min(dist / centerBoostDistance, 1.0)
        local baseVolume = soundCfg.baseVolume or 0.02
        local maxVolume = math.max(baseVolume, soundCfg.maxVolume or 0.26)
        local volume = baseVolume + ((maxVolume - baseVolume) * math.max(intensity, proximity * proximity))
        volume = math.min(maxVolume, volume + (centerBoost * 0.05))
        if intensity <= 0.0 then
            volume = 0.0
        end
        setTornadoWindAudio(volume, soundCfg)
    end

    if cameraCfg.enabled ~= false then
        local nowMs = GetGameTimer()
        if nowMs - tornadoInteractionLastShakeAt >= math.max(60, math.floor(cameraCfg.updateIntervalMs or 120)) then
            tornadoInteractionLastShakeAt = nowMs
            if intensity > 0.0 then
                local baseAmplitude = cameraCfg.baseAmplitude or 0.10
                local maxAmplitude = math.max(baseAmplitude, cameraCfg.maxAmplitude or 0.52)
                local amplitude = baseAmplitude + ((maxAmplitude - baseAmplitude) * intensity)
                ShakeGameplayCam(cameraCfg.shakeName or 'SKY_DIVING_SHAKE', amplitude)
            else
                StopGameplayCamShaking(true)
            end
        end
    end
end

local function computeWildfirePositions(anchor, density, plumeCount, fireCount, cfg)
    local positions = {}
    local smokeRadius = (cfg.plumeRadius or 14.0) * (0.65 + (density * 0.85))
    local fireRadius = (cfg.fireRadius or 10.0) * (0.65 + (density * 0.75))

    for i = 1, plumeCount do
        local offset = smokeOffsets[((i - 1) % #smokeOffsets) + 1]
        local isFire = i <= fireCount
        local radius = isFire and fireRadius or smokeRadius
        local x = anchor.x + (offset.x * (radius / 10.0))
        local y = anchor.y + (offset.y * (radius / 10.0))
        local z = getGroundPosition(x, y, anchor.z)
        positions[#positions + 1] = {
            x = x,
            y = y,
            z = z,
            fire = isFire
        }
    end

    return positions
end

local function rebuildWildfireFx(zone, density)
    local cfg = Config.ClientFx.wildfireSmoke or {}
    local plumeCount = math.max(1, math.floor((cfg.minPlumes or 2) + (((cfg.maxPlumes or 6) - (cfg.minPlumes or 2)) * density) + 0.5))
    local fireCount = 0

    if cfg.enableFire ~= false then
        fireCount = math.floor((cfg.minFires or 1) + (((cfg.maxFires or 4) - (cfg.minFires or 1)) * density) + 0.5)
    end

    local pedCoords = GetEntityCoords(PlayerPedId())
    local positions = computeWildfirePositions(pedCoords, density, plumeCount, fireCount, cfg)

    removeSmoke()

    if not ensurePtfxAsset(cfg.asset or 'core') then
        return
    end

    for i = 1, #positions do
        local pos = positions[i]
        local smokeHandle = nil
        local smokeEffects = cfg.effects
        if type(smokeEffects) ~= 'table' or #smokeEffects == 0 then
            smokeEffects = { cfg.effect or 'exp_grd_grenade_smoke' }
        end

        for j = 1, #smokeEffects do
            UseParticleFxAssetNextCall(cfg.asset or 'core')
            smokeHandle = StartParticleFxLoopedAtCoord(
                smokeEffects[j],
                pos.x,
                pos.y,
                pos.z + (cfg.plumeHeightOffset or 0.2),
                0.0,
                0.0,
                0.0,
                (cfg.smokeScale or 2.0) * (0.75 + (density * 0.9)),
                false,
                false,
                false,
                false
            )

            if smokeHandle and smokeHandle ~= 0 then
                break
            end
        end

        if smokeHandle and smokeHandle ~= 0 then
            if cfg.smokeFarClipDistance then
                SetParticleFxLoopedFarClipDist(smokeHandle, cfg.smokeFarClipDistance)
            end
            activeSmokeHandles[#activeSmokeHandles + 1] = smokeHandle
        end

        if pos.fire then
            local fireHandle = StartScriptFire(pos.x, pos.y, pos.z, cfg.fireMaxChildren or 1, false)
            if fireHandle and fireHandle ~= 0 then
                activeFireHandles[#activeFireHandles + 1] = fireHandle
            end
        end
    end

    wildfireAnchor = pedCoords
    wildfireSignature = ('%d:%d'):format(plumeCount, fireCount)
end

local function updateSmokePlumes(zone)
    local density = getSmokeDensity(zone)
    local cfg = Config.ClientFx.wildfireSmoke or {}
    local minPlumes = cfg.minPlumes or 2
    local maxPlumes = cfg.maxPlumes or 6
    local targetCount = math.floor(minPlumes + ((maxPlumes - minPlumes) * density) + 0.5)

    if density <= 0.0 or targetCount <= 0 then
        removeSmoke()
        return
    end

    local pedCoords = GetEntityCoords(PlayerPedId())
    local refreshDistance = cfg.refreshDistance or 18.0
    local fireCount = 0

    if cfg.enableFire ~= false then
        fireCount = math.floor((cfg.minFires or 1) + (((cfg.maxFires or 4) - (cfg.minFires or 1)) * density) + 0.5)
    end

    local signature = ('%d:%d'):format(targetCount, fireCount)
    if wildfireSignature == signature and wildfireAnchor and distanceBetween(pedCoords, wildfireAnchor) < refreshDistance then
        return
    end

    rebuildWildfireFx(zone, density)
end

local function drawWildfireOverlay(zone)
    local density = getSmokeDensity(zone)
    if density <= 0.0 then
        return
    end

    local cfg = Config.ClientFx.wildfireSmoke or {}
    local overlayColor = cfg.overlayColor or { r = 224, g = 96, b = 24 }
    local accentColor = cfg.accentOverlayColor or { r = 142, g = 28, b = 12 }
    local minAlpha = cfg.overlayMinAlpha or 18
    local maxAlpha = cfg.overlayMaxAlpha or 150
    local accentMaxAlpha = cfg.accentOverlayMaxAlpha or 52
    local overlayAlpha = math.floor(minAlpha + ((maxAlpha - minAlpha) * density))
    local accentAlpha = math.floor(accentMaxAlpha * density)

    DrawRect(0.5, 0.5, 1.0, 1.0, overlayColor.r, overlayColor.g, overlayColor.b, overlayAlpha)
    DrawRect(0.5, 0.5, 1.0, 1.0, accentColor.r, accentColor.g, accentColor.b, accentAlpha)
end

local function drawBlizzardOverlay(zone)
    local intensity = getBlizzardVisualIntensity(zone)
    if intensity <= 0.0 then
        return
    end

    local cfg = Config.ClientFx.blizzard or {}
    local hazeStrength = math.max(0.0, math.min(1.0, tonumber(cfg.fogStrength) or 0.0))
    if hazeStrength <= 0.0 then
        return
    end

    local overlayColor = cfg.hazeColor or { r = 236, g = 242, b = 252 }
    local accentColor = cfg.hazeAccentColor or { r = 214, g = 226, b = 242 }
    local minAlpha = tonumber(cfg.hazeMinAlpha) or 8
    local maxAlpha = tonumber(cfg.hazeMaxAlpha) or 24
    local accentMaxAlpha = tonumber(cfg.hazeAccentMaxAlpha) or 10
    local hazeFactor = intensity * hazeStrength
    local overlayAlpha = math.floor(minAlpha + ((maxAlpha - minAlpha) * hazeFactor))
    local accentAlpha = math.floor(accentMaxAlpha * hazeFactor)

    DrawRect(0.5, 0.5, 1.0, 1.0, overlayColor.r, overlayColor.g, overlayColor.b, overlayAlpha)
    DrawRect(0.5, 0.5, 1.0, 1.0, accentColor.r, accentColor.g, accentColor.b, accentAlpha)
end

ensurePtfxAsset = function(asset)
    if not asset then return false end
    if HasNamedPtfxAssetLoaded(asset) then
        return true
    end

    RequestNamedPtfxAsset(asset)
    local start = GetGameTimer()
    while not HasNamedPtfxAssetLoaded(asset) and (GetGameTimer() - start) < 5000 do
        Wait(0)
    end

    return HasNamedPtfxAssetLoaded(asset)
end

local function stopParticleFxHandles(handles)
    for i = 1, #handles do
        local handle = handles[i]
        if handle then
            StopParticleFxLooped(handle, 0)
        end
    end
end

stopTornadoFx = function()
    stopParticleFxHandles(tornadoFxHandles)
    tornadoFxHandles = {}
    stopParticleFxHandles(tornadoFunnelFxHandles)
    for i = 1, #tornadoFunnelFxNodes do
        local node = tornadoFunnelFxNodes[i]
        if node and node.entity and DoesEntityExist(node.entity) then
            SetEntityAsMissionEntity(node.entity, true, true)
            DeleteEntity(node.entity)
        end
    end
    tornadoFunnelFxHandles = {}
    tornadoFunnelFxNodes = {}
    tornadoFxSignature = nil
    tornadoFunnelGroundZ = nil
    tornadoFunnelGroundRefreshAt = 0
    nextTornadoDebrisAt = 0
    nextTornadoFunnelRefreshAt = 0
end

local function ensureModelLoaded(modelName)
    if not modelName then
        return nil
    end

    local model = type(modelName) == 'number' and modelName or joaat(modelName)
    if not IsModelInCdimage(model) then
        return nil
    end

    if HasModelLoaded(model) then
        return model
    end

    RequestModel(model)
    local start = GetGameTimer()
    while not HasModelLoaded(model) and (GetGameTimer() - start) < 5000 do
        Wait(0)
    end

    if not HasModelLoaded(model) then
        return nil
    end

    return model
end

local function clearTornadoFunnelFx()
    stopParticleFxHandles(tornadoFunnelFxHandles)
    for i = 1, #tornadoFunnelFxNodes do
        local node = tornadoFunnelFxNodes[i]
        if node and node.entity and DoesEntityExist(node.entity) then
            SetEntityAsMissionEntity(node.entity, true, true)
            DeleteEntity(node.entity)
        end
    end

    tornadoFunnelFxHandles = {}
    tornadoFunnelFxNodes = {}
    tornadoFunnelGroundZ = nil
    tornadoFunnelGroundRefreshAt = 0
    nextTornadoFunnelRefreshAt = 0
end

local function buildTornadoFunnelFx(zone)
    local cfg = Config.ClientFx.tornadoFunnel or {}
    if cfg.enabled == false then
        clearTornadoFunnelFx()
        return
    end

    local asset = cfg.asset or 'core'
    if not ensurePtfxAsset(asset) then
        return
    end

    local modelHash = ensureModelLoaded(cfg.anchorModel or 'prop_beachball_02')
    if not modelHash then
        if tornadoDebugEnabled then
            notify('Tornado funnel anchor model failed to load.', false)
        end
        return
    end

    clearTornadoFunnelFx()

    local armCount = math.max(2, math.floor(cfg.swirlArmCount or 3))
    local pointsPerArm = math.max(6, math.floor(cfg.swirlPointsPerArm or 16))
    local innerFillCount = math.max(0, math.floor(cfg.innerFillCount or 10))
    local coreColumnCount = math.max(0, math.floor(cfg.coreColumnCount or 0))
    local spineCount = math.max(0, math.floor(cfg.spineCount or 0))
    local spineScaleBase = cfg.spineScaleBase or 1.8
    local spineScaleTop = cfg.spineScaleTop or 3.2
    local baseHeight = cfg.baseHeight or -1.2
    local topHeight = cfg.topHeight or 100.0
    local baseScale = cfg.baseScale or 1.3
    local topScale = cfg.topScale or 4.0
    local coreScaleBase = cfg.coreScaleBase or (baseScale * 1.2)
    local coreScaleTop = cfg.coreScaleTop or (topScale * 1.1)
    local maxHandles = math.max(8, math.floor(cfg.maxHandles or 56))
    local effects = cfg.effects
    if type(effects) ~= 'table' or #effects == 0 then
        effects = { cfg.effect or 'ent_amb_smoke_foundry' }
    end

    local groundZ = getGroundPosition(zone.coords.x, zone.coords.y, zone.coords.z)
    tornadoFunnelGroundZ = groundZ
    tornadoFunnelGroundRefreshAt = GetGameTimer() + math.max(250, math.floor(cfg.groundResampleIntervalMs or 400))
    local nodeDefs = {}

    local function pushNode(def)
        if #nodeDefs >= maxHandles then
            return false
        end
        nodeDefs[#nodeDefs + 1] = def
        return true
    end

    for arm = 1, armCount do
        if #nodeDefs >= maxHandles then
            break
        end

        local armOffset = ((arm - 1) / armCount) * (math.pi * 2.0)
        for point = 1, pointsPerArm do
            if #nodeDefs >= maxHandles then
                break
            end

            local t = (point - 1) / (pointsPerArm - 1)
            local phase = (arm * 1.37) + (point * 0.63)
            pushNode({
                kind = 'arm',
                t = t,
                armOffset = armOffset,
                phase = phase,
                effectSeed = (arm * 97) + point,
                initialHeight = baseHeight + ((topHeight - baseHeight) * t),
                initialScale = baseScale + ((topScale - baseScale) * t),
            })
        end
    end

    for i = 1, innerFillCount do
        if #nodeDefs >= maxHandles then
            break
        end

        local t = i / (innerFillCount + 1)
        local phase = i * 2.11
        pushNode({
            kind = 'inner',
            t = t,
            phase = phase,
            effectSeed = i * 43,
            initialHeight = baseHeight + ((topHeight - baseHeight) * t),
            initialScale = baseScale + ((topScale - baseScale) * t) * 0.85,
        })
    end

    for c = 1, coreColumnCount do
        if #nodeDefs >= maxHandles then
            break
        end

        local t = (c - 1) / math.max(1, coreColumnCount - 1)
        local phase = c * 1.73
        pushNode({
            kind = 'core',
            t = t,
            phase = phase,
            effectSeed = 5000 + c,
            initialHeight = baseHeight + ((topHeight - baseHeight) * t),
            initialScale = coreScaleBase + ((coreScaleTop - coreScaleBase) * t),
        })
    end

    for s = 1, spineCount do
        if #nodeDefs >= maxHandles then
            break
        end

        local t = (s - 1) / math.max(1, spineCount - 1)
        pushNode({
            kind = 'spine',
            t = t,
            phase = s * 0.81,
            effectSeed = 700 + s,
            initialHeight = baseHeight + ((topHeight - baseHeight) * t),
            initialScale = spineScaleBase + ((spineScaleTop - spineScaleBase) * t),
        })
    end

    if cfg.topCloudEffect and cfg.topCloudScale and #nodeDefs < maxHandles then
        pushNode({
            kind = 'topCloud',
            effectName = cfg.topCloudEffect,
            effectSeed = 9001,
            initialHeight = cfg.topCloudHeight or (topHeight + 4.0),
            initialScale = cfg.topCloudScale,
        })
    end

    if cfg.baseCloudEffect and cfg.baseCloudScale and #nodeDefs < maxHandles then
        pushNode({
            kind = 'baseCloud',
            effectName = cfg.baseCloudEffect,
            effectSeed = 9002,
            initialHeight = cfg.baseCloudHeight or 0.0,
            initialScale = cfg.baseCloudScale,
        })
    end

    local function spawnLoopedFxOnNode(node, effectName, initialScale)
        UseParticleFxAssetNextCall(asset)
        local handle = StartParticleFxLoopedOnEntity(
            effectName,
            node.entity,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            initialScale,
            false,
            false,
            false
        )

        if handle and handle ~= 0 and cfg.farClipDistance then
            SetParticleFxLoopedFarClipDist(handle, cfg.farClipDistance)
        end

        return handle
    end

    for i = 1, #nodeDefs do
        local node = nodeDefs[i]
        local startZ = groundZ + (node.initialHeight or 0.0)
        node.entity = CreateObjectNoOffset(modelHash, zone.coords.x, zone.coords.y, startZ, false, false, false)
        if node.entity and node.entity ~= 0 then
            SetEntityCollision(node.entity, false, false)
            SetEntityVisible(node.entity, false, false)
            SetEntityAlpha(node.entity, 0, false)
            SetEntityInvincible(node.entity, true)
            FreezeEntityPosition(node.entity, true)

            local initialScale = math.max(0.1, node.initialScale or baseScale)
            local handle = nil
            if node.effectName then
                handle = spawnLoopedFxOnNode(node, node.effectName, initialScale)
            else
                for j = 1, #effects do
                    local effectName = effects[((node.effectSeed + j - 2) % #effects) + 1]
                    handle = spawnLoopedFxOnNode(node, effectName, initialScale)
                    if handle and handle ~= 0 then
                        node.effectName = effectName
                        break
                    end
                end
            end

            if handle and handle ~= 0 then
                node.handle = handle
                tornadoFunnelFxHandles[#tornadoFunnelFxHandles + 1] = handle
                tornadoFunnelFxNodes[#tornadoFunnelFxNodes + 1] = node
            else
                SetEntityAsMissionEntity(node.entity, true, true)
                DeleteEntity(node.entity)
            end
        end
    end

    SetModelAsNoLongerNeeded(modelHash)

    if tornadoDebugEnabled and #tornadoFunnelFxNodes == 0 then
        notify('Tornado funnel FX failed to spawn nodes; check asset/effect settings.', false)
    elseif tornadoDebugEnabled then
        notify(('Tornado funnel nodes active: %d'):format(#tornadoFunnelFxNodes), false)
    end

    local rebuildIntervalMs = math.max(5000, math.floor(cfg.rebuildIntervalMs or 45000))
    nextTornadoFunnelRefreshAt = GetGameTimer() + rebuildIntervalMs
end

local function updateTornadoFunnelFx(zone)
    if #tornadoFunnelFxNodes == 0 then
        return
    end

    local cfg = Config.ClientFx.tornadoFunnel or {}
    local spiralTurns = cfg.spiralTurns or 3.0
    local radiusProfilePower = cfg.radiusProfilePower or 1.5
    local innerFillRadiusScale = cfg.innerFillRadiusScale or 0.45
    local innerScaleBoost = cfg.innerScaleBoost or 1.45
    local innerMinRadius = cfg.innerMinRadius or 0.08
    local innerMaxRadius = cfg.innerMaxRadius
    local coreRadius = cfg.coreRadius or 0.95
    local coreTwistTurns = cfg.coreTwistTurns or 6.5
    local coreScaleBase = cfg.coreScaleBase or (cfg.baseScale or 1.3) * 1.2
    local coreScaleTop = cfg.coreScaleTop or (cfg.topScale or 4.0) * 1.1
    local spineRadius = cfg.spineRadius or 1.0
    local spineTwistTurns = cfg.spineTwistTurns or 2.0
    local spineScaleBase = cfg.spineScaleBase or 1.8
    local spineScaleTop = cfg.spineScaleTop or 3.2
    local baseRadius = cfg.baseRadius or 1.5
    local topRadius = cfg.topRadius or 26.0
    local baseHeight = cfg.baseHeight or -1.2
    local topHeight = cfg.topHeight or 100.0
    local baseScale = cfg.baseScale or 1.3
    local topScale = cfg.topScale or 4.0
    local degreesPerLayer = cfg.swirlDegreesPerLayer or 60.0
    local rotationSpeed = cfg.rotationSpeed or 3.0
    local radiusJitterScale = cfg.radiusJitterScale or 0.32
    local heightJitter = cfg.heightJitter or 1.8
    local scaleJitter = cfg.scaleJitter or 0.30

    local nowSec = GetGameTimer() / 1000.0
    local baseAngle = nowSec * rotationSpeed
    local dynamicPhase = nowSec * math.max(0.2, rotationSpeed * 0.7)
    local nowMs = GetGameTimer()
    if not tornadoFunnelGroundZ or nowMs >= tornadoFunnelGroundRefreshAt then
        tornadoFunnelGroundZ = getGroundPosition(zone.coords.x, zone.coords.y, zone.coords.z)
        tornadoFunnelGroundRefreshAt = nowMs + math.max(250, math.floor(cfg.groundResampleIntervalMs or 400))
    end
    local groundZ = tornadoFunnelGroundZ
    local missingNode = false

    for i = 1, #tornadoFunnelFxNodes do
        local node = tornadoFunnelFxNodes[i]
        if node and node.entity and DoesEntityExist(node.entity) then
            local x, y, z, rotationZ, puffScale
            if node.kind == 'arm' then
                local t = node.t or 0.0
                local profile = t ^ radiusProfilePower
                local radius = baseRadius + ((topRadius - baseRadius) * profile)
                local height = baseHeight + ((topHeight - baseHeight) * t)
                local scale = baseScale + ((topScale - baseScale) * t)
                local spinAngle = baseAngle + (node.armOffset or 0.0) + (t * spiralTurns * (math.pi * 2.0))
                local phase = node.phase or 0.0
                local angle = spinAngle + (math.sin(dynamicPhase + phase) * math.rad(degreesPerLayer * 0.33))
                local radiusFactor = 1.0 + (math.cos(dynamicPhase + (phase * 1.19)) * radiusJitterScale)
                local jitteredRadius = math.max(0.2, radius * radiusFactor)
                x = zone.coords.x + (math.cos(angle) * jitteredRadius)
                y = zone.coords.y + (math.sin(angle) * jitteredRadius)
                z = groundZ + height + (math.sin((dynamicPhase * 1.33) + (phase * 0.81)) * heightJitter)
                rotationZ = math.deg(angle) + 90.0
                puffScale = math.max(0.1, scale * (1.0 + (math.sin((dynamicPhase * 1.15) + phase) * scaleJitter)))
            elseif node.kind == 'inner' then
                local t = node.t or 0.0
                local profile = t ^ radiusProfilePower
                local outerRadius = baseRadius + ((topRadius - baseRadius) * profile)
                local phase = node.phase or 0.0
                local radius = math.max(innerMinRadius, outerRadius * innerFillRadiusScale * (0.56 + (0.38 * math.sin(dynamicPhase + phase))))
                if innerMaxRadius and innerMaxRadius > 0.0 then
                    radius = math.min(innerMaxRadius, radius)
                end
                local height = baseHeight + ((topHeight - baseHeight) * t) + (math.cos((dynamicPhase * 1.41) + phase) * heightJitter * 0.72)
                local scale = baseScale + ((topScale - baseScale) * t)
                local angle = baseAngle + phase + (t * spiralTurns * (math.pi * 2.0))
                x = zone.coords.x + (math.cos(angle) * radius)
                y = zone.coords.y + (math.sin(angle) * radius)
                z = groundZ + height
                rotationZ = math.deg(angle) + 90.0
                puffScale = math.max(0.1, scale * (0.75 + (0.28 * math.cos((dynamicPhase * 1.08) + phase))) * innerScaleBoost)
            elseif node.kind == 'core' then
                local t = node.t or 0.0
                local phase = node.phase or 0.0
                local radius = math.max(0.03, coreRadius * (0.52 + (0.48 * math.sin((dynamicPhase * 1.27) + phase))))
                local height = baseHeight + ((topHeight - baseHeight) * t) + (math.sin((dynamicPhase * 1.62) + phase) * heightJitter * 0.55)
                local angle = (baseAngle * 1.35) + phase + (t * coreTwistTurns * (math.pi * 2.0))
                x = zone.coords.x + (math.cos(angle) * radius)
                y = zone.coords.y + (math.sin(angle) * radius)
                z = groundZ + height
                rotationZ = math.deg(angle) + 90.0
                local centerBias = 1.0 - math.abs((t * 2.0) - 1.0)
                puffScale = coreScaleBase + ((coreScaleTop - coreScaleBase) * (0.45 + (0.55 * centerBias)))
            elseif node.kind == 'spine' then
                local t = node.t or 0.0
                local height = baseHeight + ((topHeight - baseHeight) * t)
                local phase = node.phase or 0.0
                local angle = baseAngle + (t * spineTwistTurns * (math.pi * 2.0)) + phase
                local radiusPulse = 0.7 + (0.3 * math.sin(dynamicPhase + (phase * 0.85)))
                local radius = math.max(0.08, spineRadius * radiusPulse)
                x = zone.coords.x + (math.cos(angle) * radius)
                y = zone.coords.y + (math.sin(angle) * radius)
                z = groundZ + height
                rotationZ = math.deg(angle) + 90.0
                puffScale = spineScaleBase + ((spineScaleTop - spineScaleBase) * t)
            elseif node.kind == 'topCloud' then
                local topHeightOffset = cfg.topCloudHeight or (topHeight + 4.0)
                local topScale = cfg.topCloudScale or 10.0
                local driftRadius = cfg.topCloudDriftRadius or 2.2
                local angle = (baseAngle * 0.27) + (i * 0.19)
                x = zone.coords.x + (math.cos(angle) * driftRadius)
                y = zone.coords.y + (math.sin(angle) * driftRadius)
                z = groundZ + topHeightOffset + (math.sin(dynamicPhase * 0.55) * 1.6)
                rotationZ = math.deg(angle)
                puffScale = topScale * (0.94 + (0.06 * math.sin(dynamicPhase * 0.8)))
            elseif node.kind == 'baseCloud' then
                local baseHeightOffset = cfg.baseCloudHeight or 0.0
                local baseScaleCfg = cfg.baseCloudScale or 18.0
                local driftRadius = cfg.baseCloudDriftRadius or 1.9
                local angle = (baseAngle * 0.45) + (i * 0.11)
                x = zone.coords.x + (math.cos(angle) * driftRadius)
                y = zone.coords.y + (math.sin(angle) * driftRadius)
                z = groundZ + baseHeightOffset + (math.cos(dynamicPhase * 0.93) * 0.35)
                rotationZ = math.deg(angle)
                puffScale = baseScaleCfg * (0.96 + (0.04 * math.cos(dynamicPhase * 1.25)))
            end

            if x and y and z then
                SetEntityCoordsNoOffset(node.entity, x, y, z, false, false, false)
                if node.handle and node.handle ~= 0 then
                    if SetParticleFxLoopedOffsets then
                        SetParticleFxLoopedOffsets(node.handle, 0.0, 0.0, 0.0, 0.0, 0.0, rotationZ or 0.0)
                    end
                    if SetParticleFxLoopedScale and puffScale then
                        SetParticleFxLoopedScale(node.handle, puffScale)
                    end
                end
            end
        else
            missingNode = true
        end
    end

    if missingNode then
        nextTornadoFunnelRefreshAt = 0
    end
end

local function startTornadoFx(zone)
    if not zone then return end
    local particleCfg = Config.ClientFx.tornadoParticle or {}
    local seq = currentState and currentState.seq or 0
    local signature = ('%s:%.1f:%s'):format(zone.name or 'tornado', (zone.radius or 0.0) + 0.0, tostring(seq))
    local zoneChanged = tornadoFxSignature ~= signature

    if zoneChanged then
        stopParticleFxHandles(tornadoFxHandles)
        tornadoFxHandles = {}
        clearTornadoFunnelFx()
        nextTornadoFunnelRefreshAt = 0
        nextTornadoDebrisAt = 0
    end

    if particleCfg.enabled == false or not particleCfg.asset or not particleCfg.effect then
        stopParticleFxHandles(tornadoFxHandles)
        tornadoFxHandles = {}
    elseif #tornadoFxHandles == 0 then
        if not ensurePtfxAsset(particleCfg.asset) then
            return
        end

        local heightOffsets = particleCfg.heightOffsets or { particleCfg.heightOffset or 0.0 }
        local scales = particleCfg.scales or { particleCfg.scale or 1.0 }
        local groundZ = getGroundPosition(zone.coords.x, zone.coords.y, zone.coords.z)

        for i = 1, #heightOffsets do
            UseParticleFxAssetNextCall(particleCfg.asset)
            local scale = scales[i] or scales[#scales] or particleCfg.scale or 1.0
            local handle = StartParticleFxLoopedAtCoord(
                particleCfg.effect,
                zone.coords.x,
                zone.coords.y,
                groundZ + heightOffsets[i],
                0.0,
                0.0,
                (i - 1) * 25.0,
                scale,
                false,
                false,
                false,
                false
            )

            if handle and handle ~= 0 then
                if particleCfg.farClipDistance then
                    SetParticleFxLoopedFarClipDist(handle, particleCfg.farClipDistance)
                end
                tornadoFxHandles[#tornadoFxHandles + 1] = handle
            end
        end
    end

    local funnelCfg = Config.ClientFx.tornadoFunnel or {}
    if funnelCfg.enabled == false then
        clearTornadoFunnelFx()
    else
        if zoneChanged or #tornadoFunnelFxNodes == 0 or GetGameTimer() >= nextTornadoFunnelRefreshAt then
            buildTornadoFunnelFx(zone)
        end
        updateTornadoFunnelFx(zone)
    end

    tornadoFxSignature = signature
end

local function burstTornadoDebris(zone)
    local cfg = Config.ClientFx.tornadoParticle or {}
    local effect = cfg.debrisEffect
    if not effect then return end
    local debrisAsset = cfg.debrisAsset or cfg.asset

    local now = GetGameTimer()
    if now < nextTornadoDebrisAt then
        return
    end

    nextTornadoDebrisAt = now + (cfg.debrisBurstIntervalMs or 1200)
    local groundZ = getGroundPosition(zone.coords.x, zone.coords.y, zone.coords.z)
    local burstCount = math.max(1, math.floor(cfg.debrisBurstCount or 4))
    local outerRadius = cfg.debrisBurstRadius or 28.0
    local baseRadius = cfg.debrisBaseRadius or math.max(4.0, outerRadius * 0.35)
    local minHeight = cfg.debrisMinHeight or 0.2
    local maxHeight = cfg.debrisMaxHeight or 8.0
    local radiusBiasPower = cfg.debrisRadiusBiasPower or 1.8

    if debrisAsset and not ensurePtfxAsset(debrisAsset) then
        return
    end

    for i = 1, burstCount do
        local angle = math.rad(math.random(0, 359))
        local innerDist = (math.random() ^ radiusBiasPower) * baseRadius
        local outerDist = math.random() * (outerRadius * 0.35)
        local dist = math.min(outerRadius, innerDist + outerDist)
        local x = zone.coords.x + (math.cos(angle) * dist)
        local y = zone.coords.y + (math.sin(angle) * dist)
        local z = groundZ + minHeight + (math.random() * (maxHeight - minHeight))
        if debrisAsset then
            UseParticleFxAssetNextCall(debrisAsset)
        end
        StartParticleFxNonLoopedAtCoord(effect, x, y, z, 0.0, 0.0, math.random(0, 359) + 0.0, cfg.debrisBurstScale or 1.0, false, false, false)
    end

    local baseDustEffect = cfg.baseDustEffect
    local baseDustCount = math.max(0, math.floor(cfg.baseDustCount or 0))
    if baseDustEffect and baseDustCount > 0 then
        local baseDustAsset = cfg.baseDustAsset or 'core'
        if ensurePtfxAsset(baseDustAsset) then
            local baseDustRadius = cfg.baseDustRadius or math.max(6.0, baseRadius * 1.35)
            local baseDustScale = cfg.baseDustScale or 1.2
            for i = 1, baseDustCount do
                local angle = math.rad(math.random(0, 359))
                local dist = math.random() * baseDustRadius
                local x = zone.coords.x + (math.cos(angle) * dist)
                local y = zone.coords.y + (math.sin(angle) * dist)
                local z = groundZ + (cfg.baseDustHeight or 0.1) + (math.random() * 0.65)
                UseParticleFxAssetNextCall(baseDustAsset)
                StartParticleFxNonLoopedAtCoord(baseDustEffect, x, y, z, 0.0, 0.0, math.random(0, 359) + 0.0, baseDustScale, false, false, false)
            end
        end
    end
end

local function drawTornadoFunnel(zone)
    local cfg = Config.ClientFx.tornadoFunnel or {}
    local drawSolid = cfg.drawSolidFunnel == true
    local drawVolumetric = cfg.drawVolumetricCloud == true
    local drawConeShell = cfg.drawConeShell == true
    local drawLineFunnel = cfg.drawLineFunnel == true and tornadoDebugEnabled
    local drawCenterBeacon = cfg.drawCenterBeacon == true

    if not (drawSolid or drawVolumetric or drawConeShell or drawLineFunnel or drawCenterBeacon) then
        return
    end

    local layers = math.max(6, math.floor(cfg.drawLayers or 16))
    local baseRadius = cfg.drawBaseRadius or 2.6
    local topRadius = cfg.drawTopRadius or 24.0
    local baseHeight = cfg.drawBaseHeight or -1.0
    local topHeight = cfg.drawTopHeight or 50.0
    local swirlRadius = cfg.drawSwirlRadius or 4.8
    local swirlSpeed = cfg.drawSwirlSpeed or 1.0
    local alphaBase = cfg.drawAlphaBase or 110
    local alphaTop = cfg.drawAlphaTop or 28
    local color = cfg.drawColor or { r = 110, g = 110, b = 110 }
    local now = GetGameTimer() / 1000.0
    local groundZ = getGroundPosition(zone.coords.x, zone.coords.y, zone.coords.z)

    if drawSolid then
        for i = 1, layers do
            local t = (i - 1) / (layers - 1)
            local radius = baseRadius + ((topRadius - baseRadius) * t)
            local z = groundZ + baseHeight + ((topHeight - baseHeight) * t)
            local alpha = math.floor(alphaBase + ((alphaTop - alphaBase) * t))
            local swirl = (1.0 - t) * swirlRadius
            local angle = (now * swirlSpeed) + (i * 0.47)
            local x = zone.coords.x + (math.cos(angle) * swirl)
            local y = zone.coords.y + (math.sin(angle) * swirl)

            DrawMarker(
                1,
                x,
                y,
                z,
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
                radius * 2.0,
                radius * 2.0,
                1.8,
                color.r,
                color.g,
                color.b,
                alpha,
                false,
                false,
                2,
                false,
                nil,
                nil,
                false
            )
        end
    end

    if drawVolumetric then
        local bands = math.max(4, math.floor(cfg.volumetricBands or 9))
        local puffsPerBand = math.max(4, math.floor(cfg.volumetricPuffsPerBand or 8))
        local volColor = cfg.volumetricColor or { r = 132, g = 132, b = 132 }
        local alphaBandBase = cfg.volumetricAlphaBase or 140
        local alphaBandTop = cfg.volumetricAlphaTop or 34
        local drift = cfg.volumetricDrift or 0.55
        local centerAlphaBase = cfg.volumetricCenterAlphaBase or 95
        local centerAlphaTop = cfg.volumetricCenterAlphaTop or 20
        local centerScale = cfg.volumetricCenterScale or 0.45

        for b = 1, bands do
            local bt = (b - 1) / (bands - 1)
            local bandRadius = (baseRadius + ((topRadius - baseRadius) * bt)) * 0.9
            local bandZ = groundZ + baseHeight + ((topHeight - baseHeight) * bt)
            local bandAlpha = math.floor(alphaBandBase + ((alphaBandTop - alphaBandBase) * bt))
            local puffRadius = math.max(1.6, bandRadius * (0.22 - (bt * 0.08)))
            local spin = (now * (swirlSpeed * (1.05 + (bt * 0.35)))) + (b * 0.51)

            for p = 1, puffsPerBand do
                local pt = (p - 1) / puffsPerBand
                local angle = spin + (pt * (math.pi * 2.0))
                local px = zone.coords.x + (math.cos(angle) * bandRadius) + (math.sin(now + p) * drift)
                local py = zone.coords.y + (math.sin(angle) * bandRadius) + (math.cos(now + b) * drift)
                DrawMarker(
                    1,
                    px,
                    py,
                    bandZ,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    puffRadius * 2.0,
                    puffRadius * 2.0,
                    2.4,
                    volColor.r,
                    volColor.g,
                    volColor.b,
                    bandAlpha,
                    false,
                    false,
                    2,
                    false,
                    nil,
                    nil,
                    false
                )
            end

            local centerRadius = math.max(1.4, bandRadius * centerScale)
            local centerAlpha = math.floor(centerAlphaBase + ((centerAlphaTop - centerAlphaBase) * bt))
            DrawMarker(
                1,
                zone.coords.x + (math.sin(now + (b * 0.6)) * (drift * 0.6)),
                zone.coords.y + (math.cos(now + (b * 0.7)) * (drift * 0.6)),
                bandZ,
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
                centerRadius * 2.0,
                centerRadius * 2.0,
                2.2,
                volColor.r,
                volColor.g,
                volColor.b,
                centerAlpha,
                false,
                false,
                2,
                false,
                nil,
                nil,
                false
            )
        end
    end

    if drawConeShell then
        local segments = math.max(8, math.floor(cfg.drawSegments or 22))
        local shellColor = cfg.drawShellColor or { r = 78, g = 78, b = 78 }
        local shellAlpha = cfg.drawShellAlpha or 130
        local spin = now * (swirlSpeed * 0.85)
        local shellTopTwist = math.rad(24.0)
        local baseZ = groundZ + baseHeight
        local topZ = groundZ + topHeight

        for s = 1, segments do
            local a1 = spin + ((s - 1) / segments) * (math.pi * 2.0)
            local a2 = spin + (s / segments) * (math.pi * 2.0)
            local tx1 = a1 + shellTopTwist
            local tx2 = a2 + shellTopTwist

            local b1x = zone.coords.x + (math.cos(a1) * baseRadius)
            local b1y = zone.coords.y + (math.sin(a1) * baseRadius)
            local b2x = zone.coords.x + (math.cos(a2) * baseRadius)
            local b2y = zone.coords.y + (math.sin(a2) * baseRadius)

            local t1x = zone.coords.x + (math.cos(tx1) * topRadius)
            local t1y = zone.coords.y + (math.sin(tx1) * topRadius)
            local t2x = zone.coords.x + (math.cos(tx2) * topRadius)
            local t2y = zone.coords.y + (math.sin(tx2) * topRadius)

            DrawPoly(b1x, b1y, baseZ, b2x, b2y, baseZ, t1x, t1y, topZ, shellColor.r, shellColor.g, shellColor.b, shellAlpha)
            DrawPoly(t1x, t1y, topZ, b2x, b2y, baseZ, t2x, t2y, topZ, shellColor.r, shellColor.g, shellColor.b, shellAlpha)
        end
    end

    if drawLineFunnel then
        local lineCount = math.max(8, math.floor(cfg.drawLineCount or 26))
        local lineColor = cfg.drawLineColor or { r = 150, g = 150, b = 150 }
        local lineAlpha = cfg.drawLineAlpha or 240
        local spin = now * (swirlSpeed * 1.1)
        local topTwist = math.rad(18.0)
        local baseZ = groundZ + baseHeight
        local topZ = groundZ + topHeight

        for l = 1, lineCount do
            local angle = spin + ((l - 1) / lineCount) * (math.pi * 2.0)
            local bx = zone.coords.x + (math.cos(angle) * baseRadius)
            local by = zone.coords.y + (math.sin(angle) * baseRadius)
            local ta = angle + topTwist
            local tx = zone.coords.x + (math.cos(ta) * topRadius)
            local ty = zone.coords.y + (math.sin(ta) * topRadius)
            DrawLine(bx, by, baseZ, tx, ty, topZ, lineColor.r, lineColor.g, lineColor.b, lineAlpha)
        end
    end

    if drawCenterBeacon then
        local beaconColor = cfg.drawBeaconColor or { r = 220, g = 220, b = 220 }
        local beaconAlpha = cfg.drawBeaconAlpha or 210
        local beaconScale = cfg.drawBeaconScale or 7.5
        DrawMarker(
            27,
            zone.coords.x,
            zone.coords.y,
            groundZ + (topHeight * 0.52),
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            beaconScale,
            beaconScale,
            topHeight * 0.95,
            beaconColor.r,
            beaconColor.g,
            beaconColor.b,
            beaconAlpha,
            false,
            false,
            2,
            false,
            nil,
            nil,
            false
        )
    end
end

RegisterNetEvent('cbk_disasters:client:setState', function(state)
    setState(state)
end)

RegisterNetEvent('cbk_disasters:client:setTornadoVisual', function(zone)
    local nowMs = GetGameTimer()
    local moveCfg = ((Config.Hazards or {}).tornado or {}).movement or {}
    local predictionWindowMs = math.max(0, math.floor(tonumber(moveCfg.broadcastIntervalMs) or 250))

    if zone and zone.coords and forcedTornadoZone and forcedTornadoZone.coords and forcedTornadoZoneUpdatedAt > 0 then
        local dtMs = math.max(1, nowMs - forcedTornadoZoneUpdatedAt)
        local dtSec = dtMs / 1000.0
        forcedTornadoZoneVelocityX = ((zone.coords.x + 0.0) - (forcedTornadoZone.coords.x + 0.0)) / dtSec
        forcedTornadoZoneVelocityY = ((zone.coords.y + 0.0) - (forcedTornadoZone.coords.y + 0.0)) / dtSec
        forcedTornadoZoneVelocityZ = ((zone.coords.z + 0.0) - (forcedTornadoZone.coords.z + 0.0)) / dtSec
    else
        forcedTornadoZoneVelocityX = 0.0
        forcedTornadoZoneVelocityY = 0.0
        forcedTornadoZoneVelocityZ = 0.0
    end

    forcedTornadoZone = zone
    forcedTornadoZoneUpdatedAt = zone and zone.coords and nowMs or 0
    forcedTornadoZonePredictionWindowMs = zone and zone.coords and predictionWindowMs or 0
    local hazard = getStateHazard(currentState)
    if hazard == 'tornado' and currentState then
        currentState.context = currentState.context or {}
        currentState.context.zone = zone
        syncZoneBlipPosition(zone)
    end

    if tornadoDebugEnabled then
        if zone and zone.coords then
            notify(('Tornado visual zone received: %.1f %.1f %.1f r=%.1f'):format(zone.coords.x + 0.0, zone.coords.y + 0.0, zone.coords.z + 0.0, (zone.radius or 0.0) + 0.0), false)
        else
            notify('Tornado visual zone cleared.', false)
        end
    end
end)

local function isPlayerInVehicle()
    return IsPedInAnyVehicle(PlayerPedId(), false)
end

local function isPlayerInInterior()
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then
        return false
    end

    local interior = GetInteriorFromEntity(ped)
    return interior ~= 0
end

local function isPlayerInShade()
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then
        return false
    end

    local coords = GetEntityCoords(ped)
    local startZ = coords.z + 0.25
    local rayHandle = StartShapeTestLosProbe(
        coords.x,
        coords.y,
        startZ,
        coords.x,
        coords.y,
        startZ + 18.0,
        17,
        ped,
        7
    )
    local _, hit = GetShapeTestResult(rayHandle)
    return hit == 1
end

local function isHeatwaveProtected()
    return isPlayerInVehicle() or isPlayerInInterior() or isPlayerInShade()
end

local function getHazardDamageMultiplier(hazard)
    if type(hazard) ~= 'string' or hazard == '' then
        return 1.0
    end

    if isPlayerInVehicle() then
        if hazard == 'tornado' then
            return 0.35
        end

        if hazard == 'wildfire_smoke' then
            return 0.45
        end

        return 0.0
    end

    if hazard == 'heatwave' and isHeatwaveProtected() then
        return 0.0
    end

    return 1.0
end

local function requestTornadoEntityControl(entity)
    if entity == 0 or not DoesEntityExist(entity) then
        return false
    end

    local playerPed = PlayerPedId()
    if entity == playerPed then
        return true
    end

    local playerVehicle = GetVehiclePedIsIn(playerPed, false)
    if playerVehicle ~= 0 and entity == playerVehicle then
        return true
    end

    if not NetworkGetEntityIsNetworked or not NetworkHasControlOfEntity or not NetworkRequestControlOfEntity then
        return true
    end

    if not NetworkGetEntityIsNetworked(entity) or NetworkHasControlOfEntity(entity) then
        return true
    end

    NetworkRequestControlOfEntity(entity)
    return NetworkHasControlOfEntity(entity)
end

local function getTornadoForceData(entity, center, maxForceDistance, baseIntensity, interactionCfg)
    if entity == 0 or not DoesEntityExist(entity) or not center then
        return nil
    end

    local coords = GetEntityCoords(entity)
    local dx = center.x - coords.x
    local dy = center.y - coords.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local maxDistance = math.max(1.0, maxForceDistance or 120.0)
    if dist <= 0.1 or dist > maxDistance then
        return nil
    end

    local normalizedX = dx / dist
    local normalizedY = dy / dist
    local tangentialX = -normalizedY
    local tangentialY = normalizedX
    local forceScale = math.max(baseIntensity or 0.12, 1.0 - math.min(dist / maxDistance, 1.0))
    local coreDistance = math.max(1.0, ((interactionCfg or {}).extremeCoreDistance) or 28.0)
    if dist < coreDistance then
        local coreBoost = 1.0 + ((1.0 - (dist / coreDistance)) * 0.45)
        forceScale = math.min(1.5, forceScale * coreBoost)
    end

    return {
        coords = coords,
        dist = dist,
        normalizedX = normalizedX,
        normalizedY = normalizedY,
        tangentialX = tangentialX,
        tangentialY = tangentialY,
        forceScale = forceScale
    }
end

local function clampTornadoEntityVelocity(entity, maxSpeed)
    if entity == 0 or not DoesEntityExist(entity) or not maxSpeed or maxSpeed <= 0.0 then
        return
    end

    local velocity = GetEntityVelocity(entity)
    local speed = math.sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y) + (velocity.z * velocity.z))
    if speed > maxSpeed and speed > 0.001 then
        local scale = maxSpeed / speed
        SetEntityVelocity(entity, velocity.x * scale, velocity.y * scale, velocity.z * scale)
    end
end

local function getTornadoLiftEntityState(entity)
    if entity == 0 or not DoesEntityExist(entity) then
        return nil
    end

    local state = tornadoLiftEntityStates[entity]
    if not state then
        state = {}
        tornadoLiftEntityStates[entity] = state
    end

    state.lastSeenAt = GetGameTimer()
    return state
end

clearTornadoLiftEntityStates = function()
    tornadoLiftEntityStates = {}
end

local function applyTornadoVelocityInjection(entity, force, cfg)
    if entity == 0 or not DoesEntityExist(entity) or not force or not cfg then
        return
    end

    local current = GetEntityVelocity(entity)
    local preserve = math.max(0.0, math.min(0.98, tonumber(cfg.velocityPreserveFactor) or 0.62))
    local pullVelocity = (tonumber(cfg.pullVelocity) or 0.0) * force.forceScale
    local spinVelocity = (tonumber(cfg.spinVelocity) or 0.0) * force.forceScale
    local liftVelocity = (tonumber(cfg.liftVelocity) or 0.0) * force.forceScale
    local groundedLift = tonumber(cfg.groundedLiftVelocity) or 0.0

    if groundedLift > 0.0 and (not IsEntityInAir or not IsEntityInAir(entity)) then
        liftVelocity = liftVelocity + groundedLift
    end

    local vx = (current.x * preserve) + (force.normalizedX * pullVelocity) + (force.tangentialX * spinVelocity)
    local vy = (current.y * preserve) + (force.normalizedY * pullVelocity) + (force.tangentialY * spinVelocity)
    local vz = (current.z * preserve) + liftVelocity
    local minVertical = tonumber(cfg.minVerticalVelocity) or 0.0
    local maxVertical = tonumber(cfg.maxVerticalVelocity)

    if vz < minVertical then
        vz = minVertical
    end

    if maxVertical and vz > maxVertical then
        vz = maxVertical
    end

    SetEntityVelocity(entity, vx, vy, vz)
end

local function maintainTornadoPedRagdoll(ped, force, pedCfg)
    if ped == 0 or not DoesEntityExist(ped) or not force or not pedCfg then
        return
    end

    local ragdollThreshold = tonumber(pedCfg.ragdollThreshold) or 0.35
    local keepThreshold = tonumber(pedCfg.liftedRagdollThreshold) or math.max(0.08, ragdollThreshold * 0.7)
    local inAir = not IsEntityInAir or IsEntityInAir(ped)
    if force.forceScale < keepThreshold and not inAir then
        return
    end

    local state = getTornadoLiftEntityState(ped)
    if not state then
        return
    end

    local nowMs = GetGameTimer()
    local ragdollTimeMs = math.max(250, math.floor(pedCfg.ragdollTimeMs or 1200))
    local maintainInterval = math.max(120, math.floor(pedCfg.maintainRagdollIntervalMs or 350))
    local needsRefresh = not state.lastRagdollAt or (nowMs - state.lastRagdollAt) >= maintainInterval

    if needsRefresh or (IsPedRagdoll and not IsPedRagdoll(ped)) then
        SetPedToRagdoll(ped, ragdollTimeMs, ragdollTimeMs, 0, false, false, false)
        state.lastRagdollAt = nowMs
    end
end

local function tryReleaseTornadoPed(ped, force, pedCfg, interactionCfg)
    if ped == 0 or not DoesEntityExist(ped) or not force or not pedCfg then
        return false
    end

    local state = getTornadoLiftEntityState(ped)
    if not state then
        return false
    end

    local nowMs = GetGameTimer()
    local cooldownMs = math.max(0, math.floor(pedCfg.releaseCooldownMs or 2600))
    local rearmDistance = tonumber(pedCfg.releaseRearmDistance) or (math.max(12.0, (tonumber(pedCfg.maxDistance) or 80.0) * 0.78))

    if state.awaitingRearm then
        if force.dist > rearmDistance then
            state.awaitingRearm = nil
        else
            return true
        end
    end

    if state.releaseUntil and nowMs < state.releaseUntil then
        return true
    end

    local releaseDistance = tonumber(pedCfg.releaseDistance) or math.max(18.0, (interactionCfg or {}).extremeCoreDistance or 24.0)
    local releaseThreshold = tonumber(pedCfg.releaseForceScaleThreshold) or 0.60
    local releaseAfterMs = math.max(300, math.floor(pedCfg.releaseAfterMs or 1500))
    local shouldCapture = force.dist <= releaseDistance or force.forceScale >= releaseThreshold

    if shouldCapture then
        state.captureStartedAt = state.captureStartedAt or nowMs
    else
        state.captureStartedAt = nil
    end

    if not state.captureStartedAt or (nowMs - state.captureStartedAt) < releaseAfterMs then
        return false
    end

    local current = GetEntityVelocity(ped)
    local preserve = math.max(0.0, math.min(0.95, tonumber(pedCfg.releaseVelocityPreserveFactor) or 0.18))
    local outwardVelocity = tonumber(pedCfg.releaseOutVelocity) or 16.0
    local upwardVelocity = tonumber(pedCfg.releaseUpVelocity) or 8.0
    local spinVelocity = tonumber(pedCfg.releaseSpinVelocity) or 4.2
    local vx = (current.x * preserve) - (force.normalizedX * outwardVelocity) + (force.tangentialX * spinVelocity)
    local vy = (current.y * preserve) - (force.normalizedY * outwardVelocity) + (force.tangentialY * spinVelocity)
    local vz = math.max(current.z * preserve, 0.0) + upwardVelocity

    SetEntityVelocity(ped, vx, vy, vz)
    SetPedToRagdoll(ped, math.max(400, math.floor(pedCfg.ragdollTimeMs or 1800)), math.max(400, math.floor(pedCfg.ragdollTimeMs or 1800)), 0, false, false, false)
    state.captureStartedAt = nil
    state.lastRagdollAt = nowMs
    state.releaseUntil = nowMs + cooldownMs
    state.awaitingRearm = true
    return true
end

local function tryReleaseTornadoVehicle(entity, force, vehicleCfg, interactionCfg)
    if entity == 0 or not DoesEntityExist(entity) or not force or not vehicleCfg then
        return false
    end

    local state = getTornadoLiftEntityState(entity)
    if not state then
        return false
    end

    local nowMs = GetGameTimer()
    local cooldownMs = math.max(0, math.floor(vehicleCfg.releaseCooldownMs or 2200))
    local rearmDistance = tonumber(vehicleCfg.releaseRearmDistance) or (math.max(14.0, (tonumber(vehicleCfg.maxDistance) or 90.0) * 0.80))

    if state.awaitingRearm then
        if force.dist > rearmDistance then
            state.awaitingRearm = nil
        else
            return true
        end
    end

    if state.releaseUntil and nowMs < state.releaseUntil then
        return true
    end

    local releaseDistance = tonumber(vehicleCfg.releaseDistance) or math.max(18.0, (interactionCfg or {}).extremeCoreDistance or 24.0)
    local releaseThreshold = tonumber(vehicleCfg.releaseForceScaleThreshold) or 0.48
    local releaseAfterMs = math.max(300, math.floor(vehicleCfg.releaseAfterMs or 1600))
    local shouldCapture = force.dist <= releaseDistance or force.forceScale >= releaseThreshold

    if shouldCapture then
        state.captureStartedAt = state.captureStartedAt or nowMs
    else
        state.captureStartedAt = nil
    end

    if not state.captureStartedAt or (nowMs - state.captureStartedAt) < releaseAfterMs then
        return false
    end

    local current = GetEntityVelocity(entity)
    local preserve = math.max(0.0, math.min(0.95, tonumber(vehicleCfg.releaseVelocityPreserveFactor) or 0.25))
    local outwardVelocity = tonumber(vehicleCfg.releaseOutVelocity) or 18.0
    local upwardVelocity = tonumber(vehicleCfg.releaseUpVelocity) or 10.5
    local spinVelocity = tonumber(vehicleCfg.releaseSpinVelocity) or 5.5
    local vx = (current.x * preserve) - (force.normalizedX * outwardVelocity) + (force.tangentialX * spinVelocity)
    local vy = (current.y * preserve) - (force.normalizedY * outwardVelocity) + (force.tangentialY * spinVelocity)
    local vz = math.max(current.z * preserve, 0.0) + upwardVelocity

    SetEntityVelocity(entity, vx, vy, vz)
    state.captureStartedAt = nil
    state.releaseUntil = nowMs + cooldownMs
    state.awaitingRearm = true
    return true
end

local function applyConfiguredTornadoVehicleForce(entity, center, baseIntensity, vehicleCfg, maxForceDistance, liftScale, spinScale, stallChance, interactionCfg)
    local force = getTornadoForceData(entity, center, maxForceDistance or vehicleCfg.maxDistance or 120.0, baseIntensity, interactionCfg)
    if not force or not requestTornadoEntityControl(entity) then
        return false, nil, nil
    end

    if tryReleaseTornadoVehicle(entity, force, vehicleCfg, interactionCfg) then
        return true, force.dist, force.forceScale
    end

    local pull = (vehicleCfg.maxPull or 4.75) * force.forceScale
    local lift = (vehicleCfg.maxLift or 1.65) * force.forceScale * (liftScale or 1.0)
    local spin = (vehicleCfg.maxSpin or 2.65) * force.forceScale * (spinScale or 1.0)

    ApplyForceToEntity(
        entity,
        1,
        (force.normalizedX * pull) + (force.tangentialX * spin),
        (force.normalizedY * pull) + (force.tangentialY * spin),
        lift,
        0.0,
        0.0,
        spin * 1.35,
        false,
        true,
        true,
        false,
        false
    )

    applyTornadoVelocityInjection(entity, force, vehicleCfg)
    clampTornadoEntityVelocity(entity, vehicleCfg.velocityClamp or 42.0)

    if stallChance and stallChance > 0.0 and math.random() < stallChance then
        SetVehicleEngineOn(entity, false, true, true)
        SetVehicleUndriveable(entity, true)
        SetTimeout(2500, function()
            if DoesEntityExist(entity) then
                SetVehicleUndriveable(entity, false)
                SetVehicleEngineOn(entity, true, true, false)
            end
        end)
    end

    return true, force.dist, force.forceScale
end

local function applyConfiguredTornadoPedForce(ped, center, baseIntensity, pedCfg, maxForceDistance, interactionCfg)
    local force = getTornadoForceData(ped, center, maxForceDistance or pedCfg.maxDistance or 90.0, baseIntensity, interactionCfg)
    if not force or not requestTornadoEntityControl(ped) then
        return false, nil, nil
    end

    if tryReleaseTornadoPed(ped, force, pedCfg, interactionCfg) then
        return true, force.dist, force.forceScale
    end

    local pull = (pedCfg.maxPull or 2.35) * force.forceScale
    local lift = (pedCfg.maxLift or 0.72) * force.forceScale
    local spin = (pedCfg.maxSpin or 0.75) * force.forceScale

    ApplyForceToEntity(
        ped,
        1,
        (force.normalizedX * pull) + (force.tangentialX * spin),
        (force.normalizedY * pull) + (force.tangentialY * spin),
        lift,
        0.0,
        0.0,
        spin * 0.45,
        false,
        true,
        true,
        false,
        false
    )

    applyTornadoVelocityInjection(ped, force, pedCfg)
    maintainTornadoPedRagdoll(ped, force, pedCfg)
    clampTornadoEntityVelocity(ped, pedCfg.velocityClamp or 24.0)

    return true, force.dist, force.forceScale
end

local function isTornadoDebrisEntity(entity)
    for i = 1, #tornadoDebrisPool do
        local entry = tornadoDebrisPool[i]
        if entry and entry.entity == entity then
            return true
        end
    end

    return false
end

local function applyTornadoForce(payload)
    if not payload or not payload.center then
        return
    end

    local ped = PlayerPedId()
    local inVehicle = isPlayerInVehicle()
    local entity = inVehicle and GetVehiclePedIsIn(ped, false) or ped
    local interactionCfg = Config.ClientFx.tornadoInteraction or {}

    if entity == 0 or not DoesEntityExist(entity) then
        return
    end

    if inVehicle then
        local vehicleCfg = interactionCfg.vehicle or {}
        applyConfiguredTornadoVehicleForce(
            entity,
            payload.center,
            payload.intensity or 0.12,
            vehicleCfg,
            payload.maxForceDistance,
            payload.vehicleLiftScale or 1.0,
            payload.vehicleSpinScale or 1.0,
            payload.stallChance or 0.15,
            interactionCfg
        )
    else
        applyConfiguredTornadoPedForce(
            ped,
            payload.center,
            payload.intensity or 0.12,
            interactionCfg.player or {},
            payload.maxForceDistance,
            interactionCfg
        )
    end
end

local function applyLocalTornadoLift(zone)
    local interactionCfg = Config.ClientFx.tornadoInteraction or {}
    if interactionCfg.enabled == false or not zone or not zone.coords then
        return
    end

    local playerPed = PlayerPedId()
    if playerPed == 0 or not DoesEntityExist(playerPed) then
        return
    end

    local baseIntensity, playerDist = getTornadoInteractionIntensity(zone, interactionCfg.maxDistance or 260.0)
    if baseIntensity <= 0.0 then
        return
    end

    local playerCfg = interactionCfg.player or {}
    local pedCfg = interactionCfg.peds or {}
    local vehicleCfg = interactionCfg.vehicle or {}
    local playerVehicle = GetVehiclePedIsIn(playerPed, false)
    local center = zone.coords

    if playerVehicle ~= 0 and vehicleCfg.enabled ~= false then
        applyConfiguredTornadoVehicleForce(
            playerVehicle,
            center,
            math.max(baseIntensity, 0.28),
            vehicleCfg,
            vehicleCfg.maxDistance or interactionCfg.closeRangeDistance or 90.0,
            1.20 + (baseIntensity * 1.05),
            0.95 + (baseIntensity * 0.65),
            nil,
            interactionCfg
        )
    elseif playerCfg.enabled ~= false then
        applyConfiguredTornadoPedForce(
            playerPed,
            center,
            math.max(baseIntensity, 0.18),
            playerCfg,
            playerCfg.maxDistance or interactionCfg.closeRangeDistance or 90.0,
            interactionCfg
        )
    end

    local pedSearchRadius = math.max(0.0, pedCfg.searchRadius or pedCfg.maxDistance or 0.0)
    local vehicleSearchRadius = math.max(0.0, vehicleCfg.sweepRadius or vehicleCfg.maxDistance or 0.0)
    local sweepRadius = math.max(pedSearchRadius, vehicleSearchRadius)
    if sweepRadius <= 0.0 or playerDist > (sweepRadius + 30.0) then
        return
    end

    if pedCfg.enabled ~= false then
        local pedAffected = 0
        local pedMaxCount = math.max(1, math.floor(pedCfg.maxSweepCount or 10))
        for _, nearbyPed in ipairs(GetGamePool('CPed')) do
            if pedAffected >= pedMaxCount then
                break
            end

            if nearbyPed ~= playerPed
                and DoesEntityExist(nearbyPed)
                and not IsPedAPlayer(nearbyPed)
                and not IsPedInAnyVehicle(nearbyPed, false)
                and not IsEntityDead(nearbyPed)
                and not isTornadoDebrisEntity(nearbyPed)
            then
                local applied = applyConfiguredTornadoPedForce(
                    nearbyPed,
                    center,
                    math.max(baseIntensity * 0.85, 0.12),
                    pedCfg,
                    pedSearchRadius,
                    interactionCfg
                )
                if applied then
                    pedAffected = pedAffected + 1
                end
            end
        end
    end

    if vehicleCfg.enabled ~= false then
        local vehicleAffected = 0
        local vehicleMaxCount = math.max(1, math.floor(vehicleCfg.maxSweepCount or 8))
        for _, vehicle in ipairs(GetGamePool('CVehicle')) do
            if vehicleAffected >= vehicleMaxCount then
                break
            end

            if vehicle ~= playerVehicle and DoesEntityExist(vehicle) then
                local driver = GetPedInVehicleSeat(vehicle, -1)
                if driver == 0 or (driver ~= playerPed and not IsPedAPlayer(driver)) then
                    local applied = applyConfiguredTornadoVehicleForce(
                        vehicle,
                        center,
                        math.max(baseIntensity * 0.90, 0.14),
                        vehicleCfg,
                        vehicleSearchRadius,
                        0.85 + (baseIntensity * 0.45),
                        0.70 + (baseIntensity * 0.40),
                        nil,
                        interactionCfg
                    )
                    if applied then
                        vehicleAffected = vehicleAffected + 1
                    end
                end
            end
        end
    end
end

local function spawnLightningFx(coords)
    ForceLightningFlash()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local dx = playerCoords.x - coords.x
    local dy = playerCoords.y - coords.y
    local dz = playerCoords.z - coords.z
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    if dist <= 200.0 then
        AddExplosion(coords.x, coords.y, coords.z, 29, 0.0, true, false, 0.0, false)
    end
end

RegisterNetEvent('cbk_disasters:client:hazard', function(payload)
    if not payload or not payload.kind then return end

    if payload.kind == 'tornado' then
        if not getActiveTornadoZone() then
            applyTornadoForce(payload)
        end
    elseif payload.kind == 'lightning' then
        spawnLightningFx(payload.coords)
    elseif payload.kind == 'heatwave' then
        if isHeatwaveProtected() then
            return
        end
        if payload.staminaDrain then
            RestorePlayerStamina(PlayerId(), 0.0)
        end
    end
end)

RegisterNetEvent('cbk_disasters:client:applyDamage', function(payload)
    local hazard = nil
    local amount = payload
    if type(payload) == 'table' then
        amount = payload.amount
        hazard = payload.hazard
    end

    local damage = math.max(0, math.floor(tonumber(amount) or 0))
    if damage <= 0 then return end

    local multiplier = getHazardDamageMultiplier(hazard)
    damage = math.max(0, math.floor((damage * multiplier) + 0.5))
    if damage <= 0 then
        return
    end

    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then
        return
    end

    local health = GetEntityHealth(ped)
    if health <= 0 then
        return
    end

    SetEntityHealth(ped, math.max(0, health - damage))
end)

exports('GetActiveDisaster', function()
    return currentState
end)

CreateThread(function()
    Wait(2500)
    TriggerServerEvent('cbk_disasters:server:requestState')
end)

CreateThread(function()
    while true do
        Wait(500)

        if currentState and (GetGameTimer() - weatherAppliedAt) >= Config.Sync.weatherApplyIntervalMs then
            applyDisasterWeather(currentState)
            weatherAppliedAt = GetGameTimer()
        elseif not currentState then
            weatherAppliedAt = 0
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)

        if currentState and Config.ClientFx.statusReminderSeconds > 0 then
            local nowSec = math.floor(GetGameTimer() / 1000)
            if nowSec - lastReminder >= Config.ClientFx.statusReminderSeconds then
                local state = currentState
                local unixTime = getCurrentUnixTime()
                if unixTime > 0 then
                    local remaining = math.max(0, (state.endsAt or 0) - unixTime)
                    notify(('%s in effect | %sm remaining'):format(state.label, math.ceil(remaining / 60)), false)
                    lastReminder = nowSec
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        local state = currentState
        if Config.Debug and Config.ClientFx.drawZoneMarkersWhenDebug and state and state.context and state.context.zone then
            Wait(0)
            local zone = state.context.zone
            DrawMarker(1, zone.coords.x, zone.coords.y, zone.coords.z - 5.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, zone.radius * 2.0, zone.radius * 2.0, 10.0, 255, 120, 0, Config.ClientFx.debugZoneMarkerAlpha, false, false, 2, false, nil, nil, false)
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        local state = currentState
        local cfg = Config.ClientFx.zoneBlip or {}
        if cfg.showWorldPulse == true and state and state.context and state.context.zone then
            Wait(0)
            local zone = state.context.zone
            local pulse = (math.sin(GetGameTimer() * (cfg.worldPulseSpeed or 0.004)) + 1.0) * 0.5
            local minScale = cfg.worldPulseMinScale or 1.05
            local maxScale = cfg.worldPulseMaxScale or 1.45
            local scale = minScale + ((maxScale - minScale) * pulse)
            local minAlpha = cfg.worldPulseMinAlpha or 85
            local maxAlpha = cfg.worldPulseMaxAlpha or 180
            local alpha = math.floor(minAlpha + ((maxAlpha - minAlpha) * pulse))
            local coverageRadius = zone.radius * scale
            local coverageHeight = cfg.worldPulseHeight or 18.0

            DrawMarker(1, zone.coords.x, zone.coords.y, zone.coords.z - 5.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, coverageRadius * 2.0, coverageRadius * 2.0, coverageHeight, 255, 20, 20, alpha, false, false, 2, false, nil, nil, false)
            DrawMarker(27, zone.coords.x, zone.coords.y, zone.coords.z + 4.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, coverageRadius * 2.0, coverageRadius * 2.0, coverageHeight + 6.0, 255, 40, 40, math.max(60, alpha - 20), false, false, 2, false, nil, nil, false)
            DrawMarker(1, zone.coords.x, zone.coords.y, zone.coords.z - 3.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, coverageRadius * 1.35, coverageRadius * 1.35, 3.0, 255, 60, 60, math.min(255, alpha + 25), false, false, 2, false, nil, nil, false)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        local tornadoZone = getActiveTornadoZone()
        if tornadoZone then
            startTornadoFx(tornadoZone)
            burstTornadoDebris(tornadoZone)
            Wait(50)
        else
            if tornadoFxSignature or #tornadoFxHandles > 0 or #tornadoFunnelFxNodes > 0 then
                stopTornadoFx()
            end
            Wait(350)
        end
    end
end)

CreateThread(function()
    while true do
        local state = currentState
        local hazard = getStateHazard(state)
        if state and hazard == 'blizzard' then
            updateBlizzardFx(state.context and state.context.zone or nil)
            Wait(120)
        else
            stopBlizzardFx()
            Wait(400)
        end
    end
end)

CreateThread(function()
    while true do
        local state = currentState
        local hazard = getStateHazard(state)
        if state and hazard == 'blizzard' then
            Wait(0)
            updateBlizzardSnow(state.context and state.context.zone or nil)
        else
            blizzardSnowParticles = {}
            Wait(400)
        end
    end
end)

CreateThread(function()
    while true do
        local state = currentState
        local hazard = getStateHazard(state)
        if state and hazard == 'blizzard' then
            Wait(0)
            drawBlizzardOverlay(state.context and state.context.zone or nil)
        else
            Wait(400)
        end
    end
end)

CreateThread(function()
    while true do
        local tornadoZone = getActiveTornadoZone()
        if tornadoZone then
            Wait(0)
            drawTornadoFunnel(tornadoZone)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        local tornadoZone = getActiveTornadoZone()
        if tornadoZone then
            updateTornadoInteraction(tornadoZone)
            Wait(math.max(60, math.floor(((Config.ClientFx.tornadoInteraction or {}).camera or {}).updateIntervalMs or 120)))
        else
            updateTornadoInteraction(nil)
            cleanupTornadoDebrisPool()
            Wait(400)
        end
    end
end)

CreateThread(function()
    while true do
        local tornadoZone = getActiveTornadoZone()
        local interactionCfg = Config.ClientFx.tornadoInteraction or {}
        if tornadoZone and interactionCfg.enabled ~= false then
            applyLocalTornadoLift(tornadoZone)
            Wait(math.max(70, math.floor(interactionCfg.forceIntervalMs or 140)))
        else
            clearTornadoLiftEntityStates()
            Wait(400)
        end
    end
end)

CreateThread(function()
    while true do
        local tornadoZone = getActiveTornadoZone()
        local debrisCfg = ((Config.ClientFx.tornadoInteraction or {}).debrisPool or {})
        if tornadoZone and debrisCfg.enabled ~= false then
            updateTornadoDebrisPool(tornadoZone)
            Wait(math.max(80, math.floor(debrisCfg.updateIntervalMs or 150)))
        else
            cleanupTornadoDebrisPool()
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(500)
        local state = currentState
        local hazard = getStateHazard(state)
        if state and state.context and state.context.zone and hazard == 'wildfire_smoke' then
            local zone = state.context.zone
            updateSmokePlumes(zone)
        else
            removeSmoke()
        end
    end
end)

CreateThread(function()
    while true do
        local state = currentState
        local hazard = getStateHazard(state)
        if state and hazard == 'wildfire_smoke' and state.context and state.context.zone then
            Wait(0)
            drawWildfireOverlay(state.context.zone)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if panelOpen then
            Wait(0)
            if IsControlJustPressed(0, 322) or IsControlJustPressed(0, 177) then
                closePanel()
            end
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if tornadoDebugEnabled then
            Wait(0)
            drawTornadoDebugHud()
        else
            Wait(750)
        end
    end
end)

RegisterNetEvent('cbk_disasters:client:setTornadoDebug', function(action)
    local normalized = string.lower(tostring(action or 'toggle'))
    if normalized == 'on' then
        tornadoDebugEnabled = true
    elseif normalized == 'off' then
        tornadoDebugEnabled = false
    else
        tornadoDebugEnabled = not tornadoDebugEnabled
    end

    notify(('Tornado debug %s'):format(tornadoDebugEnabled and 'enabled' or 'disabled'), false)
    if tornadoDebugEnabled then
        TriggerServerEvent('cbk_disasters:server:requestState')
    end
end)

if Config.Debug then
    RegisterCommand('disaster_debug_tornado', function(_, args)
        TriggerServerEvent('cbk_disasters:server:toggleTornadoDebug', tostring(args[1] or 'toggle'))
    end, false)
end

RegisterCommand('disasters', function()
    if panelOpen then
        closePanel()
    else
        TriggerServerEvent('cbk_disasters:server:requestOpenPanel')
    end
end, false)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closePanel()
    removeZoneBlips()
    stopBlizzardFx()
    resetWeather()
    tornadoDebugEnabled = false
    forcedTornadoZone = nil
    setTornadoWindAudio(0.0, {})
    cleanupTornadoDebrisPool()
    removeSmoke()
    stopTornadoFx()
    StopGameplayCamShaking(true)
end)
