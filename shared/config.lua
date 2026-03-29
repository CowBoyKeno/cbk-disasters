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
