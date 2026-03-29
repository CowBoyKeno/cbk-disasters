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
