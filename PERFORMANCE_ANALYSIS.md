# Height-Sync Performance Analysis Report

**Analysis Date:** 2026-03-06  
**Resource:** height-sync v1.0.0  
**Framework:** QBCore  

---

## Executive Summary

This report identifies critical performance issues, bugs, and QBCore integration problems in the height-sync resource. Several issues require immediate attention to prevent server instability and poor client performance.

---

## 🔴 Critical Issues

### 1. Duplicate Code Bug (server/main.lua:120-125)

**Location:** [`height-sync/server/main.lua:120-125`](height-sync/server/main.lua:120)

```lua
    -- Update in-memory store only if changed
    if PlayerHeights[src] ~= scale then
        PlayerHeights[src] = scale
    end
    -- Note: No DB write or re-broadcast for broadcast events
end)
```

This code block is duplicated from lines 114-117. It creates a syntax issue and will cause runtime errors.

**Fix Required:** Remove the duplicate code block (lines 120-125).

---

### 2. Missing Function Definition (client/sync.lua:10-35)

**Location:** [`height-sync/client/sync.lua:10-35`](height-sync/client/sync.lua:10)

The `ApplyRemoteScale` function is referenced but never properly defined. The code starts at line 12 without a function declaration:

```lua
-- Apply scale to entity (P3: cache GetPlayerFromServerId results)
-- Uses BuildMatrix from main.lua
    -- Skip if scale is 1.0 (P2 optimization)   <-- Line 12, no function definition!
    if scale == 1.0 then return end
```

**Impact:** This function is never called, so remote player scaling may not work correctly.

---

### 3. Rate Limiting Conflict (server/main.lua:21-50)

**Location:** [`height-sync/server/main.lua:21-50`](height-sync/server/main.lua:21)

Both `CanUpdate()` and `CanBroadcast()` share the same `LastUpdate` table:

```lua
local LastUpdate = {}  -- Rate limiting: [serverId] = timestamp
```

When a player calls `setHeight`, the rate limit is updated. When they then call `broadcast`, the timestamp is checked against the same table, causing unintended rate limit blocking.

**Fix Required:** Use separate rate limit tables:
```lua
local LastHeightUpdate = {}
local LastBroadcastUpdate = {}
```

---

## 🟠 Performance Issues

### 4. Frame-Rate Dependent Client Threads

**Locations:**
- [`height-sync/client/main.lua:118-130`](height-sync/client/main.lua:118) - Local player apply loop
- [`height-sync/client/sync.lua:38-66`](height-sync/client/sync.lua:38) - Remote player apply loop

Both threads use `Wait(0)`, running on every frame:

```lua
CreateThread(function()
    while true do
        Wait(0)  -- Runs 60+ times per second!
```

**Impact:** On a 60 FPS server with 32 players, this creates 1920+ matrix operations per second.

**Recommendations:**
1. Use `Wait(100)` for remote player updates (10 FPS is sufficient)
2. Add dirty flag checking to only apply when position changes
3. Consider using `SetEntityAsMissionEntity` for batch updates

---

### 5. No Distance Culling for Local Player

**Location:** [`height-sync/client/main.lua:122-128`](height-sync/client/main.lua:122)

```lua
local ped = PlayerPedId()
if DoesEntityExist(ped) and LocalHeight ~= 1.0 then
    if not IsPedInAnyVehicle(ped, false) then
        ApplyScaleToEntity(ped, LocalHeight)  -- Always applies, no distance check
    end
end
```

While this is for the local player (acceptable), the matrix is rebuilt every frame even when heading hasn't changed.

**Optimization:** Cache the matrix and only rebuild when heading changes.

---

### 6. Inefficient Remote Player Iteration

**Location:** [`height-sync/client/sync.lua:45-64`](height-sync/client/sync.lua:45)

```lua
for serverId, data in pairs(RemoteHeights) do
    -- Check distance for EACH player every frame
    local remotePos = GetEntityCoords(ped)
    local dist = #(localPos - remotePos)
```

**Issues:**
- `GetEntityCoords()` called every frame for every remote player
- No early exit when player count is high
- Distance calculation happens even when not needed

**Optimization:** Only check distance every 10 frames or use spatial partitioning.

---

### 7. Unbounded Memory Growth

**Location:** [`height-sync/client/sync.lua:4`](height-sync/client/sync.lua:4)

```lua
RemoteHeights = {}  -- [serverId] = {scale = number, ped = number}
PlayerPedCache = {}  -- Cached player peds for performance
```

Both tables grow as players join but never get cleaned except on player drop.

**Issue:** If a player disconnects unexpectedly, stale entries may remain.

---

### 8. Database Write on Every Height Change

**Location:** [`height-sync/server/main.lua:94-97`](height-sync/server/main.lua:94)

```lua
if Config.SaveToDatabase then
    exports['height-sync']:SavePlayerHeight(citizenid, scale)
end
```

Every height change triggers an immediate database write with `MySQL.query.await`. With rate limiting at 200ms, this could cause database pressure.

**Recommendations:**
1. Use debounced writes (save only after player stops changing height for 5 seconds)
2. Use batch updates for multiple players
3. Consider async writes with callbacks

---

## 🟡 QBCore Integration Issues

### 9. No QBCore Player Validation

**Location:** [`height-sync/server/main.lua:55-56`](height-sync/server/main.lua:55)

```lua
local Player = QBCore.Functions.GetPlayer(src)
if not Player then return end
```

While this checks if player exists, it doesn't validate:
- Player session state
- Player permissions (if admin-only features)
- Player job (if job-restricted)

---

### 10. Potential QBCore State Desync

**Location:** [`height-sync/client/main.lua:133-135`](height-sync/client/main.lua:133)

```lua
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('height-sync:requestInit')
end)
```

If QBCore's player loading is delayed or fails, height-sync may request init before the player is fully ready.

**Fix:** Add a small delay or check QBCore.PlayerData ready state.

---

### 11. Missing QBCore Permission Checks

**Location:** [`height-sync/server/main.lua:144-164`](height-sync/server/main.lua:144)

The exports `SetPlayerHeight` and `GetPlayerHeight` have no permission checks:

```lua
exports('SetPlayerHeight', function(serverId, scale)
    -- No permission check! Any resource can call this
```

**Risk:** Other resources could manipulate player heights without authorization.

---

## 📊 Performance Metrics

| Metric | Current | Recommended |
|--------|---------|-------------|
| Client threads (Wait(0)) | 2 | 1 |
| Remote update frequency | Every frame | Every 100-200ms |
| DB writes per height change | 1 | Debounced (1 per 5s) |
| Matrix rebuilds/second | 60+ per player | On dirty flag only |
| Memory cleanup | On disconnect | Periodic + on disconnect |

---

## ✅ Recommended Fixes Priority

### Immediate (P0)
1. Remove duplicate code in server/main.lua:120-125
2. Fix missing function definition in client/sync.lua:10-35
3. Separate rate limit tables for height vs broadcast

### High Priority (P1)
4. Change remote player update interval to 100-200ms
5. Add debounced database writes
6. Add permission checks to exports

### Medium Priority (P2)
7. Add matrix caching for local player
8. Implement periodic cleanup of stale cache entries
9. Add QBCore player state validation

---

## 📝 QBCore Best Practices Applied

✅ Uses `QBCore.Functions.GetPlayer(src)` for player lookup  
✅ Uses `QBCore:Client:OnPlayerLoaded` event  
✅ Uses `QBCore:Client:OnPlayerUnload` event  
✅ Uses `oxmysql` for database (QBCore standard)  
✅ Exports functions for external access  

---

*Report generated for fivem-pedmatrix project*
