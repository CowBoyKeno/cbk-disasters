clientHazardsReady = false

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

function isPlayerInVehicle()
    return IsPedInAnyVehicle(PlayerPedId(), false)
end

function isPlayerInInterior()
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then
        return false
    end

    local interior = GetInteriorFromEntity(ped)
    return interior ~= 0
end

function isPlayerInShade()
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

function isHeatwaveProtected()
    return isPlayerInVehicle() or isPlayerInInterior() or isPlayerInShade()
end

function getHazardDamageMultiplier(hazard)
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

function requestTornadoEntityControl(entity)
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

function getTornadoForceData(entity, center, maxForceDistance, baseIntensity, interactionCfg)
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

function clampTornadoEntityVelocity(entity, maxSpeed)
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

function getTornadoLiftEntityState(entity)
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
    tornadoNextPedSweepAt = 0
    tornadoNextVehicleSweepAt = 0
end

function applyTornadoVelocityInjection(entity, force, cfg)
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

function maintainTornadoPedRagdoll(ped, force, pedCfg)
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

function tryReleaseTornadoPed(ped, force, pedCfg, interactionCfg)
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

function tryReleaseTornadoVehicle(entity, force, vehicleCfg, interactionCfg)
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

function applyConfiguredTornadoVehicleForce(entity, center, baseIntensity, vehicleCfg, maxForceDistance, liftScale, spinScale, stallChance, interactionCfg)
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

function applyConfiguredTornadoPedForce(ped, center, baseIntensity, pedCfg, maxForceDistance, interactionCfg)
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

function isTornadoDebrisEntity(entity)
    for i = 1, #tornadoDebrisPool do
        local entry = tornadoDebrisPool[i]
        if entry and entry.entity == entity then
            return true
        end
    end

    return false
end

function applyTornadoForce(payload)
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

function applyLocalTornadoLift(zone)
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
    local nowMs = GetGameTimer()
    local forceIntervalMs = math.max(70, math.floor(interactionCfg.forceIntervalMs or 140))

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

    if pedCfg.enabled ~= false and nowMs >= (tornadoNextPedSweepAt or 0) then
        tornadoNextPedSweepAt = nowMs + math.max(forceIntervalMs, math.floor(pedCfg.sweepIntervalMs or 350))
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

    if vehicleCfg.enabled ~= false and nowMs >= (tornadoNextVehicleSweepAt or 0) then
        tornadoNextVehicleSweepAt = nowMs + math.max(forceIntervalMs, math.floor(vehicleCfg.sweepIntervalMs or 450))
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

function spawnLightningFx(coords)
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

clientHazardsReady = true

