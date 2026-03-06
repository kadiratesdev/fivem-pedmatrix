-- Client main module for height-sync
-- Core state, matrix apply, NUI callbacks

LocalHeight = 1.0
HeightApplied = false

-- Build transformation matrix for entity scaling
---@param entity number Entity handle
---@param scale number Height scale
local function BuildMatrix(entity, scale)
    local heading = GetEntityHeading(entity)
    local rad = heading * math.pi / 180.0
    
    -- Calculate forward vector (rotation only, no scale)
    local forwardX = math.sin(rad)
    local forwardY = math.cos(rad)
    
    -- Calculate right vector (rotation only, no scale) - FIXED: consistent with forward
    local rightX = math.cos(rad)
    local rightY = -math.sin(rad)
    
    -- Up vector with Z-axis scale
    local upX = 0.0
    local upY = 0.0
    local upZ = scale
    
    -- Position
    local pos = GetEntityCoords(entity)
    
    return {
        forward = {x = forwardX, y = forwardY, z = 0.0},
        right = {x = rightX, y = rightY, z = 0.0},
        up = {x = upX, y = upY, z = upZ},
        position = {x = pos.x, y = pos.y, z = pos.z}
    }
end

-- Apply scale to entity using SetEntityMatrix
---@param entity number Entity handle
---@param scale number Height scale
function ApplyScaleToEntity(entity, scale)
    if not DoesEntityExist(entity) then return end
    
    local matrix = BuildMatrix(entity, scale)
    SetEntityMatrix(entity, matrix.right, matrix.forward, matrix.up, matrix.position)
    HeightApplied = true
end

-- Reset entity matrix to default
---@param entity number Entity handle
function ResetEntityMatrix(entity)
    if not DoesEntityExist(entity) then return end
    
    local heading = GetEntityHeading(entity)
    local rad = heading * math.pi / 180.0
    
    local forwardX = math.sin(rad)
    local forwardY = math.cos(rad)
    local rightX = math.cos(rad)
    local rightY = -math.sin(rad)
    
    local pos = GetEntityCoords(entity)
    
    SetEntityMatrix(entity, 
        {x = rightX, y = rightY, z = 0.0},
        {x = forwardX, y = forwardY, z = 0.0},
        {x = 0.0, y = 0.0, z = 1.0},
        {x = pos.x, y = pos.y, z = pos.z}
    )
end

-- Set local player height
---@param scale number Height scale
function SetLocalHeight(scale)
    -- Clamp to valid range
    scale = math.max(Config.MinHeight, math.min(Config.MaxHeight, scale))
    LocalHeight = scale
    
    -- Send to server
    TriggerServerEvent('height-sync:setHeight', scale)
end

-- Get local player height
---@return number Height scale
function GetLocalHeight()
    return LocalHeight
end

-- Get UI open state
---@return boolean Whether UI is open
function GetUIOpen()
    return UIOpen or false
end

-- Set UI open state
---@param state boolean Open state
function SetUIOpen(state)
    UIOpen = state
end

-- NUI callback: set height from UI with validation
RegisterNUICallback('setHeight', function(data, cb)
    -- Validate NUI source - only accept from our own UI
    if not GetUIOpen() then
        cb('error')
        return
    end
    
    local scale = tonumber(data.scale)
    if scale then
        -- Validate scale range
        scale = math.max(Config.MinHeight, math.min(Config.MaxHeight, scale))
        SetLocalHeight(scale)
    end
    cb('ok')
end)

-- NUI callback: close UI
RegisterNUICallback('close', function(data, cb)
    SetUIOpen(false)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Per-frame matrix application with throttle (local player)
CreateThread(function()
    local frameCount = 0
    while true do
        Wait(15) -- Throttle to ~66fps instead of every frame
        
        local ped = PlayerPedId()
        if DoesEntityExist(ped) and LocalHeight ~= 1.0 then
            -- Skip if in vehicle (P2 optimization)
            if not IsPedInAnyVehicle(ped, false) then
                ApplyScaleToEntity(ped, LocalHeight)
            end
        end
    end
end)

-- BUG-01 Fix: Trigger requestInit on QBCore player loaded
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('height-sync:requestInit')
end)

-- Also handle resource restart mid-session
AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then
        TriggerServerEvent('height-sync:requestInit')
    end
end)

-- Handle receiving height from server
RegisterNetEvent('height-sync:receiveHeight', function(serverId, scale)
    if serverId == GetPlayerServerId(PlayerId()) then
        LocalHeight = scale
    end
end)

-- Reset height on resource stop
AddEventHandler('onClientResourceStop', function(res)
    if res == GetCurrentResourceName() then
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            ResetEntityMatrix(ped)
        end
    end
end)

-- P3: Death/respawn handler to reset HeightApplied state
AddEventHandler('ped:onPlayerDied', function()
    HeightApplied = false
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        ResetEntityMatrix(ped)
    end
    HeightApplied = false
    LocalHeight = 1.0
end)

print('[height-sync] Client started')
