-- Client sync module for height-sync
-- Broadcast loop, remote apply loop, event listeners

RemoteHeights = {}  -- [serverId] = {scale = number, ped = number}

-- Cached player peds for performance (P3 optimization)
local PlayerPedCache = {}

-- Apply scale to entity to remote player
---@param serverId number Server ID of the player
---@param scale number Height scale to apply
local function ApplyRemoteScale(serverId, scale)
    -- Skip if scale is 1.0 (P2 optimization)
    if scale == 1.0 then return end
    
    local ped = GetPlayerPed(GetPlayerFromServerId(serverId))
    
    if not DoesEntityExist(ped) then return end
    
    local localPed = PlayerPedId()
    local localPos = GetEntityCoords(localPed)
    local remotePos = GetEntityCoords(ped)
    
    -- Distance check (P2 optimization: batch before GetPlayerPed)
    local dist = #(localPos - remotePos)
    if dist > Config.SyncDistance then return end
    
    -- Update cache
    PlayerPedCache[serverId] = ped
    
    -- Skip if in vehicle (P2 optimization)
    if IsPedInAnyVehicle(ped, false) then return end
    
    local matrix = BuildMatrix(ped, scale)
    SetEntityMatrix(ped, matrix.right, matrix.forward, matrix.up, matrix.position)
end

-- Per-frame matrix application with throttle (remote players)
CreateThread(function()
    local frameCount = 0
    while true do
        Wait(15) -- Throttle to ~66fps instead of every frame
        frameCount = frameCount + 1
        
        local localPed = PlayerPedId()
        local localPos = GetEntityCoords(localPed)
        
        for serverId, data in pairs(RemoteHeights) do
            -- Skip if scale is 1.0 (P2 optimization)
            if data.scale ~= 1.0 then
                local ped = PlayerPedCache[serverId]
                
                if ped and DoesEntityExist(ped) then
                    -- Check distance
                    local remotePos = GetEntityCoords(ped)
                    local dist = #(localPos - remotePos)
                    
                    if dist <= Config.SyncDistance then
                        -- Skip if in vehicle (P2 optimization)
                        if not IsPedInAnyVehicle(ped, false) then
                            local matrix = BuildMatrix(ped, data.scale)
                            SetEntityMatrix(ped, matrix.right, matrix.forward, matrix.up, matrix.position)
                        end
                    end
                end
            end
        end
    end
end)

-- Periodic broadcast loop
CreateThread(function()
    while true do
        Wait(Config.SyncInterval)
        
        local scale = GetLocalHeight()
        if scale and scale ~= 1.0 then
            TriggerServerEvent('height-sync:broadcast', scale)
        end
    end
end)

-- Handle bulk update (player join)
RegisterNetEvent('height-sync:bulkUpdate', function(heights)
    for serverId, scale in pairs(heights) do
        RemoteHeights[serverId] = {scale = scale}
    end
end)

-- Handle player height update
RegisterNetEvent('height-sync:playerUpdate', function(serverId, scale)
    -- Self-filter: ignore own updates
    if serverId == GetPlayerServerId(PlayerId()) then return end
    
    RemoteHeights[serverId] = {scale = scale}
end)

-- Handle player left
RegisterNetEvent('height-sync:playerLeft', function(serverId)
    RemoteHeights[serverId] = nil
    PlayerPedCache[serverId] = nil
end)

print('[height-sync] Sync module started')
