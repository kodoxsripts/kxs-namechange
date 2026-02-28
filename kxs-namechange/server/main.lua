local detectedFramework = nil
local useOxInventory = false

local frameworkObjects = { qbox = nil, qbcore = nil, esx = nil }

local TriggerClientEvent = TriggerClientEvent
local GetPlayerName = GetPlayerName
local tostring = tostring
local pcall = pcall

local cfg = {
    framework       = Config.Framework,
    itemName        = Config.ItemName,
    removeItem      = Config.RemoveItemOnUse,
    useItem         = Config.UseItem,
    minLen          = Config.MinNameLength,
    maxLen          = Config.MaxNameLength,
    badWords        = Config.BadWords,
    logChanges      = Config.LogChanges,
}

local NAME_PATTERN = "^[a-zA-Z'-]+$"

local function GetFrameworkObj()
    return frameworkObjects[detectedFramework]
end

local function Trim(s)
    return tostring(s):gsub("^%s+", ""):gsub("%s+$", "")
end

local function Capitalize(s)
    return s:sub(1, 1):upper() .. s:sub(2):lower()
end

local function ContainsBadWord(name)
    local lower = name:lower()
    for i = 1, #cfg.badWords do
        if lower:find(cfg.badWords[i]:lower()) then return true end
    end
    return false
end

local function ValidateName(first, last)
    if not first or not last then
        return false, "Invalid name provided."
    end

    first = Trim(first)
    last = Trim(last)

    if #first < cfg.minLen or #last < cfg.minLen then
        return false, "Names too short."
    end
    if #first > cfg.maxLen or #last > cfg.maxLen then
        return false, "Names too long."
    end
    if not first:match(NAME_PATTERN) or not last:match(NAME_PATTERN) then
        return false, "Invalid characters."
    end
    if ContainsBadWord(first) or ContainsBadWord(last) then
        return false, "Name contains a restricted word."
    end

    return true, Capitalize(first), Capitalize(last)
end

function RemovePlayerItem(playerId)
    if useOxInventory then
        pcall(function()
            exports.ox_inventory:RemoveItem(playerId, cfg.itemName, 1)
        end)
        return
    end

    if detectedFramework == 'qbcore' then
        local Player = GetFrameworkObj().Functions.GetPlayer(playerId)
        if Player then
            Player.Functions.RemoveItem(cfg.itemName, 1)
            pcall(function()
                local shared = GetFrameworkObj().Shared.Items[cfg.itemName]
                TriggerClientEvent('inventory:client:ItemBox', playerId, shared, 'remove')
            end)
        end
    elseif detectedFramework == 'esx' then
        local xPlayer = GetFrameworkObj().GetPlayerFromId(playerId)
        if xPlayer then
            xPlayer.removeInventoryItem(cfg.itemName, 1)
        end
    end
end

local function RegisterItemUsage(callback)
    if not cfg.useItem then return end

    if detectedFramework == 'qbox' then
        pcall(function()
            exports['qbx_core']:CreateUseableItem(cfg.itemName, callback)
        end)
    elseif detectedFramework == 'qbcore' then
        GetFrameworkObj().Functions.CreateUseableItem(cfg.itemName, function(source)
            local Player = GetFrameworkObj().Functions.GetPlayer(source)
            if not Player then return end
            callback(source)
        end)
    elseif detectedFramework == 'esx' then
        GetFrameworkObj().RegisterUsableItem(cfg.itemName, callback)
    end
end

local function OnItemUsed(playerId)
    if cfg.removeItem then
        RemovePlayerItem(playerId)
    end
    TriggerClientEvent('kxs-namechange:client:useItem', playerId)
end

Citizen.CreateThread(function()
    if GetResourceState('ox_inventory') == 'started' then
        useOxInventory = true
        print('[kxs-namechange] Server: ox_inventory detected')
    end
end)

local frameworkDetectors = {
    { name = 'qbox', detect = function()
        return exports['qbx_core']
    end },
    { name = 'qbcore', detect = function()
        return exports['qb-core']:GetCoreObject()
    end },
    { name = 'esx', detect = function()
        local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
        if ok and obj then return obj end
        local esxObj
        TriggerEvent('esx:getSharedObject', function(o) esxObj = o end)
        return esxObj
    end },
}

Citizen.CreateThread(function()
    local target = cfg.framework

    for _, fw in ipairs(frameworkDetectors) do
        if target == fw.name or target == 'auto' then
            local ok, obj = pcall(fw.detect)
            if ok and obj then
                frameworkObjects[fw.name] = obj
                detectedFramework = fw.name
                print(('[kxs-namechange] Server: %s framework detected'):format(fw.name))
                RegisterItemUsage(OnItemUsed)
                return
            end
        end
    end

    detectedFramework = 'standalone'
    print('[kxs-namechange] Server: Standalone mode')
end)

local function UpdateQBName(source, newFirst, newLast)
    local Player
    if detectedFramework == 'qbox' then
        Player = exports.qbx_core:GetPlayer(source)
    else
        Player = GetFrameworkObj().Functions.GetPlayer(source)
    end

    if not Player then return false, "", "" end

    local charinfo = Player.PlayerData.charinfo
    local oldFirst = charinfo.firstname
    local oldLast = charinfo.lastname

    charinfo.firstname = newFirst
    charinfo.lastname = newLast
    Player.Functions.SetPlayerData("charinfo", charinfo)

    MySQL.update('UPDATE players SET charinfo = ? WHERE citizenid = ?', {
        json.encode(charinfo), Player.PlayerData.citizenid
    })

    return true, oldFirst, oldLast
end

local function UpdateESXName(source, newFirst, newLast)
    local xPlayer = GetFrameworkObj().GetPlayerFromId(source)
    if not xPlayer then return false, "", "" end

    local oldFirst = xPlayer.get('firstName') or xPlayer.getName() or ""
    local oldLast = xPlayer.get('lastName') or ""

    xPlayer.set('firstName', newFirst)
    xPlayer.set('lastName', newLast)
    xPlayer.setName(newFirst .. ' ' .. newLast)

    MySQL.update('UPDATE users SET firstname = ?, lastname = ? WHERE identifier = ?', {
        newFirst, newLast, xPlayer.getIdentifier()
    })

    return true, oldFirst, oldLast
end

RegisterNetEvent('kxs-namechange:server:changeName', function(rawFirst, rawLast)
    local source = source

    local valid, first, last = ValidateName(rawFirst, rawLast)
    if not valid then
        TriggerClientEvent('kxs-namechange:client:nameChangeFailed', source, first)
        return
    end

    local success, oldFirst, oldLast = false, "", ""

    if detectedFramework == 'qbox' or detectedFramework == 'qbcore' then
        success, oldFirst, oldLast = UpdateQBName(source, first, last)
    elseif detectedFramework == 'esx' then
        success, oldFirst, oldLast = UpdateESXName(source, first, last)
    else
        success = true
        oldFirst, oldLast = "Unknown", "Player"
    end

    if success then
        TriggerClientEvent('kxs-namechange:client:nameChanged', source, first, last)
        if cfg.logChanges then
            print(('[kxs-namechange] Player %s (ID: %d) changed name: %s %s -> %s %s'):format(
                GetPlayerName(source), source, oldFirst, oldLast, first, last
            ))
        end
    else
        TriggerClientEvent('kxs-namechange:client:nameChangeFailed', source, "Failed to update character data.")
    end
end)
