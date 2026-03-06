-- Server main module for fivem-pedmatrix
-- Handles validation, in-memory store, and event relay

local PlayerHeights = {}  -- In-memory store: [serverId] = scale
local LastUpdate = {}      -- Rate limiting: [serverId] = timestamp
local PendingDBWrites = {} -- Batch database writes: [citizenid] = scale

-- Get current time in milliseconds using game timer
local function GetCurrentMs()
    return GetGameTimer()
end

-- Validate height scale
local function IsValidScale(scale)
    if type(scale) ~= 'number' then return false end
    if scale ~= scale then return false end -- NaN check
    if scale < Config.MinHeight or scale > Config.MaxHeight then return false end
    return true
end

-- Check if player is admin (QBCore)
local function IsPlayerAdmin(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    -- Check QBCore player data for admin status
    return Player.PlayerData.permission == 'admin' or Player.PlayerData.permission == 'superadmin'
end

-- Broadcast to nearby players only (optimization)
local function BroadcastToNearbyPlayers(serverId, scale, excludeClient)
    local targetPed = GetPlayerPed(serverId)
    if not DoesEntityExist(targetPed) then return end
    
    local targetPos = GetEntityCoords(targetPed)
    local players = GetPlayers()
    
    for _, player in ipairs(players) do
        if player ~= excludeClient then
            local playerPed = GetPlayerPed(player)
            if DoesEntityExist(playerPed) then
                local playerPos = GetEntityCoords(playerPed)
                local dist = #(targetPos - playerPos)
                if dist <= Config.SyncDistance then
                    TriggerClientEvent('fivem-pedmatrix:playerUpdate', player, serverId, scale)
                end
            end
        end
    end
end

-- Check rate limit
local function CanUpdate(source)
    local now = GetCurrentMs()
    if not LastUpdate[source] then
        LastUpdate[source] = now
        return true
    end
    
    if now - LastUpdate[source] >= Config.RateLimitSetHeight then
        LastUpdate[source] = now
        return true
    end
    
    return false
end

-- Check broadcast rate limit
local function CanBroadcast(source)
    local now = GetCurrentMs()
    if not LastUpdate[source] then
        LastUpdate[source] = now
        return true
    end
    
    if now - LastUpdate[source] >= Config.RateLimitBroadcast then
        LastUpdate[source] = now
        return true
    end
    
    return false
end

-- Handle player initial height request
RegisterNetEvent('fivem-pedmatrix:requestInit', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local scale = 1.0
    
    -- Load from database if enabled
    if Config.SaveToDatabase then
        scale = exports['fivem-pedmatrix']:LoadPlayerHeight(citizenid)
    end
    
    -- Store in memory
    PlayerHeights[src] = scale
    
    -- Send bulk update to requesting client
    TriggerClientEvent('fivem-pedmatrix:bulkUpdate', src, PlayerHeights)
    
    -- Send individual height to requesting client
    TriggerClientEvent('fivem-pedmatrix:receiveHeight', src, src, scale)
end)

-- Handle height set from client
RegisterNetEvent('fivem-pedmatrix:setHeight', function(scale)
    local src = source
    
    -- Rate limiting
    if not CanUpdate(src) then return end
    
    -- Validate
    if not IsValidScale(scale) then return end
    
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Check if player is in config allowed roles (optional admin control)
    if Config.RequireAdmin and not IsPlayerAdmin(src) then
        return -- Non-admin players cannot change height if RequireAdmin is true
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Update in-memory store
    PlayerHeights[src] = scale
    
    -- Queue to batch write (optimization)
    if Config.SaveToDatabase then
        PendingDBWrites[citizenid] = scale
    end
    
    -- Broadcast to nearby players only (optimization)
    BroadcastToNearbyPlayers(src, scale, -1)
end)

-- Handle periodic broadcast from client (for drift correction)
RegisterNetEvent('fivem-pedmatrix:broadcast', function(scale)
    local src = source
    
    -- Rate limiting (BUG-04 fix)
    if not CanBroadcast(src) then return end
    
    -- Validate
    if not IsValidScale(scale) then return end
    
    -- Update in-memory store only if changed
    if PlayerHeights[src] ~= scale then
        PlayerHeights[src] = scale
    end
    -- Note: No DB write or re-broadcast for broadcast events
end)

-- Handle map request
RegisterNetEvent('fivem-pedmatrix:requestMap', function()
    local src = source
    TriggerClientEvent('fivem-pedmatrix:bulkUpdate', src, PlayerHeights)
end)

-- Handle player drop
AddEventHandler('playerDropped', function(reason)
    local src = source
    PlayerHeights[src] = nil
    LastUpdate[src] = nil
    
    -- Notify all nearby clients
    TriggerClientEvent('fivem-pedmatrix:playerLeft', -1, src)
end)

-- Exports for external resources with source validation
exports('SetPlayerHeight', function(source, serverId, scale)
    -- Validate source (must be valid player or admin)
    if type(source) ~= 'number' or source <= 0 then return false end
    
    -- Check admin permission for external calls
    if not IsPlayerAdmin(source) then
        -- Allow self-set only for non-admin
        if serverId ~= source then return false end
    end
    
    if not IsValidScale(scale) then return false end
    
    local Player = QBCore.Functions.GetPlayer(serverId)
    if not Player then return false end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Update in-memory store
    PlayerHeights[serverId] = scale
    
    -- Queue to batch write (optimization)
    if Config.SaveToDatabase then
        PendingDBWrites[citizenid] = scale
    end
    
    -- Broadcast to nearby players only (optimization)
    BroadcastToNearbyPlayers(serverId, scale, -1)
    
    return true
end)

exports('GetPlayerHeight', function(serverId)
    return PlayerHeights[serverId] or 1.0
end)

-- Export for internal database access (BUG-02 fix)
exports('GetAllHeights', function()
    return PlayerHeights
end)

-- Batch database write thread (optimization)
CreateThread(function()
    while true do
        Wait(30000) -- Write pending changes every 30 seconds
        
        if Config.SaveToDatabase and next(PendingDBWrites) then
            for citizenid, scale in pairs(PendingDBWrites) do
                exports['fivem-pedmatrix']:SavePlayerHeight(citizenid, scale)
            end
            PendingDBWrites = {}
        end
    end
end)

print('[fivem-pedmatrix] Server started')
