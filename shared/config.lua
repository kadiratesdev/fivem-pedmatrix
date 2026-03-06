-- Shared configuration for height-sync
-- Loaded on both client and server

Config = Config or {}

-- Height limits
Config.MinHeight = 0.5   -- Minimum scale (50% of original height)
Config.MaxHeight = 2.0   -- Maximum scale (200% of original height)

-- Sync settings
Config.SyncDistance = 50.0  -- Distance in units to sync other players' heights
Config.SyncInterval = 500   -- Broadcast interval in milliseconds

-- Database settings
Config.SaveToDatabase = true   -- Whether to persist heights to database
Config.TableName = 'player_heights'

-- Rate limiting (in milliseconds)
Config.RateLimitSetHeight = 200    -- Minimum time between setHeight calls
Config.RateLimitBroadcast = 500   -- Minimum time between broadcast calls

-- UI settings
Config.CommandName = 'height'     -- Chat command to open UI
Config.KeyMappingName = 'fivem-pedmatrix:open'  -- Key mapping identifier

-- Security settings
Config.RequireAdmin = false  -- Require admin permission to change height
