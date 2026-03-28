# CBK DISASTERS #

A production-ready **server-authoritative disaster system** for FiveM RP servers.  
Built for live public-server use with automation, admin controls, scoped hazards, and descriptive config.

## Tornado Demo Video
https://youtu.be/9VTCNhKZNO8

## What is included

- Extreme heat waves
- Severe thunderstorms
- Tornado warnings with configurable impact corridors
- Blizzard conditions with a server-side night window
- Dust storms for desert regions
- Wildfire smoke events
- Automatic weighted scheduling with per-disaster cooldowns
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

## Disasters monitor (NUI)

Use `/disasters` to open the admin overlay panel. The monitor updates every second and highlights:

- Which hazard is currently active and how much longer it will run.
- The next automated disaster timer so you can stage RP pacing.
- A per-disaster column showing duration ranges, cooldowns, and the readiness state.

The panel can be refreshed manually with the "Refresh" button or closed with Esc/a second `/disasters` press. It uses the built-in NUI layer (`ui/index.html`) so no extra resources are required; simply ensure the resource is started and the NUI panel is reachable.

Each card now has a "Start event" button, the meta banner exposes a "Stop active event" control, and you can edit the duration min/max plus cooldown minutes directly in the UI. Saving those values now persists them to `timing_overrides.json`, so they survive resource restarts without manually editing `shared/disasters.lua`.

- Alerts now play a short tone whenever a new disaster begins, and the panel also draws a translucent red highlight around the configured zone so you can see where the impact corridor currently sits.
- Tornado events now spawn a looping `scr_rcbarry2_trail` particle effect above the selected corridor, giving the impression of a funnel cloud without adding extra entities or physics logic.
- Wildfire smoke shows an actual `prop_target_smoke_01`, and the alpha scales based on each player's distance to the hazard so the plume feels thicker when you're close and transparent when you're back in the safe area. The prop despawns as soon as the event ends (edit `Config.ClientFx.wildfireSmoke` if you want to tweak the density or range).

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
  client/main.lua
  server/main.lua
  server/config.lua
  shared/config.lua
  shared/disasters.lua
  README.md
```

## Configuration guidance

### Heat wave
Use this for statewide high-risk weather. By default, players take light server-side damage only when on foot.

### Thunderstorm
Thunderstorms use lightning strike events with server-side damage and client-side strike visuals.

### Tornado
A tornado event picks one configured tornado zone from `Config.Zones.tornado`.  
Players near the corridor are damaged on the server and physically affected on the client.

### Blizzard / dust / smoke
Blizzard is now a global disaster and automated blizzards only start during the configured server-side night window unless an admin launches one from the panel. Dust storms and wildfire smoke remain zoned regional hazards.

## Tuning for live public servers

Recommended defaults already aim for stability:
- hazard checks every 2.5 seconds
- no polling-heavy client loops
- server-side player iteration
- weighted random scheduling
- no object spam
- no map edits
For a 100-150 player server:
- keep hazard ticks at `2000-3000ms`
- avoid adding large numbers of particle effects
- keep tornado zones selective rather than map-wide
- do not add per-frame server events

## Integration notes

This resource is standalone.  
It does not require ESX, QBCore, Qbox, ND, or ox_lib.

If you want framework integration later, the clean extension points are:
- export `GetActiveDisaster`
- export `StartDisaster`
- export `StopDisaster`

## Verification checklist

- Resource starts cleanly
- `GlobalState[cbk_disasters:state]` updates on start/stop
- New joining players receive current disaster state
- Admin commands require ACE or a Config.Admin identifier
- Weather clears on resource stop
- Tornado zones match your server map usage
- Automation intervals fit your RP pacing

## Notes for public launch

Before going live:
- review all configured zones for your map / MLO stack
- test each disaster once in staging
- confirm your chat resource exists if you want chat alerts
- verify ACE permissions or identifier configuration
- tune durations and cooldowns to your RP economy and EMS workflow
