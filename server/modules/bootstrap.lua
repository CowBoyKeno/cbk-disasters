RESOURCE = GetCurrentResourceName()

State = {
    active = nil,
    nextEventAt = 0,
    lastRun = {},
    reminderAt = 0,
    seq = 0,
    systemEnabled = ((Config.System or {}).enabled ~= false)
}
tornadoMotion = nil
panelSubscribers = {}
stateRequestThrottle = {}
TIMING_OVERRIDES_FILE = 'timing_overrides.json'

function now()
    return os.time()
end

function canServeStateRequest(src)
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

function normalizeClockHour(hour)
    local numeric = tonumber(hour)
    if not numeric then
        return nil
    end

    numeric = math.floor(numeric)
    return ((numeric % 24) + 24) % 24
end

function getServerClockHour()
    local automation = Config.Automation or {}
    local timeTable = automation.blizzardNightUseUtc == true and os.date('!*t') or os.date('*t')
    return normalizeClockHour(timeTable and timeTable.hour)
end

function getBlizzardNightWindow()
    local automation = Config.Automation or {}
    local startHour = normalizeClockHour(automation.blizzardNightStartHour or 20) or 20
    local endHour = normalizeClockHour(automation.blizzardNightEndHour or 6) or 6
    return startHour, endHour
end

function isHourInWindow(hour, startHour, endHour)
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

function isPanelActor(actor)
    return type(actor) == 'string' and actor:sub(1, 6) == 'panel:'
end

function isBlizzardAutoWindowOpen()
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

function getHazardConfig(hazardOrDef)
    local hazardKey = hazardOrDef
    if type(hazardOrDef) == 'table' then
        hazardKey = hazardOrDef.hazard
    end

    if type(hazardKey) ~= 'string' or hazardKey == '' then
        return nil, nil
    end

    return (Config.Hazards or {})[hazardKey], hazardKey
end

function getValidZones(zoneKey)
    local zones = (Config.Zones or {})[zoneKey]
    local validZones = {}

    if type(zones) ~= 'table' then
        return validZones
    end

    for i = 1, #zones do
        local zone = zones[i]
        local radius = type(zone) == 'table' and tonumber(zone.radius) or nil
        if type(zone) == 'table' and zone.coords and radius and radius > 0.0 then
            validZones[#validZones + 1] = zone
        end
    end

    return validZones
end

function hasValidZoneConfig(zoneKey)
    return #getValidZones(zoneKey) > 0
end

function normalizeTransitionConfig(transition)
    local defaults = Config.Transitions or {}
    local source = type(transition) == 'table' and transition or {}

    local inMinutes = tonumber(source.inMinutes)
    if inMinutes == nil then
        inMinutes = tonumber(defaults.inMinutes) or 3
    end

    local outMinutes = tonumber(source.outMinutes)
    if outMinutes == nil then
        outMinutes = tonumber(defaults.outMinutes) or inMinutes
    end

    local curveExponent = tonumber(source.curveExponent)
    if curveExponent == nil then
        curveExponent = tonumber(defaults.curveExponent) or 1.0
    end

    return {
        inSeconds = math.max(0, math.floor(inMinutes * 60)),
        outSeconds = math.max(0, math.floor(outMinutes * 60)),
        curveExponent = math.max(0.1, curveExponent)
    }
end

function getDisasterTransitionConfig(defOrState)
    if type(defOrState) ~= 'table' then
        return normalizeTransitionConfig(nil)
    end

    local transition = defOrState.transition
    if type(transition) == 'table' and transition.inSeconds ~= nil and transition.outSeconds ~= nil then
        return {
            inSeconds = math.max(0, math.floor(tonumber(transition.inSeconds) or 0)),
            outSeconds = math.max(0, math.floor(tonumber(transition.outSeconds) or 0)),
            curveExponent = math.max(0.1, tonumber(transition.curveExponent) or 1.0)
        }
    end

    return normalizeTransitionConfig(transition)
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

function getDisasterTransitionIntensity(state, timestamp)
    if type(state) ~= 'table' then
        return 0.0
    end

    local duration = math.max(0, math.floor(tonumber(state.durationSeconds) or 0))
    if duration <= 0 then
        return 1.0
    end

    local transition = getDisasterTransitionConfig(state)
    local ts = math.floor(tonumber(timestamp) or now())
    local startedAt = math.floor(tonumber(state.startedAt) or ts)
    local endsAt = math.floor(tonumber(state.endsAt) or (startedAt + duration))
    local elapsed = math.max(0, ts - startedAt)
    local remaining = math.max(0, endsAt - ts)
    local fadeIn = transition.inSeconds or 0
    local fadeOut = transition.outSeconds or 0
    local fadeInRatio = fadeIn > 0 and math.min(1.0, elapsed / fadeIn) or 1.0
    local fadeOutRatio = fadeOut > 0 and math.min(1.0, remaining / fadeOut) or 1.0

    return shapeTransitionIntensity(math.min(fadeInRatio, fadeOutRatio), transition.curveExponent)
end

function canStartDisaster(key, actor)
    local def = Disasters[key]
    if not def then
        return false, 'invalid'
    end

    if State.active then
        return false, 'active'
    end

    local hazardConfig = getHazardConfig(def)
    if not hazardConfig then
        return false, 'invalid_config'
    end

    if hazardConfig.enabled == false then
        return false, 'event_disabled'
    end

    if def.requiresZone and not hasValidZoneConfig(def.requiresZone) then
        return false, 'zone_unavailable'
    end

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

function log(...)
    print(('[%s] %s'):format(RESOURCE, table.concat({ ... }, ' ')))
end

function debugLog(...)
    if Config.Debug then
        log('[debug]', ...)
    end
end

function normalizeIdentifier(identifier)
    if type(identifier) ~= 'string' then
        return nil
    end

    local normalized = string.lower(identifier)
    normalized = normalized:gsub('^identifier%.', '')
    return normalized
end

function isIdentifierAuthorized(source)
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

function hasAdminPermission(src)
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

function isSystemEnabled()
    return State.systemEnabled ~= false
end

function isAutomationEnabled()
    local automation = Config.Automation or {}
    return isSystemEnabled() and automation.enabled ~= false
end

function notifyAll(message)
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

function notifyOne(target, message)
    TriggerClientEvent('cbk_disasters:client:notify', target, message, Config.Announcements.useFeedSound)
end

function removePanelSubscriber(src)
    local target = tonumber(src)
    if target and target > 0 then
        panelSubscribers[target] = nil
    end
end

function addPanelSubscriber(src)
    local target = tonumber(src)
    if target and target > 0 then
        panelSubscribers[target] = true
    end
end

function clamp(n, min, max)
    if n < min then return min end
    if n > max then return max end
    return n
end

function randomFloat(min, max)
    if max <= min then
        return min
    end

    return min + ((math.random(0, 10000) / 10000.0) * (max - min))
end

function normalize2D(x, y)
    local length = math.sqrt((x * x) + (y * y))
    if length <= 0.0001 then
        return 0.0, 0.0, 0.0
    end

    return x / length, y / length, length
end

function vecDistance(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function getZoneIntensity(coords, zone, radiusOverride)
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

function getPlayers()
    return GetPlayers()
end

function randomDuration(def)
    local duration = def and def.duration or {}
    local minMinutes = tonumber(duration.min)
    local maxMinutes = tonumber(duration.max)
    if not minMinutes or not maxMinutes then
        return 60
    end

    minMinutes = math.max(1, math.floor(minMinutes))
    maxMinutes = math.max(minMinutes, math.floor(maxMinutes))

    if not Config.Automation.randomizeDuration then
        return minMinutes * 60
    end

    local minSeconds = minMinutes * 60
    local maxSeconds = maxMinutes * 60
    return math.random(minSeconds, maxSeconds)
end

function chooseZone(zoneKey)
    local zones = getValidZones(zoneKey)
    if #zones == 0 then return nil end
    return zones[math.random(1, #zones)]
end

function serializeZone(zone)
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

function normalizeTimingValues(durationMin, durationMax, cooldownMinutes)
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

function validateDisasterDefinition(key, def)
    local issues = {}

    if type(def) ~= 'table' then
        issues[#issues + 1] = ('%s: definition must be a table.'):format(tostring(key))
        return issues
    end

    if def.key ~= key then
        issues[#issues + 1] = ('%s: def.key must match the disaster key.'):format(tostring(key))
    end

    if type(def.label) ~= 'string' or def.label == '' then
        issues[#issues + 1] = ('%s: label must be a non-empty string.'):format(tostring(key))
    end

    if type(def.announcement) ~= 'string' or def.announcement == '' then
        issues[#issues + 1] = ('%s: announcement must be a non-empty string.'):format(tostring(key))
    end

    if type(def.weather) ~= 'string' or def.weather == '' then
        issues[#issues + 1] = ('%s: weather must be a non-empty string.'):format(tostring(key))
    end

    local hazardConfig, hazardKey = getHazardConfig(def)
    if not hazardKey then
        issues[#issues + 1] = ('%s: hazard must be a non-empty string.'):format(tostring(key))
    elseif not hazardConfig then
        issues[#issues + 1] = ('%s: missing Config.Hazards.%s definition.'):format(tostring(key), hazardKey)
    end

    local weight = tonumber(def.weight or 1)
    if not weight or weight <= 0 then
        issues[#issues + 1] = ('%s: weight must be a positive number.'):format(tostring(key))
    end

    local duration = def.duration or {}
    local minValue, maxValue, cooldownValue = normalizeTimingValues(duration.min, duration.max, def.cooldownMinutes)
    if not minValue then
        issues[#issues + 1] = ('%s: duration.min, duration.max, and cooldownMinutes must be valid integers.'):format(tostring(key))
    elseif maxValue < minValue or cooldownValue < 0 then
        issues[#issues + 1] = ('%s: duration/cooldown values are out of range.'):format(tostring(key))
    end

    if def.requiresZone then
        if type(def.requiresZone) ~= 'string' or def.requiresZone == '' then
            issues[#issues + 1] = ('%s: requiresZone must be a non-empty string when set.'):format(tostring(key))
        elseif not hasValidZoneConfig(def.requiresZone) then
            issues[#issues + 1] = ('%s: requires at least one valid zone in Config.Zones.%s.'):format(tostring(key), def.requiresZone)
        end
    end

    if def.transition ~= nil then
        if type(def.transition) ~= 'table' then
            issues[#issues + 1] = ('%s: transition must be a table when set.'):format(tostring(key))
        else
            local inMinutes = def.transition.inMinutes
            local outMinutes = def.transition.outMinutes
            local curveExponent = def.transition.curveExponent

            if inMinutes ~= nil and (not tonumber(inMinutes) or tonumber(inMinutes) < 0) then
                issues[#issues + 1] = ('%s: transition.inMinutes must be a number greater than or equal to 0.'):format(tostring(key))
            end

            if outMinutes ~= nil and (not tonumber(outMinutes) or tonumber(outMinutes) < 0) then
                issues[#issues + 1] = ('%s: transition.outMinutes must be a number greater than or equal to 0.'):format(tostring(key))
            end

            if curveExponent ~= nil and (not tonumber(curveExponent) or tonumber(curveExponent) <= 0) then
                issues[#issues + 1] = ('%s: transition.curveExponent must be a number greater than 0.'):format(tostring(key))
            end
        end
    end

    return issues
end

function validateDisasterConfiguration()
    local issues = {}

    for key, def in pairs(Disasters) do
        local definitionIssues = validateDisasterDefinition(key, def)
        for i = 1, #definitionIssues do
            issues[#issues + 1] = definitionIssues[i]
        end
    end

    table.sort(issues)
    return #issues == 0, issues
end

function applyTimingValues(def, durationMin, durationMax, cooldownMinutes)
    def.duration = def.duration or {}
    def.duration.min = durationMin
    def.duration.max = durationMax
    def.cooldownMinutes = cooldownMinutes
end

function buildTimingOverrideSnapshot()
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

function saveTimingOverrides()
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

function loadTimingOverrides()
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

function resolveStateHazard(state)
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

function hydrateStateHazard(state)
    local hazard = resolveStateHazard(state)
    if not state or not hazard then
        return hazard
    end

    state.hazard = hazard
    state.context = state.context or {}
    state.context.hazard = state.context.hazard or hazard
    return hazard
end

function getTornadoVisualZone()
    if not State.active or hydrateStateHazard(State.active) ~= 'tornado' then
        return nil
    end

    local zone = State.active.context and State.active.context.zone
    return serializeZone(zone)
end

function clearTornadoMotion()
    tornadoMotion = nil
end

function initializeTornadoMotion(active)
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

function updateTornadoMovement()
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

function buildContext(def)
    local context = {
        hazard = def.hazard
    }

    if def.requiresZone then
        local zone = chooseZone(def.requiresZone)
        context.zone = serializeZone(zone)
        if not context.zone then
            return nil, 'zone_unavailable'
        end
    end

    return context
end

stopDisaster = nil

