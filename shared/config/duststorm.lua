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
