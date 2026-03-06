-- Server database module for height-sync
-- Handles oxmysql CRUD operations

local DatabaseReady = false

-- Initialize database connection
local function InitDatabase()
    if DatabaseReady then return true end
    
    local result = MySQL.query.await("SHOW TABLES LIKE 'player_heights'")
    if #result == 0 then
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `player_heights` (
                `citizenid`  VARCHAR(50)  NOT NULL,
                `scale`      FLOAT        NOT NULL DEFAULT 1.0,
                `updated_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`citizenid`)
            )
        ]])
    end
    
    DatabaseReady = true
    return true
end

-- Load player height from database
---@param citizenid string Player's citizenid
---@return number scale Player's saved height scale (default 1.0)
exports.LoadPlayerHeight = function(citizenid)
    if not DatabaseReady then
        InitDatabase()
    end
    
    local result = MySQL.query.await('SELECT scale FROM player_heights WHERE citizenid = ?', {citizenid})
    if result and #result > 0 then
        return tonumber(result[1].scale) or 1.0
    end
    
    return 1.0
end

-- Save player height to database
---@param citizenid string Player's citizenid
---@param scale number Height scale to save
exports.SavePlayerHeight = function(citizenid, scale)
    if not DatabaseReady then
        InitDatabase()
    end
    
    MySQL.query.await([[
        INSERT INTO player_heights (citizenid, scale, updated_at)
        VALUES (?, ?, NOW())
        ON DUPLICATE KEY UPDATE scale = VALUES(scale), updated_at = NOW()
    ]], {citizenid, scale})
end
