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
    announcement = 'Whiteout blizzard conditions are impacting ALL areas. Travel is strongly discouraged.',
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
