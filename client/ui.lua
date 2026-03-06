-- Client UI module for height-sync
-- RegisterCommand, RegisterKeyMapping, NUI management

-- Open height UI
local function OpenHeightUI()
    if not GetUIOpen() then
        SetUIOpen(true)
        SetNuiFocus(true, true)
        SendNUIMessage({
            type = 'open',
            minHeight = Config.MinHeight,
            maxHeight = Config.MaxHeight,
            currentHeight = GetLocalHeight()
        })
    end
end

-- Close height UI
local function CloseHeightUI()
    if GetUIOpen() then
        SetUIOpen(false)
        SetNuiFocus(false, false)
    end
end

-- Register chat command
RegisterCommand(Config.CommandName, function()
    OpenHeightUI()
end, false)

-- Register key mapping (F2 by default)
RegisterKeyMapping(Config.CommandName, 'Open Height Sync UI', 'keyboard', 'F2')

print('[height-sync] UI module started')
