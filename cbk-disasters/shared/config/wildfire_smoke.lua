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
