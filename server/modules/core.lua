function setGlobalState()
    hydrateStateHazard(State.active)
    GlobalState[Config.Sync.stateBagName] = State.active
    TriggerClientEvent('cbk_disasters:client:setState', -1, State.active)
    TriggerClientEvent('cbk_disasters:client:setTornadoVisual', -1, getTornadoVisualZone())
    broadcastPanelData()
end

function scheduleNextRandom()
    if not isAutomationEnabled() then
        State.nextEventAt = 0
        debugLog('Automatic scheduling is disabled.')
        broadcastPanelData()
        return
    end

    local minSecs = Config.Automation.minMinutesBetweenEvents * 60
    local maxSecs = Config.Automation.maxMinutesBetweenEvents * 60
    State.nextEventAt = now() + math.random(minSecs, maxSecs)
    debugLog('Next disaster scheduled at', tostring(State.nextEventAt))
    broadcastPanelData()
end

function setSystemEnabled(enabled, actor)
    local normalized = enabled ~= false
    if State.systemEnabled == normalized then
        return false
    end

    State.systemEnabled = normalized
    State.reminderAt = 0

    if normalized then
        if not State.active then
            scheduleNextRandom()
        else
            broadcastPanelData()
        end
        log(('Disaster system enabled by %s.'):format(tostring(actor or 'unknown')))
        return true
    end

    if State.active then
        stopDisaster('silent')
    else
        State.nextEventAt = 0
        clearTornadoMotion()
        setGlobalState()
    end

    log(('Disaster system disabled by %s.'):format(tostring(actor or 'unknown')))
    return true
end

stopDisaster = function(reason)
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

function startDisaster(key, actor)
    local def = Disasters[key]
    if not def then
        return false, 'invalid'
    end

    if not isSystemEnabled() then
        return false, 'disabled'
    end

    local allowed, reason = canStartDisaster(key, actor)
    if not allowed then
        return false, reason
    end

    local duration = randomDuration(def)
    local context, contextReason = buildContext(def)
    if not context then
        return false, contextReason or 'invalid_config'
    end
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
        transition = getDisasterTransitionConfig(def),
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

function chooseRandomDisaster()
    local pool = {}
    local ts = now()

    for key, def in pairs(Disasters) do
        local allowed, reason = canStartDisaster(key, 'automation')
        if allowed then
            local cooldown = def.cooldownMinutes * 60
            local lastRun = State.lastRun[key] or 0
            if ts - lastRun >= cooldown then
                for _ = 1, (def.weight or 1) do
                    pool[#pool + 1] = key
                end
            end
        elseif reason == 'zone_unavailable' or reason == 'invalid_config' then
            debugLog(('Skipping disaster %s for automation: %s'):format(key, reason))
        end
    end

    if #pool == 0 then
        return nil
    end

    return pool[math.random(1, #pool)]
end

function applyServerDamage(src, _, amount, hazard)
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

function playerInVehicle(ped)
    return GetVehiclePedIsIn(ped, false) ~= 0
end

function processHeatwave(src, ped, coords, active)
    local hz = Config.Hazards.heatwave
    if not hz.enabled then return end
    if hz.vehicleProtection and playerInVehicle(ped) then return end
    local intensity = getDisasterTransitionIntensity(active)
    if intensity <= 0.0 then return end
    if math.random() > intensity then return end

    local damageScale = 0.25 + (intensity * 0.75)
    local damage = math.max(1, math.floor((hz.pedestrianDamage * damageScale) + 0.5))
    applyServerDamage(src, ped, damage, 'heatwave')
    TriggerClientEvent('cbk_disasters:client:hazard', src, {
        kind = 'heatwave',
        intensity = intensity,
        staminaDrain = hz.sprintStaminaDrain
    })
end

function processLightning(src, ped, coords, key, active)
    local hz = Config.Hazards[key]
    if not hz.enabled then return end
    local transitionIntensity = getDisasterTransitionIntensity(active)
    if transitionIntensity <= 0.0 then return end

    local strikeChance = hz.lightningStrikeChance * transitionIntensity
    if math.random() > strikeChance then return end

    local strike = {
        x = coords.x + math.random(-hz.strikeRadius * 10, hz.strikeRadius * 10) / 10.0,
        y = coords.y + math.random(-hz.strikeRadius * 10, hz.strikeRadius * 10) / 10.0,
        z = coords.z
    }

    local damage = math.max(1, math.floor((hz.strikeDamage * (0.25 + (transitionIntensity * 0.75))) + 0.5))
    applyServerDamage(src, ped, damage, key)
    TriggerClientEvent('cbk_disasters:client:hazard', -1, {
        kind = 'lightning',
        coords = strike,
        intensity = transitionIntensity,
        target = tonumber(src)
    })
end

function processTornado(src, ped, coords, active)
    local hz = Config.Hazards.tornado
    if not hz.enabled then return end
    local transitionIntensity = getDisasterTransitionIntensity(active)
    if transitionIntensity <= 0.0 then return end
    local zone = active.context and active.context.zone
    if not zone then return end

    local effectiveRadius = math.min(zone.radius or hz.pullRadius, hz.pullRadius)
    local zoneIntensity, dist = getZoneIntensity(coords, zone, effectiveRadius)
    local intensity = zoneIntensity * transitionIntensity
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

function processRegionalDamage(src, ped, coords, active)
    local hazard = hydrateStateHazard(active)
    local hz = Config.Hazards[hazard]
    if not hz then return end
    if not hz.enabled then return end
    local transitionIntensity = getDisasterTransitionIntensity(active)
    if transitionIntensity <= 0.0 then return end
    local def = active and active.key and Disasters[active.key] or nil
    local zone = active.context and active.context.zone
    local intensity, dist = transitionIntensity, 0.0
    if def and def.requiresZone then
        if not zone or not zone.coords then
            debugLog(('Skipping %s damage tick because the active zone context is missing.'):format(hazard))
            return
        end

        local zoneIntensity
        zoneIntensity, dist = getZoneIntensity(coords, zone)
        intensity = zoneIntensity * transitionIntensity
        if intensity <= 0.0 then return end
    end

    if math.random() > intensity then
        return
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

function processHazards()
    local active = State.active
    if not active then return end
    local hazard = hydrateStateHazard(active)
    if not hazard then return end

    for _, src in ipairs(getPlayers()) do
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            if hazard == 'heatwave' then
                processHeatwave(src, ped, coords, active)
            elseif hazard == 'thunderstorm' then
                processLightning(src, ped, coords, 'thunderstorm', active)
            elseif hazard == 'tornado' then
                processTornado(src, ped, coords, active)
            elseif hazard == 'blizzard' or hazard == 'duststorm' or hazard == 'wildfire_smoke' then
                processRegionalDamage(src, ped, coords, active)
            end
        end
    end
end

