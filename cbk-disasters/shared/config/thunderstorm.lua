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
