Config = {}

Config.Debug = false

Config.Locale = {
    prefix = '^3[Disaster Alert]^7 ',
    fallbackEventName = 'Unknown Event',
    adminOnly = 'You do not have permission to use this command.',
    invalidDisaster = 'Invalid disaster key.',
    blizzardNightOnly = 'Blizzards can only auto-start at night unless you launch one from the panel.',
    disasterAlreadyActive = 'A disaster is already active. Stop it before starting another one.',
    disasterConfigDisabled = 'That disaster is disabled in config.',
    disasterZoneUnavailable = 'That disaster cannot start because its configured zones are missing or invalid.',
    configValidationFailed = 'Disaster configuration validation failed. Check the server console for details.',
    invalidTiming = 'Invalid timing values.',
    timingUpdated = 'Timing values saved.',
    timingSaveFailed = 'Timing values updated for this session, but saving to disk failed.',
    systemEnabled = 'Disaster system enabled.',
    systemDisabled = 'Disaster system disabled.',
    systemUnavailable = 'The disaster system is currently disabled.',
    automationDisabled = 'Automatic disasters are disabled.',
    disasterStarted = 'Disaster started:',
    disasterStopped = 'Active disaster stopped.',
    noActiveDisaster = 'There is no active disaster.',
    nextDisaster = 'Next automatic disaster in approximately',
    minutes = 'minutes'
}

Config.Announcements = {
    enabled = true,
    useChat = true,
    useFeedSound = true,
    repeatReminderMinutes = 5
}
-- Server-only admin settings live in `server/config.lua` so identifiers are not sent to clients.

Config.System = {
    enabled = false -- Startup state for the whole disaster system. The admin panel can still toggle this live.
}

Config.Automation = {
    enabled = true,
    minMinutesBetweenEvents = 35,
    maxMinutesBetweenEvents = 90,
    randomizeDuration = true,
    blizzardNightOnly = true,
    blizzardNightStartHour = 20,
    blizzardNightEndHour = 6,
    blizzardNightUseUtc = false -- false = server local time, true = UTC
}

Config.Sync = {
    weatherApplyIntervalMs = 2000,
    stateBagName = 'cbk_disasters:state',
    stateRequestCooldownMs = 1500
}

Config.Intensity = {
    zoneMinimum = 0.12,
    curveExponent = 0.80
}

Config.Transitions = {
    inMinutes = 3,
    outMinutes = 3,
    curveExponent = 1.0
}

-- Shared/global buckets. Disaster-specific settings are defined in `shared/config/*.lua`.
Config.Hazards = {
    tickMs = 2500
}

Config.Zones = {}

Config.ClientFx = {
    drawZoneMarkersWhenDebug = false,
    statusReminderSeconds = 90,
    debugZoneMarkerAlpha = 60,
    alertSound = {
        enabled = true,
        useNuiSiren = true,
        sirenDurationMs = 6200,
        sirenVolume = 0.30,
        mode = 'bulletin',
        bulletinLowHz = 853,
        bulletinHighHz = 960,
        bulletinOnMs = 950,
        bulletinOffMs = 260,
        bulletinCycles = 4,
        bulletinStaticMs = 120,
        useFrontendFallback = false,
        name = '5_SEC_WARNING',
        set = 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS',
        pulses = 2,
        intervalMs = 220,
        finalName = 'Event_Start_Text',
        finalSet = 'GTAO_FM_Events_Soundset'
    },
    zoneBlip = {
        enabled = true,
        radiusColor = 1,
        radiusAlpha = 128,
        radiusMultiplier = 1.35,
        centerSprite = 161,
        centerColor = 1,
        centerScale = 1.15,
        shortRange = false,
        flashes = true,
        flashTimerMs = 15000,
        showWorldPulse = false,
        worldPulseMinScale = 1.05,
        worldPulseMaxScale = 1.45,
        worldPulseMinAlpha = 85,
        worldPulseMaxAlpha = 180,
        worldPulseHeight = 18.0,
        worldPulseSpeed = 0.004
    }
}


Disasters = {}

DisasterTimecycles = {
    default = nil
}


Config.Hazards = Config.Hazards or {}
Disasters = Disasters or {}
DisasterTimecycles = DisasterTimecycles or { default = nil }

Config.Hazards.heatwave = {
    enabled = true,
    pedestrianDamage = 2,
    vehicleProtection = true,
    sprintStaminaDrain = true
}

Disasters.heatwave = {
    key = 'heatwave',
    label = 'Extreme Heat Wave',
    announcement = 'A dangerous heat wave is now impacting the state. Hydrate, reduce exertion, and avoid long exposure outdoors.',
    weather = 'EXTRASUNNY',
    rainLevel = 0.0,
    windSpeed = 0.0,
    timecycle = 'heatwave',
    duration = { min = 18, max = 35 },
    cooldownMinutes = 45,
    weight = 12,
    hazard = 'heatwave',
    transition = {
        inMinutes = 4,
        outMinutes = 4
    }
}

DisasterTimecycles.heatwave = 'REDMIST_blend'


Config.Hazards = Config.Hazards or {}
Disasters = Disasters or {}
DisasterTimecycles = DisasterTimecycles or { default = nil }

Config.Hazards.thunderstorm = {
    enabled = true,
    lightningStrikeChance = 0.022, -- per eligible player per tick
    strikeRadius = 6.0,
    strikeDamage = 20
}

Disasters.thunderstorm = {
    key = 'thunderstorm',
    label = 'Severe Thunderstorm',
    announcement = 'A severe thunderstorm has developed. Expect lightning, reduced visibility, and hazardous driving conditions.',
    weather = 'THUNDER',
    rainLevel = 0.85,
    windSpeed = 0.75,
    timecycle = 'storm',
    duration = { min = 16, max = 28 },
    cooldownMinutes = 35,
    weight = 14,
    hazard = 'thunderstorm',
    transition = {
        inMinutes = 3,
        outMinutes = 3
    }
}

DisasterTimecycles.storm = 'Rainy'
DisasterTimecycles.storm_dark = 'BarryFadeOut'


Config.Hazards = Config.Hazards or {}
Config.Zones = Config.Zones or {}
Config.ClientFx = Config.ClientFx or {}
Disasters = Disasters or {}

Config.Hazards.tornado = {
    enabled = true,
    pullRadius = 120.0,
    lethalCoreRadius = 10.0,
    maxForceDistance = 105.0,
    vehicleEngineStallChance = 0.20,
    debrisDamage = 4,
    movement = {
        enabled = true,
        minSpeed = 1.0,
        maxSpeed = 4.0,
        turnIntervalMinMs = 3200,
        turnIntervalMaxMs = 6400,
        turnJitterDegrees = 24.0,
        turnTowardCenterWeight = 0.14,
        zoneRadiusRatio = 1.0,
        maxTravelRadius = 2200.0,
        updateIntervalMs = 100,
        broadcastIntervalMs = 250,
        broadcastUpdates = true
    }
}

Config.Zones.tornado = {
    { name = 'Grapeseed', coords = vec3(2468.5, 4781.9, 34.6), radius = 2100.0 },
    { name = 'Sandy Shores', coords = vec3(1735.8, 3298.1, 41.1), radius = 2400.0 },
    { name = 'Great Chaparral', coords = vec3(-104.3, 1920.6, 196.9), radius = 2200.0 },
    { name = 'Paleto Bay', coords = vec3(-160.0, 6225.0, 30.0), radius = 2000.0 },
    { name = 'Mount Chiliad', coords = vec3(450.0, 5560.0, 800.0), radius = 2400.0 },
    { name = 'Raton Canyon', coords = vec3(-150.0, 4415.0, 100.0), radius = 2200.0 }
}

Config.ClientFx.tornadoParticle = {
    enabled = true,
    asset = 'scr_rcbarry2',
    effect = 'scr_rcbarry2_trail',
    scale = 3.4,
    heightOffset = 2.5,
    heightOffsets = { 2.5, 10.0, 18.0 },
    scales = { 3.8, 2.7, 1.8 },
    farClipDistance = 500.0,
    debrisEffect = 'scr_fbi_falling_debris',
    debrisBurstScale = 1.55,
    debrisBurstRadius = 30.0,
    debrisBurstIntervalMs = 1200
}

Config.ClientFx.tornadoFunnel = {
    enabled = true,
    asset = 'core',
    effect = 'ent_amb_smoke_foundry',
    effects = {
        'ent_amb_smoke_foundry'
    },
    layers = 120,
    baseRadius = 1.0,
    topRadius = 4.5,
    baseHeight = -1.2,
    topHeight = 200.0,
    baseScale = 2.6,
    topScale = 8.0,
    swirlDegreesPerLayer = 55.0,
    rotationSpeed = 1.8,
    refreshIntervalMs = 250,
    farClipDistance = 500.0,
    maxHandles = 40,
    innerFillCount = 6,
    topCloudEffect = 'ent_amb_smoke_foundry',
    topCloudScale = 7.8,
    topCloudHeight = 145.0,
    drawSolidFunnel = false,
    drawLayers = 120,
    drawBaseRadius = 30.0,
    drawTopRadius = 3.0,
    drawBaseHeight = 2.0,
    drawTopHeight = 222.0,
    drawSwirlRadius = 4.8,
    drawSwirlSpeed = 4.0,
    drawAlphaBase = 240,
    drawAlphaTop = 28,
    drawColor = { r = 60, g = 60, b = 60 },
    drawConeShell = false,
    drawSegments = 30,
    drawShellAlpha = 125,
    drawShellColor = { r = 52, g = 52, b = 52 },
    drawLineFunnel = false,
    drawLineCount = 26,
    drawLineAlpha = 140,
    drawLineColor = { r = 95, g = 95, b = 95 },
    drawCenterBeacon = false,
    drawBeaconColor = { r = 220, g = 220, b = 220 },
    drawBeaconAlpha = 80,
    drawBeaconScale = 15.5,
    drawVolumetricCloud = false,
    volumetricBands = 6,
    volumetricPuffsPerBand = 6,
    volumetricAlphaBase = 60,
    volumetricAlphaTop = 34,
    volumetricColor = { r = 70, g = 70, b = 70 },
    volumetricDrift = 0.55
}

Config.ClientFx.tornadoInteraction = {
    enabled = true,
    maxDistance = 260.0,
    forceIntervalMs = 70,
    closeRangeDistance = 30.0,
    extremeCoreDistance = 10.0,
    damageTickMs = 1600,
    player = {
        enabled = true,
        maxDistance = 40.0,
        maxPull = 6.25,
        maxLift = 3.35,
        maxSpin = 1.95,
        pullVelocity = 8.5,
        spinVelocity = 4.1,
        liftVelocity = 7.8,
        groundedLiftVelocity = 3.4,
        minVerticalVelocity = 2.2,
        maxVerticalVelocity = 14.0,
        velocityPreserveFactor = 0.45,
        ragdollThreshold = 0.10,
        liftedRagdollThreshold = 0.06,
        ragdollTimeMs = 2200,
        maintainRagdollIntervalMs = 280,
        releaseDistance = 18.0,
        releaseRearmDistance = 62.0,
        releaseForceScaleThreshold = 0.82,
        releaseAfterMs = 1750,
        releaseCooldownMs = 4200,
        releaseOutVelocity = 42.0,
        releaseUpVelocity = 11.5,
        releaseSpinVelocity = 5.4,
        releaseVelocityPreserveFactor = 0.10,
        velocityClamp = 38.0
    },
    peds = {
        enabled = true,
        searchRadius = 40.0,
        sweepIntervalMs = 350,
        maxSweepCount = 10,
        maxPull = 2.45,
        maxLift = 0.86,
        maxSpin = 0.90,
        pullVelocity = 4.8,
        spinVelocity = 2.0,
        liftVelocity = 4.6,
        groundedLiftVelocity = 1.8,
        minVerticalVelocity = 1.2,
        maxVerticalVelocity = 9.0,
        velocityPreserveFactor = 0.52,
        ragdollThreshold = 0.18,
        ragdollTimeMs = 1800,
        velocityClamp = 20.0
    },
    camera = {
        enabled = true,
        shakeName = 'SKY_DIVING_SHAKE',
        baseAmplitude = 0.10,
        maxAmplitude = 0.52,
        updateIntervalMs = 120
    },
    sound = {
        enabled = true,
        maxDistance = 260.0,
        baseVolume = 0.02,
        maxVolume = 0.26,
        lowpassHz = 420,
        highpassHz = 36,
        centerBoostDistance = 70.0
    },
    vehicle = {
        enabled = true,
        maxDistance = 30.0,
        sweepRadius = 40.0,
        sweepIntervalMs = 450,
        maxSweepCount = 8,
        maxLift = 6.00,
        maxPull = 8.6,
        maxSpin = 4.80,
        pullVelocity = 10.4,
        spinVelocity = 6.4,
        liftVelocity = 7.4,
        groundedLiftVelocity = 4.6,
        minVerticalVelocity = 1.4,
        maxVerticalVelocity = 15.5,
        velocityPreserveFactor = 0.58,
        releaseDistance = 18.0,
        releaseRearmDistance = 40.0,
        releaseForceScaleThreshold = 0.82,
        releaseAfterMs = 3400,
        releaseCooldownMs = 4200,
        releaseOutVelocity = 42.0,
        releaseUpVelocity = 15.0,
        releaseSpinVelocity = 8.0,
        releaseVelocityPreserveFactor = 0.08,
        velocityClamp = 58.0
    },
    debrisPool = {
        enabled = true,
        maxDistance = 100.0,
        poolSizeNear = 16,
        poolSizeMid = 10,
        poolSizeFar = 6,
        updateIntervalMs = 250,
        modelNames = {
            'prop_rub_tyre_01',
            'prop_trafficcone_01a',
            'prop_boxpile_06b',
            'prop_crate_11e',
            'prop_cardbordbox_04a',
            'prop_bin_08open',
            'prop_bucket_02a',
            { name = 'a_c_cow', entityType = 'ped' }
        },
        spawnRadius = 30.0,
        minHeight = 2.0,
        maxHeight = 28.0,
        orbitSpeed = 1.4,
        riseSpeed = 6.8,
        despawnHeight = 32.0,
        collision = false
    }
}

Disasters.tornado = {
    key = 'tornado',
    label = 'Tornado Warning',
    announcement = 'A tornado warning is in effect. Take cover immediately and avoid open roads near the impact corridor.',
    weather = 'THUNDER',
    rainLevel = 1.00,
    windSpeed = 1.00,
    duration = { min = 10, max = 18 },
    cooldownMinutes = 80,
    weight = 5,
    hazard = 'tornado',
    transition = {
        inMinutes = 2,
        outMinutes = 2
    },
    requiresZone = 'tornado'
}


Config.Hazards = Config.Hazards or {}
Config.ClientFx = Config.ClientFx or {}
Disasters = Disasters or {}

Config.Hazards.blizzard = {
    enabled = true,
    pedestrianDamage = 1
}

Config.ClientFx.blizzard = {
    earlyWeather = 'XMAS',
    buildupWeather = 'XMAS',
    snowCoverWeather = 'XMAS',
    enableGlobalSnowCover = true,
    trackThreshold = 0.0,
    snowCoverThreshold = 0.0,
    weatherTransitionSeconds = 1.5,
    forceSnowPass = true,
    snowLevelMin = 1.00,
    snowLevelMax = 1.00,
    weatherWindBase = 2.00,
    weatherWindExtra = 1.50,
    timecycleBoost = 0.80,
    fogStrength = 1.00,
    windBaseSpeed = 2.20,
    windMaxSpeed = 3.60,
    windBaseDirection = 235.0,
    windSwingDegrees = 92.0,
    windGustSpeed = 1.35,
    windGustAmplitude = 0.70,
    windMicroGustSpeed = 2.95,
    windMicroGustAmplitude = 0.28,
    particleCountMin = 800,
    particleCountMax = 1000,
    particleRadius = 30.0,
    particleNearBias = 2.25,
    particleHeightMin = 0.25,
    particleHeightMax = 20.0,
    particleFallSpeedMin = 6.0,
    particleFallSpeedMax = 14.0,
    particleWindDriftScale = 8.0,
    particleTrailMin = 0.10,
    particleTrailMax = 0.24,
    particleAlpha = 1600,
    particleMarkerFraction = 0.00,
    particleMarkerMinScale = 0.050,
    particleMarkerMaxScale = 0.100,
    particleColor = { r = 240, g = 245, b = 255 },
    hazeMinAlpha = 100,
    hazeMaxAlpha = 180,
    hazeAccentMaxAlpha = 150,
    hazeColor = { r = 236, g = 242, b = 252 },
    hazeAccentColor = { r = 214, g = 226, b = 242 }
}

Disasters.blizzard = {
    key = 'blizzard',
    label = 'Blizzard Conditions',
    announcement = 'Whiteout blizzard conditions are impacting northern areas. Travel is strongly discouraged.',
    weather = 'XMAS',
    rainLevel = 0.0,
    windSpeed = 1.00,
    duration = { min = 18, max = 30 },
    cooldownMinutes = 80,
    weight = 6,
    hazard = 'blizzard',
    transition = {
        inMinutes = 5,
        outMinutes = 5
    }
}


Config.Hazards = Config.Hazards or {}
Config.Zones = Config.Zones or {}
Disasters = Disasters or {}
DisasterTimecycles = DisasterTimecycles or { default = nil }

Config.Hazards.duststorm = {
    enabled = true,
    pedestrianDamage = 1
}

Config.Zones.duststorm = {
    { name = 'Grand Senora Desert', coords = vec3(1880.0, 3560.0, 40.0), radius = 650.0 },
    { name = 'Sandy Shores', coords = vec3(1735.8, 3298.1, 41.1), radius = 650.0 },
    { name = 'Algonquin', coords = vec3(-300.0, 2000.0, 100.0), radius = 450.0 },
    { name = 'Grapeseed', coords = vec3(2468.5, 4781.9, 34.6), radius = 650.0 }
}

Disasters.duststorm = {
    key = 'duststorm',
    label = 'Dust Storm Advisory',
    announcement = 'A dense dust storm is reducing visibility across desert regions. Slow down and use caution.',
    weather = 'SMOG',
    rainLevel = 0.0,
    windSpeed = 1.00,
    timecycle = 'sandstorm',
    duration = { min = 16, max = 26 },
    cooldownMinutes = 50,
    weight = 10,
    hazard = 'duststorm',
    transition = {
        inMinutes = 3,
        outMinutes = 3
    },
    requiresZone = 'duststorm'
}

DisasterTimecycles.sandstorm = 'underwater_deep'


Config.Hazards = Config.Hazards or {}
Config.Zones = Config.Zones or {}
Config.ClientFx = Config.ClientFx or {}
Disasters = Disasters or {}
DisasterTimecycles = DisasterTimecycles or { default = nil }

Config.Hazards.wildfire_smoke = {
    enabled = true,
    pedestrianDamage = 1
}

Config.Zones.wildfire_smoke = {
    { name = 'Tongva Hills', coords = vec3(-1462.0, 1322.0, 145.0), radius = 600.0 },
    { name = 'Raton Canyon', coords = vec3(-150.0, 4415.0, 100.0), radius = 700.0 },
    { name = 'Mount Chiliad', coords = vec3(450.0, 5560.0, 800.0), radius = 900.0 },
    { name = 'Great Chaparral', coords = vec3(-104.3, 1920.6, 196.9), radius = 700.0 }
}

Config.ClientFx.wildfireSmoke = {
    asset = 'core',
    effect = 'exp_grd_grenade_smoke',
    effects = {
        'ent_amb_smoke_foundry',
        'exp_grd_grenade_smoke',
        'exp_extinguisher'
    },
    smokeScale = 7.5,
    smokeFarClipDistance = 900.0,
    maxDistance = 800.0,
    minPlumes = 5,
    maxPlumes = 20,
    plumeRadius = 56.0,
    plumeHeightOffset = 0.2,
    refreshDistance = 14.0,
    enableFire = true,
    minFires = 8,
    maxFires = 16,
    fireRadius = 24.0,
    fireMaxChildren = 1,
    overlayMinAlpha = 46,
    overlayMaxAlpha = 210,
    overlayColor = { r = 224, g = 96, b = 24 },
    accentOverlayMaxAlpha = 95,
    accentOverlayColor = { r = 142, g = 28, b = 12 }
}

Disasters.wildfire_smoke = {
    key = 'wildfire_smoke',
    label = 'Wildfire Smoke Event',
    announcement = 'Heavy wildfire smoke is affecting air quality. Limit outdoor exposure and expect poor visibility in affected areas.',
    weather = 'FOGGY',
    rainLevel = 0.0,
    windSpeed = 0.20,
    timecycle = 'forestfire',
    duration = { min = 18, max = 32 },
    cooldownMinutes = 55,
    weight = 9,
    hazard = 'wildfire_smoke',
    transition = {
        inMinutes = 4,
        outMinutes = 4
    },
    requiresZone = 'wildfire_smoke'
}

DisasterTimecycles.forestfire = 'REDMIST'


Config = Config or {}

Config.Admin = {
    aceCommand = 'cbkdisasters.admin',     -- ACE permission used by in-resource commands.
    allowAcePermissions = true,            -- Set to false to disable ACE lookups and rely solely on identifiers.
    allowConsole = true,                   -- Allow the server console (source 0) to run admin commands.
    identifiers = {
        'fivem:18296635',                     -- Authorized identifier example.
        'discord:1043241558503337994',        -- Authorized identifier example.
    }
}


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

local function resolveStartFailureMessage(reason)
    if reason == 'invalid' then
        return Config.Locale.invalidDisaster
    end

    if reason == 'disabled' then
        return Config.Locale.systemUnavailable
    end

    if reason == 'night_only' then
        return Config.Locale.blizzardNightOnly
    end

    if reason == 'active' then
        return Config.Locale.disasterAlreadyActive
    end

    if reason == 'event_disabled' then
        return Config.Locale.disasterConfigDisabled
    end

    if reason == 'zone_unavailable' then
        return Config.Locale.disasterZoneUnavailable
    end

    if reason == 'invalid_config' then
        return Config.Locale.configValidationFailed
    end

    return nil
end

local function notifyStartFailure(target, reason)
    local message = resolveStartFailureMessage(reason)
    if not message then
        return
    end

    if target > 0 then
        notifyOne(target, message)
    else
        log(message)
    end
end

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
        notifyStartFailure(src, reason)
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
    if not isSystemEnabled() then
        msg = Config.Locale.systemUnavailable
    elseif State.active then
        local remaining = math.max(0, State.active.endsAt - now())
        msg = ('Active: %s | Remaining: %sm'):format(State.active.label, math.ceil(remaining / 60))
    elseif not isAutomationEnabled() then
        msg = Config.Locale.automationDisabled
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

RegisterCommand('disasters', function(src)
    if src <= 0 then
        log('The /disasters panel can only be opened by an in-game player.')
        return
    end

    if not hasAdminPermission(src) then
        notifyOne(src, Config.Locale.adminOnly)
        return
    end

    openPanelFor(src)
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
        notifyStartFailure(src, reason)
        return
    end

    if src > 0 then
        notifyOne(src, ('%s %s'):format(Config.Locale.disasterStarted, key))
    end
end)

RegisterNetEvent('cbk_disasters:server:setSystemEnabledFromPanel', function(data)
    local src = source
    if not hasAdminPermission(src) then
        if src > 0 then
            notifyOne(src, Config.Locale.adminOnly)
        end
        return
    end

    if type(data) ~= 'table' or type(data.enabled) ~= 'boolean' then
        return
    end

    local changed = setSystemEnabled(data.enabled, ('panel:%s'):format(src))
    if src > 0 then
        if changed or isSystemEnabled() == data.enabled then
            notifyOne(src, data.enabled and Config.Locale.systemEnabled or Config.Locale.systemDisabled)
        end
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
    local validConfig, issues = validateDisasterConfiguration()
    if not validConfig then
        State.systemEnabled = false
        State.active = nil
        State.nextEventAt = 0
        log(('Configuration validation failed with %d issue(s). Refusing to start the disaster system.'):format(#issues))
        for i = 1, #issues do
            log(('[config] %s'):format(issues[i]))
        end
        SetTimeout(0, function()
            StopResource(RESOURCE)
        end)
        return
    end
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
        elseif isAutomationEnabled() and State.nextEventAt > 0 and now() >= State.nextEventAt then
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



