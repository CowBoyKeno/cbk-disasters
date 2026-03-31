Config = Config or {}

Config.Admin = {
    aceCommand = 'cbkdisasters.admin',     -- ACE permission used by in-resource commands.
    allowAcePermissions = true,            -- Set to false to disable ACE lookups and rely solely on identifiers.
    allowConsole = true,                   -- Allow the server console (source 0) to run admin commands.
    identifiers = {
                'license:replace_with_admin_license',
                'fivem:replace_with_admin_fivem_id',
                'discord:replace_with_admin_discord_id',
                'steam:replace_with_admin_steam_id'       -- Authorized identifier example.
    }
}
