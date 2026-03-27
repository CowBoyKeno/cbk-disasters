local RESOURCE = GetCurrentResourceName()

local State = {
    active = nil,
    nextEventAt = 0,
    lastRun = {},
    reminderAt = 0,
    seq = 0
}
local tornadoMotion = nil
local panelSubscribers = {}
local stateRequestThrottle = {}
local TIMING_OVERRIDES_FILE = 'timing_overrides.json'

local function now()
    return os.time()
end

local function canServeStateRequest(src)
    if type(src) ~= 'number' or src <= 0 then
        return true
    end

    local cooldownMs = math.max(250, math.floor(tonumber((Config.Sync or {}).stateRequestCooldownMs) or 1500))
    local nowMs = GetGameTimer()
    local nextAllowedAt = stateRequestThrottle[src] or 0
    if nowMs < nextAllowedAt then
        return false
    end

    stateRequestThrottle[src] = nowMs + cooldownMs
    return true
end

local function normalizeClockHour(hour)
    local numeric = tonumber(hour)
    if not numeric then
        return nil
    end

    numeric = math.floor(numeric)
    return ((numeric % 24) + 24) % 24
end

local function getServerClockHour()
    local automation = Config.Automation or {}
    local timeTable = automation.blizzardNightUseUtc == true and os.date('!*t') or os.date('*t')
    return normalizeClockHour(timeTable and timeTable.hour)
end

local function getBlizzardNightWindow()
    local automation = Config.Automation or {}
    local startHour = normalizeClockHour(automation.blizzardNightStartHour or 20) or 20
    local endHour = normalizeClockHour(automation.blizzardNightEndHour or 6) or 6
    return startHour, endHour
end

local function isHourInWindow(hour, startHour, endHour)
    local normalizedHour = normalizeClockHour(hour)
    if not normalizedHour then
        return false
    end

    if startHour == endHour then
        return true
    end

    if startHour < endHour then
        return normalizedHour >= startHour and normalizedHour < endHour
    end

    return normalizedHour >= startHour or normalizedHour < endHour
end

local function isPanelActor(actor)
    return type(actor) == 'string' and actor:sub(1, 6) == 'panel:'
end

local function isBlizzardAutoWindowOpen()
    local automation = Config.Automation or {}
    if automation.blizzardNightOnly == false then
        return true
    end

    local currentHour = getServerClockHour()
    if currentHour == nil then
        return false
    end

    local startHour, endHour = getBlizzardNightWindow()
    return isHourInWindow(currentHour, startHour, endHour)
end

local function canStartDisaster(key, actor)
    if key ~= 'blizzard' then
        return true
    end

    local automation = Config.Automation or {}
    if automation.blizzardNightOnly == false or isPanelActor(actor) then
        return true
    end

    if not isBlizzardAutoWindowOpen() then
        return false, 'night_only'
    end

    return true
end

local function log(...)
    print(('[%s] %s'):format(RESOURCE, table.concat({ ... }, ' ')))
end

local function debugLog(...)
    if Config.Debug then
        log('[debug]', ...)
    end
end

local function normalizeIdentifier(identifier)
    if type(identifier) ~= 'string' then
        return nil
    end

    local normalized = string.lower(identifier)
    normalized = normalized:gsub('^identifier%.', '')
    return normalized
end

local function isIdentifierAuthorized(source)
    local adminConfig = Config.Admin or {}
    local identifiers = adminConfig.identifiers or {}
    if type(identifiers) ~= 'table' or #identifiers == 0 then
        return false
    end

    local normalizedAllowed = {}
    for i = 1, #identifiers do
        local entry = normalizeIdentifier(identifiers[i])
        if entry then
            normalizedAllowed[entry] = true
        end
    end

    if next(normalizedAllowed) == nil then
        return false
    end

    local playerIdentifiers = GetPlayerIdentifiers(source)
    if type(playerIdentifiers) ~= 'table' then
        return false
    end

    for i = 1, #playerIdentifiers do
        local playerIdentifier = normalizeIdentifier(playerIdentifiers[i])
        if playerIdentifier and normalizedAllowed[playerIdentifier] then
            return true
        end
    end

    return false
end

local function hasAdminPermission(src)
    local adminConfig = Config.Admin or {}
    if src == 0 then
        return adminConfig.allowConsole ~= false
    end

    if adminConfig.allowAcePermissions ~= false and adminConfig.aceCommand and adminConfig.aceCommand ~= '' then
        if IsPlayerAceAllowed(src, adminConfig.aceCommand) then
            return true
        end
    end

    return isIdentifierAuthorized(src)
end

local function notifyAll(message)
    if not Config.Announcements.enabled then return end
    if Config.Announcements.useChat then
        TriggerClientEvent('chat:addMessage', -1, {
            color = { 255, 180, 0 },
            multiline = true,
            args = { 'Disaster Alert', message }
        })
    end

    TriggerClientEvent('cbk_disasters:client:notify', -1, message, Config.Announcements.useFeedSound)
end

local function notifyOne(target, message)
    TriggerClientEvent('cbk_disasters:client:notify', target, message, Config.Announcements.useFeedSound)
end

local function removePanelSubscriber(src)
    local target = tonumber(src)
    if target and target > 0 then
        panelSubscribers[target] = nil
    end
end

local function addPanelSubscriber(src)
    local target = tonumber(src)
    if target and target > 0 then
        panelSubscribers[target] = true
    end
end

local function clamp(n, min, max)
    if n < min then return min end
    if n > max then return max end
    return n
end

local function randomFloat(min, max)
    if max <= min then
        return min
    end

    return min + ((math.random(0, 10000) / 10000.0) * (max - min))
end

local function normalize2D(x, y)
    local length = math.sqrt((x * x) + (y * y))
    if length <= 0.0001 then
        return 0.0, 0.0, 0.0
    end

    return x / length, y / length, length
end

local function vecDistance(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function getZoneIntensity(coords, zone, radiusOverride)
    if not coords or not zone or not zone.coords then
        return 0.0, 0.0
    end

    local radius = radiusOverride or zone.radius or 0.0
    if radius <= 0.0 then
        return 0.0, 0.0
    end

    local dist = vecDistance(coords, zone.coords)
    if dist > radius then
        return 0.0, dist
    end

    local intensityConfig = Config.Intensity or {}
    local minimum = intensityConfig.zoneMinimum or 0.12
    local exponent = intensityConfig.curveExponent or 0.80
    local raw = 1.0 - (dist / radius)
    local shaped = raw ^ exponent
    return clamp(math.max(minimum, shaped), minimum, 1.0), dist
end

local function getPlayers()
    return GetPlayers()
end

local function randomDuration(def)
    if not Config.Automation.randomizeDuration then
        return def.duration.min * 60
    end

    local minSeconds = def.duration.min * 60
    local maxSeconds = def.duration.max * 60
    return math.random(minSeconds, maxSeconds)
end

local function chooseZone(zoneKey)
    local zones = Config.Zones[zoneKey]
    if not zones or #zones == 0 then return nil end
    return zones[math.random(1, #zones)]
end

local function serializeZone(zone)
    if not zone or not zone.coords then
        return nil
    end

    return {
        name = zone.name,
        radius = zone.radius,
        coords = {
            x = zone.coords.x + 0.0,
            y = zone.coords.y + 0.0,
            z = zone.coords.z + 0.0
        }
    }
end

local function normalizeTimingValues(durationMin, durationMax, cooldownMinutes)
    local minValue = tonumber(durationMin)
    local maxValue = tonumber(durationMax)
    local cooldownValue = tonumber(cooldownMinutes)

    if not minValue or not maxValue or not cooldownValue then
        return nil
    end

    minValue = math.floor(minValue)
    maxValue = math.floor(maxValue)
    cooldownValue = math.floor(cooldownValue)

    if minValue <= 0 or maxValue < minValue or cooldownValue < 0 then
        return nil
    end

    return minValue, maxValue, cooldownValue
end

local function applyTimingValues(def, durationMin, durationMax, cooldownMinutes)
    def.duration = def.duration or {}
    def.duration.min = durationMin
    def.duration.max = durationMax
    def.cooldownMinutes = cooldownMinutes
end

local function buildTimingOverrideSnapshot()
    local snapshot = {}

    for key, def in pairs(Disasters) do
        snapshot[key] = {
            duration = {
                min = math.floor((def.duration and def.duration.min) or 0),
                max = math.floor((def.duration and def.duration.max) or 0)
            },
            cooldownMinutes = math.floor(def.cooldownMinutes or 0)
        }
    end

    return snapshot
end

local function saveTimingOverrides()
    if not json or type(json.encode) ~= 'function' then
        log('Unable to save timing overrides: json.encode is unavailable.')
        return false
    end

    local ok, encoded = pcall(json.encode, buildTimingOverrideSnapshot())
    if not ok or type(encoded) ~= 'string' then
        log('Unable to save timing overrides: failed to encode JSON.')
        return false
    end

    SaveResourceFile(RESOURCE, TIMING_OVERRIDES_FILE, encoded, #encoded)
    local persisted = LoadResourceFile(RESOURCE, TIMING_OVERRIDES_FILE)
    if persisted ~= encoded then
        log(('Unable to save timing overrides to %s.'):format(TIMING_OVERRIDES_FILE))
        return false
    end

    return true
end

local function loadTimingOverrides()
    if not json or type(json.decode) ~= 'function' then
        log('Unable to load timing overrides: json.decode is unavailable.')
        return
    end

    local raw = LoadResourceFile(RESOURCE, TIMING_OVERRIDES_FILE)
    if not raw or raw == '' then
        return
    end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then
        log(('Unable to parse %s, ignoring saved timing overrides.'):format(TIMING_OVERRIDES_FILE))
        return
    end

    for key, override in pairs(decoded) do
        local def = Disasters[key]
        if def and type(override) == 'table' then
            local duration = override.duration or {}
            local minValue, maxValue, cooldownValue = normalizeTimingValues(duration.min, duration.max, override.cooldownMinutes)
            if minValue then
                applyTimingValues(def, minValue, maxValue, cooldownValue)
            else
                debugLog(('Skipping invalid timing override for %s'):format(key))
            end
        end
    end
end

local function resolveStateHazard(state)
    if not state then
        return nil
    end

    if type(state.hazard) == 'string' and state.hazard ~= '' then
        return state.hazard
    end

    if state.context and type(state.context.hazard) == 'string' and state.context.hazard ~= '' then
        return state.context.hazard
    end

    if type(state.key) == 'string' and state.key ~= '' then
        return state.key
    end

    return nil
end

local function hydrateStateHazard(state)
    local hazard = resolveStateHazard(state)
    if not state or not hazard then
        return hazard
    end

    state.hazard = hazard
    state.context = state.context or {}
    state.context.hazard = state.context.hazard or hazard
    return hazard
end

local function getTornadoVisualZone()
    if not State.active or hydrateStateHazard(State.active) ~= 'tornado' then
        return nil
    end

    local zone = State.active.context and State.active.context.zone
    return serializeZone(zone)
end

local function clearTornadoMotion()
    tornadoMotion = nil
end

local function initializeTornadoMotion(active)
    clearTornadoMotion()

    if not active or resolveStateHazard(active) ~= 'tornado' then
        return
    end

    local zone = active.context and active.context.zone
    if not zone or not zone.coords then
        return
    end

    local moveCfg = ((Config.Hazards or {}).tornado or {}).movement or {}
    if moveCfg.enabled == false then
        return
    end

    local minSpeed = math.max(0.5, tonumber(moveCfg.minSpeed) or 4.5)
    local maxSpeed = math.max(minSpeed, tonumber(moveCfg.maxSpeed) or 8.5)
    local turnMinMs = math.max(900, math.floor(tonumber(moveCfg.turnIntervalMinMs) or 1900))
    local turnMaxMs = math.max(turnMinMs, math.floor(tonumber(moveCfg.turnIntervalMaxMs) or 4200))
    local configuredTravelRadius = tonumber(moveCfg.maxTravelRadius)
    local movementRadius = math.max(
        18.0,
        configuredTravelRadius or ((zone.radius or 100.0) * (tonumber(moveCfg.zoneRadiusRatio) or 0.55))
    )
    local initialAngle = randomFloat(0.0, math.pi * 2.0)

    tornadoMotion = {
        originX = zone.coords.x + 0.0,
        originY = zone.coords.y + 0.0,
        originZ = zone.coords.z + 0.0,
        posX = zone.coords.x + 0.0,
        posY = zone.coords.y + 0.0,
        dirX = math.cos(initialAngle),
        dirY = math.sin(initialAngle),
        speed = randomFloat(minSpeed, maxSpeed),
        minSpeed = minSpeed,
        maxSpeed = maxSpeed,
        turnJitterRadians = math.rad(tonumber(moveCfg.turnJitterDegrees) or 30.0),
        turnTowardCenterWeight = clamp(tonumber(moveCfg.turnTowardCenterWeight) or 0.42, 0.0, 1.0),
        maxOffset = movementRadius,
        turnMinMs = turnMinMs,
        turnMaxMs = turnMaxMs,
        nextTurnAt = GetGameTimer() + math.random(turnMinMs, turnMaxMs),
        lastUpdateMs = GetGameTimer(),
        lastBroadcastAt = GetGameTimer()
    }
end

local function updateTornadoMovement()
    local active = State.active
    if not active or resolveStateHazard(active) ~= 'tornado' then
        clearTornadoMotion()
        return
    end

    local zone = active.context and active.context.zone
    if not zone or not zone.coords then
        return
    end

    local moveCfg = ((Config.Hazards or {}).tornado or {}).movement or {}
    if moveCfg.enabled == false then
        return
    end

    if not tornadoMotion then
        initializeTornadoMotion(active)
        if not tornadoMotion then
            return
        end
    end

    local nowMs = GetGameTimer()
    local dt = (nowMs - (tornadoMotion.lastUpdateMs or nowMs)) / 1000.0
    if dt <= 0.0 then
        return
    end
    tornadoMotion.lastUpdateMs = nowMs

    if nowMs >= (tornadoMotion.nextTurnAt or 0) then
        local toCenterX = tornadoMotion.originX - tornadoMotion.posX
        local toCenterY = tornadoMotion.originY - tornadoMotion.posY
        local centerX, centerY = normalize2D(toCenterX, toCenterY)
        local blend = tornadoMotion.turnTowardCenterWeight
        local mixedX = (tornadoMotion.dirX * (1.0 - blend)) + (centerX * blend)
        local mixedY = (tornadoMotion.dirY * (1.0 - blend)) + (centerY * blend)
        local normX, normY = normalize2D(mixedX, mixedY)
        if normX == 0.0 and normY == 0.0 then
            local a = randomFloat(0.0, math.pi * 2.0)
            normX = math.cos(a)
            normY = math.sin(a)
        end

        local jitter = randomFloat(-tornadoMotion.turnJitterRadians, tornadoMotion.turnJitterRadians)
        local cosJ = math.cos(jitter)
        local sinJ = math.sin(jitter)
        tornadoMotion.dirX = (normX * cosJ) - (normY * sinJ)
        tornadoMotion.dirY = (normX * sinJ) + (normY * cosJ)
        tornadoMotion.speed = randomFloat(tornadoMotion.minSpeed, tornadoMotion.maxSpeed)
        tornadoMotion.nextTurnAt = nowMs + math.random(tornadoMotion.turnMinMs, tornadoMotion.turnMaxMs)
    end

    local nextX = tornadoMotion.posX + (tornadoMotion.dirX * tornadoMotion.speed * dt)
    local nextY = tornadoMotion.posY + (tornadoMotion.dirY * tornadoMotion.speed * dt)
    local deltaX = nextX - tornadoMotion.originX
    local deltaY = nextY - tornadoMotion.originY
    local _, _, offsetLength = normalize2D(deltaX, deltaY)

    if offsetLength > tornadoMotion.maxOffset then
        local edgeX = tornadoMotion.originX + (deltaX / offsetLength) * tornadoMotion.maxOffset
        local edgeY = tornadoMotion.originY + (deltaY / offsetLength) * tornadoMotion.maxOffset
        nextX = edgeX
        nextY = edgeY

        local towardCenterX, towardCenterY = normalize2D(tornadoMotion.originX - edgeX, tornadoMotion.originY - edgeY)
        if towardCenterX ~= 0.0 or towardCenterY ~= 0.0 then
            tornadoMotion.dirX = towardCenterX
            tornadoMotion.dirY = towardCenterY
        end
    end

    tornadoMotion.posX = nextX
    tornadoMotion.posY = nextY
    zone.coords = {
        x = nextX,
        y = nextY,
        z = tornadoMotion.originZ
    }

    if moveCfg.broadcastUpdates ~= false then
        local broadcastIntervalMs = math.max(150, math.floor(tonumber(moveCfg.broadcastIntervalMs) or 250))
        if (nowMs - (tornadoMotion.lastBroadcastAt or 0)) >= broadcastIntervalMs then
            tornadoMotion.lastBroadcastAt = nowMs
            TriggerClientEvent('cbk_disasters:client:setTornadoVisual', -1, getTornadoVisualZone())
        end
    end
end

local function buildContext(def)
    local context = {
        hazard = def.hazard
    }

    if def.requiresZone then
        context.zone = serializeZone(chooseZone(def.requiresZone))
    end

    return context
end

local function buildPanelData()
    local ts = now()
    local disasters = {}
    local panelActive = nil

    for _, def in pairs(Disasters) do
        local entry = {
            key = def.key,
            label = def.label,
            hazard = def.hazard,
            announcement = def.announcement,
            duration = def.duration,
        cooldownSeconds = (def.cooldownMinutes or 0) * 60,
        cooldownMinutes = def.cooldownMinutes or 0
        }

        local status = 'ready'
        if State.active and State.active.key == def.key then
            status = 'active'
            entry.remainingSeconds = math.max(0, (State.active.endsAt or 0) - ts)
        else
            local lastRun = State.lastRun[def.key] or 0
            local elapsed = ts - lastRun
            local cooldownRemaining = math.max(0, entry.cooldownSeconds - elapsed)
            entry.cooldownRemaining = cooldownRemaining
            if cooldownRemaining > 0 then
                status = 'cooldown'
            end
        end

        if status == 'active' then
            panelActive = {
                key = def.key,
                label = def.label,
                endsAt = State.active.endsAt,
                remainingSeconds = entry.remainingSeconds
            }
        end

        entry.status = status
        disasters[#disasters + 1] = entry
    end

    table.sort(disasters, function(a, b)
        return a.label < b.label
    end)

    return {
        disasters = disasters,
        active = panelActive,
        automationNextEventSeconds = math.max(0, State.nextEventAt - ts),
        timestamp = ts
    }
end

local function broadcastPanelData()
    local panelData = buildPanelData()

    for src in pairs(panelSubscribers) do
        if not GetPlayerName(src) or not hasAdminPermission(src) then
            panelSubscribers[src] = nil
        else
            TriggerClientEvent('cbk_disasters:client:updatePanel', src, panelData)
        end
    end
end

local function sendPanelData(target)
    local src = tonumber(target)
    if src and src > 0 and hasAdminPermission(src) then
        TriggerClientEvent('cbk_disasters:client:updatePanel', src, buildPanelData())
    end
end

local function openPanelFor(target)
    local src = tonumber(target)
    if not src or src <= 0 or not hasAdminPermission(src) then
        return false
    end

    addPanelSubscriber(src)
    TriggerClientEvent('cbk_disasters:client:openPanel', src, buildPanelData())
    return true
end

local function setGlobalState()
    hydrateStateHazard(State.active)
    GlobalState[Config.Sync.stateBagName] = State.active
    TriggerClientEvent('cbk_disasters:client:setState', -1, State.active)
    TriggerClientEvent('cbk_disasters:client:setTornadoVisual', -1, getTornadoVisualZone())
    broadcastPanelData()
end

local function scheduleNextRandom()
    local minSecs = Config.Automation.minMinutesBetweenEvents * 60
    local maxSecs = Config.Automation.maxMinutesBetweenEvents * 60
    State.nextEventAt = now() + math.random(minSecs, maxSecs)
    debugLog('Next disaster scheduled at', tostring(State.nextEventAt))
    broadcastPanelData()
end

local function stopDisaster(reason)
    if not State.active then return false end

    local activeLabel = State.active.label
    State.active = nil
    clearTornadoMotion()
    State.reminderAt = 0
    State.seq = State.seq + 1
    setGlobalState()
    scheduleNextRandom()

    if reason ~= 'silent' then
        notifyAll(('The %s has ended. Conditions are stabilizing.'):format(activeLabel))
    end

    log('Stopped active disaster.')
    return true
end

local function startDisaster(key, actor)
    local def = Disasters[key]
    if not def then
        return false, 'invalid'
    end

    local allowed, reason = canStartDisaster(key, actor)
    if not allowed then
        return false, reason
    end

    if State.active then
        stopDisaster('replace')
    end

    local duration = randomDuration(def)
    local context = buildContext(def)
    State.seq = State.seq + 1

    State.active = {
        key = def.key,
        hazard = def.hazard,
        label = def.label,
        announcement = def.announcement,
        weather = def.weather,
        rainLevel = def.rainLevel,
        windSpeed = def.windSpeed,
        timecycle = def.timecycle,
        startedAt = now(),
        endsAt = now() + duration,
        durationSeconds = duration,
        context = context,
        seq = State.seq,
        startedBy = actor or 'automation'
    }

    State.lastRun[key] = now()
    initializeTornadoMotion(State.active)
    State.reminderAt = now() + (Config.Announcements.repeatReminderMinutes * 60)
    setGlobalState()

    notifyAll(def.announcement)
    log(('Started disaster %s (duration=%ss)'):format(key, duration))
    return true
end

local function chooseRandomDisaster()
    local pool = {}
    local ts = now()
    local allowBlizzard = isBlizzardAutoWindowOpen()

    for key, def in pairs(Disasters) do
        if key ~= 'blizzard' or allowBlizzard then
            local cooldown = def.cooldownMinutes * 60
            local lastRun = State.lastRun[key] or 0
            if ts - lastRun >= cooldown then
                for _ = 1, (def.weight or 1) do
                    pool[#pool + 1] = key
                end
            end
        end
    end

    if #pool == 0 then
        return nil
    end

    return pool[math.random(1, #pool)]
end

local function applyServerDamage(src, _, amount, hazard)
    local damage = math.max(0, math.floor(tonumber(amount) or 0))
    if damage <= 0 then return end
    local target = tonumber(src)

    if target and target > 0 then
        TriggerClientEvent('cbk_disasters:client:applyDamage', target, {
            amount = damage,
            hazard = hazard
        })
    end
end

local function playerInVehicle(ped)
    return GetVehiclePedIsIn(ped, false) ~= 0
end

local function processHeatwave(src, ped, coords)
    local hz = Config.Hazards.heatwave
    if not hz.enabled then return end
    if hz.vehicleProtection and playerInVehicle(ped) then return end
    applyServerDamage(src, ped, hz.pedestrianDamage, 'heatwave')
    TriggerClientEvent('cbk_disasters:client:hazard', src, {
        kind = 'heatwave',
        staminaDrain = hz.sprintStaminaDrain
    })
end

local function processLightning(src, ped, coords, key)
    local hz = Config.Hazards[key]
    if not hz.enabled then return end
    if math.random() > hz.lightningStrikeChance then return end

    local strike = {
        x = coords.x + math.random(-hz.strikeRadius * 10, hz.strikeRadius * 10) / 10.0,
        y = coords.y + math.random(-hz.strikeRadius * 10, hz.strikeRadius * 10) / 10.0,
        z = coords.z
    }

    applyServerDamage(src, ped, hz.strikeDamage, key)
    TriggerClientEvent('cbk_disasters:client:hazard', -1, {
        kind = 'lightning',
        coords = strike,
        target = tonumber(src)
    })
end

local function processTornado(src, ped, coords, active)
    local hz = Config.Hazards.tornado
    if not hz.enabled then return end
    local zone = active.context and active.context.zone
    if not zone then return end

    local effectiveRadius = math.min(zone.radius or hz.pullRadius, hz.pullRadius)
    local intensity, dist = getZoneIntensity(coords, zone, effectiveRadius)
    if intensity <= 0.0 then return end

    local lethal = dist <= hz.lethalCoreRadius
    if lethal then
        applyServerDamage(src, ped, math.max(35, math.ceil(35 * (0.75 + intensity))), 'tornado')
    else
        applyServerDamage(src, ped, math.max(1, math.ceil(hz.debrisDamage * (0.45 + intensity))), 'tornado')
    end

    TriggerClientEvent('cbk_disasters:client:hazard', src, {
        kind = 'tornado',
        center = zone.coords,
        zone = zone,
        intensity = intensity,
        distance = dist,
        maxForceDistance = hz.maxForceDistance,
        pullRadius = effectiveRadius,
        lethalCoreRadius = hz.lethalCoreRadius,
        vehicleLiftScale = clamp(0.55 + (intensity * 1.10), 0.55, 1.75),
        vehicleSpinScale = clamp(0.40 + (intensity * 0.95), 0.40, 1.45),
        stallChance = clamp(hz.vehicleEngineStallChance * (0.45 + intensity), 0.02, 0.95)
    })
end

local function processRegionalDamage(src, ped, coords, active)
    local hazard = hydrateStateHazard(active)
    local hz = Config.Hazards[hazard]
    if not hz then return end
    if not hz.enabled then return end
    local zone = active.context and active.context.zone
    local intensity, dist = 1.0, 0.0
    if zone then
        intensity, dist = getZoneIntensity(coords, zone)
        if intensity <= 0.0 then return end
    end

    local pedestrianDamage = math.max(1, math.ceil(hz.pedestrianDamage * (0.35 + intensity)))
    applyServerDamage(src, ped, pedestrianDamage, hazard)
    TriggerClientEvent('cbk_disasters:client:hazard', src, {
        kind = hazard,
        zone = zone,
        intensity = intensity,
        distance = dist
    })
end

local function processHazards()
    local active = State.active
    if not active then return end
    local hazard = hydrateStateHazard(active)
    if not hazard then return end

    for _, src in ipairs(getPlayers()) do
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            if hazard == 'heatwave' then
                processHeatwave(src, ped, coords)
            elseif hazard == 'thunderstorm' then
                processLightning(src, ped, coords, 'thunderstorm')
            elseif hazard == 'tornado' then
                processTornado(src, ped, coords, active)
            elseif hazard == 'blizzard' or hazard == 'duststorm' or hazard == 'wildfire_smoke' then
                processRegionalDamage(src, ped, coords, active)
            end
        end
    end
end

RegisterNetEvent('cbk_disasters:server:requestState', function()
    local src = source
    if not canServeStateRequest(src) then
        return
    end

    hydrateStateHazard(State.active)
    TriggerClientEvent('cbk_disasters:client:setState', src, State.active)
    TriggerClientEvent('cbk_disasters:client:setTornadoVisual', src, getTornadoVisualZone())
end)

RegisterNetEvent('cbk_disasters:server:requestOpenPanel', function()
    local src = source
    if not hasAdminPermission(src) then
        if src > 0 then
            notifyOne(src, Config.Locale.adminOnly)
        end
        return
    end

    openPanelFor(src)
end)

RegisterNetEvent('cbk_disasters:server:panelClosed', function()
    removePanelSubscriber(source)
end)

RegisterNetEvent('cbk_disasters:server:toggleTornadoDebug', function(action)
    local src = source
    if Config.Debug ~= true then
        return
    end

    if not hasAdminPermission(src) then
        if src > 0 then
            notifyOne(src, Config.Locale.adminOnly)
        end
        return
    end

    TriggerClientEvent('cbk_disasters:client:setTornadoDebug', src, tostring(action or 'toggle'))
end)

RegisterCommand('disaster_start', function(src, args)
    if not hasAdminPermission(src) then
        if src > 0 then
            notifyOne(src, Config.Locale.adminOnly)
        end
        return
    end

    local key = tostring(args[1] or '')
    if key == '' or not Disasters[key] then
        if src > 0 then
            notifyOne(src, Config.Locale.invalidDisaster)
        else
            log('Usage: disaster_start <key>')
        end
        return
    end

    local ok, reason = startDisaster(key, ('admin:%s'):format(src))
    if not ok then
        if reason == 'night_only' then
            if src > 0 then
                notifyOne(src, Config.Locale.blizzardNightOnly)
            else
                log(Config.Locale.blizzardNightOnly)
            end
        end
        return
    end

    if src > 0 then
        notifyOne(src, ('%s %s'):format(Config.Locale.disasterStarted, key))
    end
end, false)

RegisterCommand('disaster_stop', function(src)
    if not hasAdminPermission(src) then
        if src > 0 then
            notifyOne(src, Config.Locale.adminOnly)
        end
        return
    end

    if stopDisaster() and src > 0 then
        notifyOne(src, Config.Locale.disasterStopped)
    elseif src > 0 then
        notifyOne(src, Config.Locale.noActiveDisaster)
    end
end, false)

RegisterCommand('disaster_status', function(src)
    local msg
    if State.active then
        local remaining = math.max(0, State.active.endsAt - now())
        msg = ('Active: %s | Remaining: %sm'):format(State.active.label, math.ceil(remaining / 60))
    else
        local eta = math.max(0, State.nextEventAt - now())
        msg = ('No active disaster. Next automation window in ~%sm'):format(math.ceil(eta / 60))
    end

    if src > 0 then
        notifyOne(src, msg)
    else
        log(msg)
    end
end, false)

RegisterNetEvent('cbk_disasters:server:requestPanelData', function()
    local src = source
    if not hasAdminPermission(src) then
        if src > 0 then
            notifyOne(src, Config.Locale.adminOnly)
        end
        removePanelSubscriber(src)
        return
    end

    addPanelSubscriber(src)
    sendPanelData(src)
end)

RegisterNetEvent('cbk_disasters:server:startDisasterFromPanel', function(data)
    local src = source
    if not hasAdminPermission(src) then
        if src > 0 then
            notifyOne(src, Config.Locale.adminOnly)
        end
        return
    end

    if not data or type(data.key) ~= 'string' then
        if src > 0 then
            notifyOne(src, Config.Locale.invalidDisaster)
        end
        return
    end

    local key = tostring(data.key)
    local ok, reason = startDisaster(key, ('panel:%s'):format(src))
    if not ok then
        if reason == 'invalid' and src > 0 then
            notifyOne(src, Config.Locale.invalidDisaster)
        end
        return
    end

    if src > 0 then
        notifyOne(src, ('%s %s'):format(Config.Locale.disasterStarted, key))
    end
end)

RegisterNetEvent('cbk_disasters:server:stopDisasterFromPanel', function()
    local src = source
    if not hasAdminPermission(src) then
        if src > 0 then
            notifyOne(src, Config.Locale.adminOnly)
        end
        return
    end

    if stopDisaster('panel') then
        if src > 0 then
            notifyOne(src, Config.Locale.disasterStopped)
        end
    elseif src > 0 then
        notifyOne(src, Config.Locale.noActiveDisaster)
    end
end)

RegisterNetEvent('cbk_disasters:server:updateDisasterTimesFromPanel', function(data)
    local src = source
    if not hasAdminPermission(src) then
        if src > 0 then
            notifyOne(src, Config.Locale.adminOnly)
        end
        return
    end

    if not data or type(data.key) ~= 'string' then
        if src > 0 then
            notifyOne(src, Config.Locale.invalidDisaster)
        end
        return
    end

    local key = tostring(data.key)
    local def = Disasters[key]
    if not def then
        if src > 0 then
            notifyOne(src, Config.Locale.invalidDisaster)
        end
        return
    end

    local durationMin, durationMax, cooldownMinutes = normalizeTimingValues(data.durationMin, data.durationMax, data.cooldownMinutes)
    if not durationMin then
        if src > 0 then
            notifyOne(src, Config.Locale.invalidTiming)
        end
        return
    end

    applyTimingValues(def, durationMin, durationMax, cooldownMinutes)
    local saved = saveTimingOverrides()

    broadcastPanelData()

    if src > 0 then
        notifyOne(src, saved and Config.Locale.timingUpdated or Config.Locale.timingSaveFailed)
    end
end)

exports('GetActiveDisaster', function()
    return State.active
end)

exports('StartDisaster', function(key, actor)
    return startDisaster(key, actor or 'export')
end)

exports('StopDisaster', function(reason)
    return stopDisaster(reason or 'export')
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE then return end
    math.randomseed(GetGameTimer() + os.time())
    loadTimingOverrides()
    scheduleNextRandom()
    setGlobalState()
    log('Resource started.')
end)

AddEventHandler('playerJoining', function()
    local src = source
    hydrateStateHazard(State.active)
    if State.active then
        TriggerClientEvent('cbk_disasters:client:setState', src, State.active)
    end
    TriggerClientEvent('cbk_disasters:client:setTornadoVisual', src, getTornadoVisualZone())
end)

AddEventHandler('playerDropped', function()
    stateRequestThrottle[source] = nil
    removePanelSubscriber(source)
end)

CreateThread(function()
    while true do
        Wait(5000)

        if State.active then
            if now() >= State.active.endsAt then
                stopDisaster()
            elseif State.reminderAt > 0 and now() >= State.reminderAt then
                notifyAll(State.active.announcement)
                State.reminderAt = now() + (Config.Announcements.repeatReminderMinutes * 60)
            end
        elseif Config.Automation.enabled and State.nextEventAt > 0 and now() >= State.nextEventAt then
            local key = chooseRandomDisaster()
            if key then
                startDisaster(key, 'automation')
            else
                scheduleNextRandom()
            end
        end
    end
end)

CreateThread(function()
    while true do
        local moveCfg = ((Config.Hazards or {}).tornado or {}).movement or {}
        local intervalMs = math.max(80, math.floor(tonumber(moveCfg.updateIntervalMs) or 600))

        if moveCfg.enabled ~= false and State.active and resolveStateHazard(State.active) == 'tornado' then
            updateTornadoMovement()
            Wait(intervalMs)
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.Hazards.tickMs)
        if State.active then
            processHazards()
        end
    end
end)
