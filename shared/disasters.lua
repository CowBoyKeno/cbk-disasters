Disasters = {
    heatwave = {
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
        hazard = 'heatwave'
    },

    thunderstorm = {
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
        hazard = 'thunderstorm'
    },

    tornado = {
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
        requiresZone = 'tornado'
    },

    blizzard = {
        key = 'blizzard',
        label = 'Blizzard Conditions',
        announcement = 'Whiteout blizzard conditions are impacting northern areas. Travel is strongly discouraged.',
        weather = 'XMAS',
        rainLevel = 0.0,
        windSpeed = 1.00,
        duration = { min = 18, max = 30 },
        cooldownMinutes = 80,
        weight = 6,
        hazard = 'blizzard'
    },

    duststorm = {
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
        requiresZone = 'duststorm'
    },

    wildfire_smoke = {
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
        requiresZone = 'wildfire_smoke'
    }
}

DisasterTimecycles = {
    default = nil,
    heatwave = 'REDMIST_blend',
    storm = 'Rainy',
    storm_dark = 'BarryFadeOut',
    sandstorm = 'underwater_deep',
    forestfire = 'REDMIST'
}
