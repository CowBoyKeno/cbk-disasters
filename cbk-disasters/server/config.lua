Config = Config or {}

Config.Admin = {
    aceCommand = 'cbkdisasters.admin',     -- ACE permission used by in-resource commands.
    allowAcePermissions = true,            -- Set to false to disable ACE lookups and rely solely on identifiers.
    allowConsole = true,                   -- Allow the server console (source 0) to run admin commands.
    identifiers = {
        'fivem:18296635',                     -- Authorized identifier example.
        'discord:1043241558503337994',        -- Authorized identifier example.
    }
}
