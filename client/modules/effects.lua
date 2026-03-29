clientEffectsReady = false

function drawDebugTextLine(x, y, text, r, g, b, a, scale)
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

function drawTornadoDebugHud()
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
    wildfireObserverAnchor = nil
    wildfireSignature = nil
end

function getGroundPosition(x, y, fallbackZ)
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

function getTornadoInteractionIntensity(zone, maxDistance)
    if not zone or not zone.coords then
        return 0.0, 99999.0
    end

    local pedCoords = GetEntityCoords(PlayerPedId())
    local dist = distanceBetween(pedCoords, zone.coords)
    local radius = math.max(1.0, maxDistance or zone.radius or 0.0)
    if dist > radius then
        return 0.0, dist
    end

    local transitionIntensity = getDisasterTransitionIntensity(currentState)
    if transitionIntensity <= 0.0 then
        return 0.0, dist
    end

    local raw = 1.0 - math.min(dist / radius, 1.0)
    local shaped = (raw * raw) * transitionIntensity
    return shaped, dist
end

function getDebrisPoolTargetCount(dist, cfg)
    if dist <= 65.0 then
        return math.max(1, math.floor(cfg.poolSizeNear or 16))
    elseif dist <= 95.0 then
        return math.max(1, math.floor(cfg.poolSizeMid or 10))
    elseif dist <= (cfg.maxDistance or 120.0) then
        return math.max(1, math.floor(cfg.poolSizeFar or 6))
    end

    return 0
end

function getTornadoDebrisModelSpec(entry)
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

function chooseTornadoDebrisModel(cfg)
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

function ensureDebrisEntry(index, zone, cfg)
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

function updateTornadoDebrisPool(zone)
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

function updateTornadoInteraction(zone)
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

function computeWildfirePositions(anchor, density, plumeCount, fireCount, cfg)
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

function rebuildWildfireFx(zone, density)
    local cfg = Config.ClientFx.wildfireSmoke or {}
    if not zone or not zone.coords then
        removeSmoke()
        return
    end

    local plumeCount = math.max(1, math.floor((cfg.minPlumes or 2) + (((cfg.maxPlumes or 6) - (cfg.minPlumes or 2)) * density) + 0.5))
    local fireCount = 0

    if cfg.enableFire ~= false then
        fireCount = math.floor((cfg.minFires or 1) + (((cfg.maxFires or 4) - (cfg.minFires or 1)) * density) + 0.5)
    end

    local pedCoords = GetEntityCoords(PlayerPedId())
    local zoneAnchor = zone.coords
    local positions = computeWildfirePositions(zoneAnchor, density, plumeCount, fireCount, cfg)

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

    wildfireAnchor = {
        x = zoneAnchor.x + 0.0,
        y = zoneAnchor.y + 0.0,
        z = zoneAnchor.z + 0.0
    }
    wildfireObserverAnchor = {
        x = pedCoords.x + 0.0,
        y = pedCoords.y + 0.0,
        z = pedCoords.z + 0.0
    }
    wildfireSignature = ('%d:%d'):format(plumeCount, fireCount)
end

function updateSmokePlumes(zone)
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
    local anchorMatches = wildfireAnchor and distanceBetween(zone.coords, wildfireAnchor) < 3.0
    local observerMatches = wildfireObserverAnchor and distanceBetween(pedCoords, wildfireObserverAnchor) < refreshDistance
    if wildfireSignature == signature and anchorMatches and observerMatches then
        return
    end

    rebuildWildfireFx(zone, density)
end

function drawWildfireOverlay(zone)
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

function drawBlizzardOverlay(zone)
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

function stopParticleFxHandles(handles)
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

function ensureModelLoaded(modelName)
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

function clearTornadoFunnelFx()
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

function buildTornadoFunnelFx(zone)
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

function updateTornadoFunnelFx(zone)
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

function startTornadoFx(zone)
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

function burstTornadoDebris(zone)
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

function drawTornadoFunnel(zone)
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

clientEffectsReady = true

