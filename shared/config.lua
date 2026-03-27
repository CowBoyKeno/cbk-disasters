Config = {}

Config.Debug = false

Config.Locale = {
    prefix = '^3[Disaster Alert]^7 ',
    fallbackEventName = 'Unknown Event',
    adminOnly = 'You do not have permission to use this command.',
    invalidDisaster = 'Invalid disaster key.',
    blizzardNightOnly = 'Blizzards can only auto-start at night unless you launch one from the panel.',
    invalidTiming = 'Invalid timing values.',
    timingUpdated = 'Timing values saved.',
    timingSaveFailed = 'Timing values updated for this session, but saving to disk failed.',
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

Config.Hazards = {
    tickMs = 2500,

    heatwave = {
        enabled = true,
        pedestrianDamage = 2,
        vehicleProtection = true,
        sprintStaminaDrain = true
    },

    thunderstorm = {
        enabled = true,
        lightningStrikeChance = 0.003, -- per eligible player per tick
        strikeRadius = 6.0,
        strikeDamage = 20
    },

    tornado = {
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
    },

    blizzard = {
        enabled = true,
        pedestrianDamage = 2
    },

    duststorm = {
        enabled = true,
        pedestrianDamage = 1
    },

    wildfire_smoke = {
        enabled = true,
        pedestrianDamage = 1
    }
}

Config.Zones = {
    tornado = {
        { name = 'Grapeseed', coords = vec3(2468.5, 4781.9, 34.6), radius = 2100.0 },
        { name = 'Sandy Shores', coords = vec3(1735.8, 3298.1, 41.1), radius = 2400.0 },
        { name = 'Great Chaparral', coords = vec3(-104.3, 1920.6, 196.9), radius = 2200.0 }
    },

    duststorm = {
        { name = 'Grand Senora Desert', coords = vec3(1880.0, 3560.0, 40.0), radius = 650.0 }
    },

    wildfire_smoke = {
        { name = 'Tongva Hills', coords = vec3(-1462.0, 1322.0, 145.0), radius = 600.0 },
        { name = 'Raton Canyon', coords = vec3(-150.0, 4415.0, 100.0), radius = 700.0 }
    }
}

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
    },
    blizzard = {
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
        hazeMinAlpha = 110,
        hazeMaxAlpha = 200,
        hazeAccentMaxAlpha = 160,
        hazeColor = { r = 236, g = 242, b = 252 },
        hazeAccentColor = { r = 214, g = 226, b = 242 }
    },
    tornadoParticle = {
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
    },
    tornadoFunnel = {
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
        topHeight = 180.0,
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
    },

    tornadoInteraction = {
        enabled = true,
        maxDistance = 260.0,
        forceIntervalMs = 70,
        closeRangeDistance = 40.0,
        extremeCoreDistance = 10.0,
        damageTickMs = 1600,
        player = {
            enabled = true,
            maxDistance = 80.0,
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
            searchRadius = 55.0,
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
            maxDistance = 50.0,
            sweepRadius = 55.0,
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
            maxDistance = 120.0,
            poolSizeNear = 16,
            poolSizeMid = 10,
            poolSizeFar = 6,
            updateIntervalMs = 150,
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
            spawnRadius = 40.0,
            minHeight = 2.0,
            maxHeight = 24.0,
            orbitSpeed = 1.8,
            riseSpeed = 6.8,
            despawnHeight = 32.0,
            collision = false
        }
    },
    wildfireSmoke = {
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
}
