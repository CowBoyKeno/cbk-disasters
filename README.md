# CBK DISASTERS #

A production-ready **server-authoritative disaster system** for FiveM RP servers.  
Built for live public-server use with automation, admin controls, scoped hazards, and descriptive config.

## What is included

- Extreme heat waves
- Severe thunderstorms
- Tornado warnings with configurable impact corridors
- Blizzard conditions with a server-side night window
- Dust storms for desert regions
- Wildfire smoke events
- Automatic weighted scheduling with per-disaster cooldowns
- A strict one-active-event-at-a-time runtime model
- Per-disaster enable toggles in shared config
- Fail-fast startup validation for modular disaster configs
- Safe zoned-event handling that refuses to start with missing/invalid zones
- Server-side damage / hazard ownership
- Minimal client trust surface
- ACE-protected admin controls
- Full standalone resource

## Install

1. Put the folder in your server resources directory.
2. Add to `server.cfg`:
   ```cfg
   ensure cbk_disasters
   ```
3. Add ACE permissions for disaster admin controls:
   ```cfg
   add_ace group.admin cbkdisasters.admin allow
   add_principal identifier.license:YOUR_LICENSE_HERE group.admin
   ```
4. Restart the server.

## Commands

All admin commands require the ACE permission `cbkdisasters.admin` or any identifier configured in `server/config.lua` under `Config.Admin.identifiers`.

- `/disaster_start <key>`
- `/disaster_stop`
- `/disaster_status`
- `/disasters` (admin-only NUI disaster monitor; use again or press Esc to close)

### Admin configuration

Open `server/config.lua` and locate the `Config.Admin` block to configure how admin identifiers are checked:

```lua
Config.Admin = {
    aceCommand = 'cbkdisasters.admin',
    allowAcePermissions = true,
    allowConsole = true,
    identifiers = {
        -- 'license:1234567890abcdef',
        -- 'steam:110000112345678',
        -- 'discord:123456789012345678'
    }
}
```

Add any identifiers you trust and leave `allowAcePermissions` set to `true` if you still want to grant access via ACE. Set it to `false` if you prefer to rely solely on the identifiers list.

### Master system toggle

Open `shared/config.lua` and use `Config.System.enabled` to choose whether the disaster system starts online or offline:

```lua
Config.System = {
    enabled = true
}
```

When this is set to `false`, automation and manual event starts are blocked until an authorized admin turns the system back on from the panel.

The repo currently ships with this startup toggle set to `false`, so the system stays offline until you explicitly enable it.

### Modular shared config layout

Global settings still live in `shared/config.lua`, while each disaster now has its own shared config file:

- `shared/config/heatwave.lua`
- `shared/config/thunderstorm.lua`
- `shared/config/tornado.lua`
- `shared/config/blizzard.lua`
- `shared/config/duststorm.lua`
- `shared/config/wildfire_smoke.lua`

That keeps zone lists, hazard tuning, FX settings, and disaster definitions grouped by hazard instead of living in one giant shared file.

### Transition tuning

Disasters now ramp in and ramp out instead of jumping straight to full intensity. The shared defaults live in `shared/config.lua`:

```lua
Config.Transitions = {
    inMinutes = 3,
    outMinutes = 3,
    curveExponent = 1.0
}
```

Each disaster can override those timings inside its own `Disasters.<key>` definition:

```lua
transition = {
    inMinutes = 4,
    outMinutes = 4
}
```

These transition values affect both the server-authoritative hazard strength and the client weather / FX buildup, so the event feels like it is arriving and clearing naturally.

### Per-disaster toggles and validation

Each disaster file defines its own hazard block under `Config.Hazards.<hazard>`. Every hazard includes an `enabled` flag that now behaves as a hard server-side gate:

- Disabled disasters cannot be started manually.
- Disabled disasters are skipped by automation.
- Disabled disasters show as `Disabled` in the admin panel.

For zoned disasters like `tornado`, `duststorm`, and `wildfire_smoke`, the resource now requires at least one valid configured zone before the event can start. If a required zone list is missing, empty, or malformed, the event is blocked and the panel shows `Config issue`.

On resource start, the server validates all disaster definitions, timing values, hazards, and required zones. If validation fails, the resource logs the problems to the server console and stops itself instead of running with broken config.

Only one disaster can be active at a time. If a disaster is already running, all other start attempts are rejected until the active event ends or is manually stopped.

## Disasters monitor (NUI)

Use `/disasters` to open the admin overlay panel. The monitor updates every second and highlights:

- Which hazard is currently active and how much longer it will run.
- The next automated disaster timer so you can stage RP pacing.
- A per-disaster column showing duration ranges, cooldowns, and the readiness state.

The panel can be refreshed manually with the "Refresh" button or closed with Esc/a second `/disasters` press. It uses the built-in NUI layer (`ui/index.html`) so no extra resources are required; simply ensure the resource is started and the NUI panel is reachable.

Each card now has a "Start event" button, the meta banner exposes a "Disable system"/"Enable system" master toggle plus a "Stop active event" control, and you can edit the duration min/max plus cooldown minutes directly in the UI. Saving those values now persists them to `timing_overrides.json`, so they survive resource restarts without manually editing the per-disaster shared config files.

Card states now reflect the actual server-side start rules:

- `Ready`: can be started right now.
- `Cooldown`: waiting for the per-disaster cooldown to expire.
- `Busy`: another disaster is already active, so starts are blocked.
- `Disabled`: that disaster's shared config `enabled` flag is off.
- `Config issue`: the disaster requires zones or config data that failed validation.

- Alerts now play a short tone whenever a new disaster begins, and the panel also draws a translucent red highlight around the configured zone so you can see where the impact corridor currently sits.
- Tornado events now spawn a looping `scr_rcbarry2_trail` particle effect above the selected corridor, giving the impression of a funnel cloud without adding extra entities or physics logic.
- Wildfire smoke now builds zone-anchored smoke plumes and script fires around the configured wildfire area instead of around each player. Edit `Config.ClientFx.wildfireSmoke` if you want to tune density, radius, or fire counts.

## Disaster keys

- `heatwave`
- `thunderstorm`
- `tornado`
- `blizzard`
- `duststorm`
- `wildfire_smoke`

## Server-authoritative model

The server controls:

- which disaster is active
- how long it lasts
- which zone is selected for zoned events
- whether a disaster is allowed to start at all
- all player damage decisions
- all automation / cooldown logic
- the blizzard night window check for automated starts

Clients only handle:

- local weather visuals
- local UI / alert audio playback
- tornado motion response
- local vehicle response for tornado conditions

All client->server mutation events are validated on the server, and panel actions still require ACE/identifier-based admin permission checks before mutating state.

## Files

```text
cbk_disasters/
  fxmanifest.lua
  client/modules/core.lua
  client/modules/effects.lua
  client/modules/hazards.lua
  client/main.lua
  server/modules/bootstrap.lua
  server/modules/panel.lua
  server/modules/core.lua
  server/main.lua
  server/config.lua
  shared/config.lua
  shared/disasters.lua
  shared/config/heatwave.lua
  shared/config/thunderstorm.lua
  shared/config/tornado.lua
  shared/config/blizzard.lua
  shared/config/duststorm.lua
  shared/config/wildfire_smoke.lua
  README.md
```

`client/modules/` and `server/modules/` remain the editable source layout, while `client/main.lua` and `server/main.lua` are the live bundled runtime files loaded by FiveM. After editing the modular source files, run `tools/rebuild-entrypoints.ps1` so the live entrypoints pick up your changes.

## Configuration guidance

### Heat wave
Use this for statewide high-risk weather. By default, players take light server-side damage only when on foot.

### Thunderstorm
Thunderstorms use lightning strike events with server-side damage and client-side strike visuals.

### Tornado
A tornado event picks one configured tornado zone from `Config.Zones.tornado`.  
Players near the corridor are damaged on the server and physically affected on the client.

For public servers, the tornado interaction config now separates the fast player-force loop from the broader NPC/vehicle sweep cadence:

- `Config.ClientFx.tornadoInteraction.forceIntervalMs`
- `Config.ClientFx.tornadoInteraction.peds.sweepIntervalMs`
- `Config.ClientFx.tornadoInteraction.vehicle.sweepIntervalMs`

### Blizzard / dust / smoke
Blizzard is now a global disaster and automated blizzards only start during the configured server-side night window unless an admin launches one from the panel. Dust storms and wildfire smoke remain zoned regional hazards.

## Tuning for live public servers

Recommended defaults already aim for stability:
- hazard checks every 2.5 seconds
- throttled client-side interaction loops
- server-side player iteration
- weighted random scheduling
- no object spam
- no map edits
For a 100-150 player server:
- keep hazard ticks at `2000-3000ms`
- avoid adding large numbers of particle effects
- keep tornado zones selective rather than map-wide
- keep tornado ped/vehicle sweep intervals conservative unless you have profiled the client cost
- do not add per-frame server events

## Integration notes

This resource is standalone.  
It does not require ESX, QBCore, Qbox, ND, or ox_lib.

If you want framework integration later, the clean extension points are:
- export `GetActiveDisaster`
- export `StartDisaster`
- export `StopDisaster`

`StartDisaster` now returns `false` when the system is disabled, another disaster is already active, the target disaster is disabled in config, or the event cannot build valid zone context.

## Verification checklist

- Resource starts cleanly
- Broken modular config causes a clean startup refusal instead of a partial boot
- `GlobalState[cbk_disasters:state]` updates on start/stop
- New joining players receive current disaster state
- Admin commands require ACE or a Config.Admin identifier
- Disabled disasters cannot be started manually or by automation
- A second disaster cannot overlap an already active event
- Weather clears on resource stop
- Tornado zones match your server map usage
- Automation intervals fit your RP pacing

## Notes for public launch

Before going live:
- review all configured zones for your map / MLO stack
- test each disaster once in staging
- confirm your chat resource exists if you want chat alerts
- verify ACE permissions or identifier configuration
- decide whether `Config.System.enabled` should boot online or offline for your environment
- tune durations and cooldowns to your RP economy and EMS workflow
