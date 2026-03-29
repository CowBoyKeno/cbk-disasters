function buildPanelData()
    local ts = now()
    local disasters = {}
    local panelActive = nil

    for _, def in pairs(Disasters) do
        local hazardConfig = getHazardConfig(def)
        local configEnabled = hazardConfig and hazardConfig.enabled ~= false
        local zoneReady = not def.requiresZone or hasValidZoneConfig(def.requiresZone)
        local entry = {
            key = def.key,
            label = def.label,
            hazard = def.hazard,
            announcement = def.announcement,
            duration = def.duration,
            cooldownSeconds = (def.cooldownMinutes or 0) * 60,
            cooldownMinutes = def.cooldownMinutes or 0,
            enabled = configEnabled,
            zoneReady = zoneReady
        }

        local status = 'ready'
        if State.active and State.active.key == def.key then
            status = 'active'
            entry.remainingSeconds = math.max(0, (State.active.endsAt or 0) - ts)
        elseif not configEnabled then
            status = 'disabled'
        elseif not zoneReady then
            status = 'unavailable'
        elseif State.active then
            status = 'blocked'
            entry.blockedBy = State.active.key
            entry.blockedByLabel = State.active.label
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
        entry.canStart = isSystemEnabled() and status == 'ready'
        disasters[#disasters + 1] = entry
    end

    table.sort(disasters, function(a, b)
        return a.label < b.label
    end)

    return {
        disasters = disasters,
        active = panelActive,
        systemEnabled = isSystemEnabled(),
        automationEnabled = isAutomationEnabled(),
        automationNextEventSeconds = isAutomationEnabled() and math.max(0, State.nextEventAt - ts) or 0,
        timestamp = ts
    }
end

function broadcastPanelData()
    local panelData = buildPanelData()

    for src in pairs(panelSubscribers) do
        if not GetPlayerName(src) or not hasAdminPermission(src) then
            panelSubscribers[src] = nil
        else
            TriggerClientEvent('cbk_disasters:client:updatePanel', src, panelData)
        end
    end
end

function sendPanelData(target)
    local src = tonumber(target)
    if src and src > 0 and hasAdminPermission(src) then
        TriggerClientEvent('cbk_disasters:client:updatePanel', src, buildPanelData())
    end
end

function openPanelFor(target)
    local src = tonumber(target)
    if not src or src <= 0 or not hasAdminPermission(src) then
        return false
    end

    addPanelSubscriber(src)
    TriggerClientEvent('cbk_disasters:client:openPanel', src, buildPanelData())
    return true
end

