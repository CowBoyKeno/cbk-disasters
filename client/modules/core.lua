currentState = nil
clientCoreReady = false
lastReminder = 0
weatherAppliedAt = 0
stateStartedAtMs = 0
panelData = nil
panelOpen = false
activeSmokeHandles = {}
activeFireHandles = {}
wildfireAnchor = nil
wildfireObserverAnchor = nil
wildfireSignature = nil
lastAlertSeq = nil
tornadoFxHandles = {}
tornadoFunnelFxHandles = {}
tornadoFunnelFxNodes = {}
tornadoFxSignature = nil
nextTornadoDebrisAt = 0
nextTornadoFunnelRefreshAt = 0
tornadoFunnelGroundZ = nil
tornadoFunnelGroundRefreshAt = 0
blizzardSnowParticles = {}
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
forcedTornadoZone = nil
forcedTornadoZoneUpdatedAt = 0
forcedTornadoZonePredictionWindowMs = 0
forcedTornadoZoneVelocityX = 0.0
forcedTornadoZoneVelocityY = 0.0
forcedTornadoZoneVelocityZ = 0.0
tornadoDebugEnabled = false
tornadoInteractionLastAudioVolume = -1.0
tornadoInteractionLastShakeAt = 0
tornadoInteractionLastDamageAt = 0
tornadoLiftEntityStates = {}
tornadoNextPedSweepAt = 0
tornadoNextVehicleSweepAt = 0
tornadoDebrisPool = {}
tornadoDebrisModelCycle = 1
zoneRadiusBlip = nil
zoneCenterBlip = nil
getSmokeDensity = nil
getZoneIntensity = nil
getStateIntensity = nil
removeSmoke = nil
stopTornadoFx = nil
cleanupTornadoDebrisPool = nil
clearTornadoLiftEntityStates = nil
setTornadoWindAudio = nil
ensurePtfxAsset = nil

smokeOffsets = {
    { x = 0.0, y = 0.0 },
    { x = 7.0, y = 4.0 },
    { x = -6.5, y = 5.5 },
    { x = 8.5, y = -4.5 },
    { x = -7.5, y = -5.5 },
    { x = 3.5, y = -8.5 },
}

function getStateHazard(state)
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

function getCurrentUnixTime()
    local cloudTime = GetCloudTimeAsInt()
    if type(cloudTime) == 'number' and cloudTime > 0 then
        return cloudTime
    end

    return 0
end

function getDisasterProgress(state)
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

function getDisasterTransitionConfig(state)
    local defaults = Config.Transitions or {}
    local transition = state and state.transition or {}
    local inSeconds = tonumber(transition.inSeconds)
    local outSeconds = tonumber(transition.outSeconds)

    if inSeconds == nil then
        inSeconds = math.max(0, math.floor((tonumber(transition.inMinutes) or tonumber(defaults.inMinutes) or 3) * 60))
    else
        inSeconds = math.max(0, math.floor(inSeconds))
    end

    if outSeconds == nil then
        outSeconds = math.max(0, math.floor((tonumber(transition.outMinutes) or tonumber(defaults.outMinutes) or 3) * 60))
    else
        outSeconds = math.max(0, math.floor(outSeconds))
    end

    local curveExponent = math.max(0.1, tonumber(transition.curveExponent) or tonumber(defaults.curveExponent) or 1.0)

    return {
        inSeconds = inSeconds,
        outSeconds = outSeconds,
        curveExponent = curveExponent
    }
end

function shapeTransitionIntensity(ratio, exponent)
    if ratio <= 0.0 then
        return 0.0
    end

    if ratio >= 1.0 then
        return 1.0
    end

    return ratio ^ (tonumber(exponent) or 1.0)
end

function getDisasterTransitionIntensity(state)
    if not state then
        return 0.0
    end

    local duration = tonumber(state.durationSeconds) or 0
    if duration <= 0 then
        return 1.0
    end

    local transition = getDisasterTransitionConfig(state)
    local unixTime = getCurrentUnixTime()
    local elapsed = 0
    local remaining = duration

    if unixTime > 0 and state.startedAt then
        elapsed = math.max(0, unixTime - state.startedAt)
        remaining = math.max(0, (state.endsAt or (state.startedAt + duration)) - unixTime)
    elseif stateStartedAtMs > 0 then
        elapsed = math.max(0, math.floor((GetGameTimer() - stateStartedAtMs) / 1000.0))
        remaining = math.max(0, duration - elapsed)
    end

    local fadeInRatio = transition.inSeconds > 0 and math.min(1.0, elapsed / transition.inSeconds) or 1.0
    local fadeOutRatio = transition.outSeconds > 0 and math.min(1.0, remaining / transition.outSeconds) or 1.0
    return shapeTransitionIntensity(math.min(fadeInRatio, fadeOutRatio), transition.curveExponent)
end

function notify(message, playSound)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(playSound == true, false)
end

function nearlyEqual(a, b, epsilon)
    local left = tonumber(a)
    local right = tonumber(b)
    if left == nil or right == nil then
        return left == right
    end

    return math.abs(left - right) <= (epsilon or 0.001)
end

function getBlizzardWindState(cfg, intensity)
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

function stopBlizzardFx()
    blizzardSnowParticles = {}

    if SetWindDirection then
        pcall(SetWindDirection, 0.0)
    end
end

function getBlizzardVisualIntensity(zone)
    local transitionIntensity = getDisasterTransitionIntensity(currentState)
    if transitionIntensity <= 0.0 then
        return 0.0
    end

    if zone and zone.coords then
        return getZoneIntensity(zone) * transitionIntensity
    end

    return getStateIntensity(currentState)
end

function updateBlizzardFx(zone)
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

function respawnBlizzardSnowParticle(index, cfg, intensity, topOnly, windX, windY)
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

function updateBlizzardSnow(zone)
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

function closePanel()
    if not panelOpen then return end
    panelOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hidePanel' })
    TriggerServerEvent('cbk_disasters:server:panelClosed')
end

function openPanel(data)
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

RegisterNUICallback('setSystemEnabled', function(data, cb)
    if data and type(data.enabled) == 'boolean' then
        TriggerServerEvent('cbk_disasters:server:setSystemEnabledFromPanel', {
            enabled = data.enabled
        })
    end
    cb('ok')
end)

function resetWeather()
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

function getTimecycleModifier(key)
    return DisasterTimecycles[key] or DisasterTimecycles.default
end

function removeZoneBlips()
    if zoneRadiusBlip and DoesBlipExist(zoneRadiusBlip) then
        RemoveBlip(zoneRadiusBlip)
    end

    if zoneCenterBlip and DoesBlipExist(zoneCenterBlip) then
        RemoveBlip(zoneCenterBlip)
    end

    zoneRadiusBlip = nil
    zoneCenterBlip = nil
end

function updateZoneBlips(state)
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

function syncZoneBlipPosition(zone)
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

function applyDisasterWeather(state)
    if not state then
        resetWeather()
        return
    end

    local hazard = getStateHazard(state)
    local targetWeather = state.weather
    local blizzardAccumulation = 0.0
    local transitionIntensity = getDisasterTransitionIntensity(state)
    local blizzardCfg = Config.ClientFx.blizzard or {}
    if hazard == 'blizzard' then
        local allowGlobalSnowCover = blizzardCfg.enableGlobalSnowCover == true
        local fogStrength = math.max(0.0, math.min(1.0, tonumber(blizzardCfg.fogStrength) or 0.0))
        local buildupThreshold = 0.02 + (0.22 * fogStrength)
        local snowCoverThreshold = math.max(blizzardCfg.snowCoverThreshold or 0.10, 0.12 + (0.68 * fogStrength))
        blizzardAccumulation = math.max(0.0, math.min(1.0, transitionIntensity))

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

    local rainLevel = (state.rainLevel or 0.0) * transitionIntensity
    if not nearlyEqual(lastAppliedRainLevel, rainLevel, 0.01) then
        SetRainLevel(rainLevel)
        lastAppliedRainLevel = rainLevel
    end

    local windSpeed = (state.windSpeed or 0.0) * transitionIntensity
    if hazard == 'blizzard' then
        local baseWind = math.max((state.windSpeed or 0.0) * transitionIntensity, (blizzardCfg.weatherWindBase or 1.05) * transitionIntensity)
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

function playAlertTone()
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

function setState(state)
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

function getPredictedForcedTornadoZone()
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

function getActiveTornadoZone()
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

function distanceBetween(a, b)
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

    local transitionIntensity = getDisasterTransitionIntensity(state)
    if transitionIntensity <= 0.0 then
        return 0.0
    end

    if state.context and state.context.zone then
        return getZoneIntensity(state.context.zone) * transitionIntensity
    end

    return transitionIntensity
end

getSmokeDensity = function(zone)
    local cfg = Config.ClientFx.wildfireSmoke or {}
    local radius = cfg.maxDistance or (zone and zone.radius) or 400.0
    return getZoneIntensity(zone, radius) * getDisasterTransitionIntensity(currentState)
end

clientCoreReady = true

