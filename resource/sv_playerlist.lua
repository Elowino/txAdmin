-- =============================================
--  Server PlayerList handler
-- =============================================
--Check Environment
if GetConvar('txAdminServerMode', 'false') ~= 'true' then
    return
end
function logError(x)
    print("^5[txAdminClient]^1 " .. x .. "^0")
end
local oneSyncConvar = GetConvar('onesync', 'off')
local onesyncEnabled = oneSyncConvar == 'on' or oneSyncConvar == 'legacy'


-- Optimizations
local floor = math.floor
local max = math.max
local min = math.min
local sub = string.sub
local tonumber = tonumber
local tostring = tostring
local pairs = pairs


-- Variables & Consts
local refreshMinDelay = 1500
local refreshMaxDelay = 5000
local maxPlayersDelayCeil = 300 --at this number, the delay won't increase more
local intervalYieldLimit = 50
local vTypeMap = {
    ["nil"] = -1,
    ["walking"] = 0,
    ["automobile"] = 1,
    ["bike"] = 2,
    ["boat"] = 3,
    ["heli"] = 4,
    ["plane"] = 5,
    ["submarine"] = 6,
    ["trailer"] = 7,
    ["train"] = 8,
}


--[[ Refresh player list data ]]
CreateThread(function()
    while true do
        -- For each player
        local players = GetPlayers()
        for yieldCounter, serverID in pairs(players) do
            -- Updating player vehicle/health
            -- NOTE: after testing this seem not to need any error handling
            local health = 0
            local vType = -1
            if onesyncEnabled == true then
                local ped = GetPlayerPed(serverID)
                local veh = GetVehiclePedIsIn(ped)
                if veh ~= 0 then
                    vType = vTypeMap[tostring(GetVehicleType(veh))]
                else
                    vType = vTypeMap["walking"]
                end
                -- Its extremely hard to normalize this value to actually reflect
                -- it as a percentage of the current users max health depending on the server
                -- Therefore, lets just handle for base case of maxHealth 175 and health range from 100-175
                health = floor((GetEntityHealth(ped) - 100) / (GetEntityMaxHealth(ped) - 100) * 100)
            end

            -- Updating TX_PLAYERLIST
            if type(TX_PLAYERLIST[serverID]) ~= 'table' then
                TX_PLAYERLIST[serverID] = {
                    name = sub(GetPlayerName(serverID) or "unknown", 1, 75),
                    health = health,
                    vType = vType,
                }
            else
                TX_PLAYERLIST[serverID].health = health
                TX_PLAYERLIST[serverID].vType = vType
            end

            -- Mark as refreshed
            TX_PLAYERLIST[serverID].foundLastCheck = true

            -- Yield to prevent hitches
            if yieldCounter % intervalYieldLimit == 0 then
                Wait(0)
            end
        end --end for players


        --Check if player disconnected
        for playerID, playerData in pairs(TX_PLAYERLIST) do
            if playerData.foundLastCheck == true then
                playerData.foundLastCheck = false
            else
                TX_PLAYERLIST[playerID] = nil
            end
        end

        -- DEBUG
        -- debugPrint("====================================")
        -- print(json.encode(TX_PLAYERLIST, {indent = true}))
        -- debugPrint("====================================")

        -- Refresh interval with linear function
        local hDiff = refreshMaxDelay - refreshMinDelay
        local calcDelay = (hDiff/maxPlayersDelayCeil) * (#players) + refreshMinDelay
        local delay = floor(min(calcDelay, refreshMaxDelay))
        Wait(delay)
    end --end while true
end)


--[[ Handle player Join or Leave ]]
AddEventHandler('playerJoining', function(srcString, _oldID)
    -- sanity checking source
    if source <= 0 then 
        logError('playerJoining event with source '..json.encode(source))
        return
    end

    local playerData = {
        name = sub(GetPlayerName(source) or "unknown", 1, 75),
        ids = GetPlayerIdentifiers(source),
        hwids = GetPlayerTokens(source),
    }
    PrintStructuredTrace(json.encode({
        type = 'txAdminPlayerlistEvent',
        event = 'playerJoining',
        id = source,
        player = playerData
    }))

    -- relaying this info to all admins
    for adminID, _ in pairs(TX_ADMINS) do
        TriggerClientEvent('txcl:updatePlayer', adminID, source, playerData.playerName)
    end
end)

AddEventHandler('playerDropped', function(reason)
    -- sanity checking source
    if source <= 0 then 
        logError('playerDropped event with source '..json.encode(source))
        return
    end

    PrintStructuredTrace(json.encode({
        type = 'txAdminPlayerlistEvent',
        event = 'playerDropped',
        id = source,
        reason = reason
    }))

    -- relaying this info to all admins
    for adminID, _ in pairs(TX_ADMINS) do
        TriggerClientEvent('txcl:updatePlayer', adminID, source, false)
    end
end)


-- Handle getDetailedPlayerlist
-- This event is only called when the menu "players" tab is opened, and every 5s while the tab is open
-- DEBUG playerlist scroll test stuff
-- math.randomseed(os.time())
-- local fake_playerlist = {}
-- local fake_admins = {1, 10, 21, 61, 91, 141, 281}
-- local function getFakePlayer()
--     return {
--         name = 'fake'..tostring(math.random(999999)),
--         health = 0,
--         vType = math.random(8),
--     }
-- end
-- for serverID=1, 500 do
--     fake_playerlist[serverID] = getFakePlayer()
-- end
RegisterNetEvent('txsv:getDetailedPlayerlist', function()
    if TX_ADMINS[tostring(source)] == nil then
        debugPrint('Ignoring unauthenticated getDetailedPlayerlist() by ' .. source)
        return
    end

    local players = {}
    --DEBUG replace TX_PLAYERLIST with fake_playerlist and playerData.health with math.random(150)
    for playerID, playerData in pairs(TX_PLAYERLIST) do
        players[#players + 1] = {tonumber(playerID), playerData.health, playerData.vType}
    end
    local admins = {}
    for adminID, _ in pairs(TX_ADMINS) do
        admins[#admins + 1] = tonumber(adminID)
    end
    --DEBUG replace admins with fake_admins
    TriggerClientEvent('txcl:setDetailedPlayerlist', source, players, admins)
end)


-- Sends the initial playlist to a specific admin
-- Triggered by the server after admin auth
function sendInitialPlayerlist(adminID)
    local payload = {}
    --DEBUG replace TX_PLAYERLIST with fake_playerlist
    for playerID, playerData in pairs(TX_PLAYERLIST) do
        payload[#payload + 1] = {tonumber(playerID), playerData.name}
    end
    --DEBUG
    -- debugPrint("====================================")
    -- print(json.encode(payload, {indent = true}))
    -- debugPrint("====================================")

    debugPrint('Sending initial playerlist to ' .. adminID)
    TriggerClientEvent('txcl:setInitialPlayerlist', adminID, payload)
end
