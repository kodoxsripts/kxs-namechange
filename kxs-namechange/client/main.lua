local isOpen = false
local cooldownActive = false
local detectedFramework = nil

local frameworkObjects = { qbox = nil, qbcore = nil, esx = nil }

local SetNuiFocus = SetNuiFocus
local SendNUIMessage = SendNUIMessage
local DisableControlAction = DisableControlAction
local IsDisabledControlJustReleased = IsDisabledControlJustReleased
local TriggerEvent = TriggerEvent
local Wait = Citizen.Wait
local SetTimeout = Citizen.SetTimeout

local NAME_PATTERN = "^[a-zA-Z'-]+$"

local function GetFrameworkObj()
    return frameworkObjects[detectedFramework]
end

local function GetPlayerDataFromFramework()
    local fw = detectedFramework
    local obj = GetFrameworkObj()
    if not obj then return nil end

    if fw == 'qbox' then
        return obj:GetPlayerData()
    elseif fw == 'qbcore' then
        return obj.Functions.GetPlayerData()
    elseif fw == 'esx' then
        return obj.GetPlayerData()
    end
    return nil
end

local frameworkDetectors = {
    { name = 'qbox', detect = function()
        local obj = exports['qbx_core']
        obj:GetPlayerData()
        return obj
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
    local target = Config.Framework

    for _, fw in ipairs(frameworkDetectors) do
        if target == fw.name or target == 'auto' then
            local ok, obj = pcall(fw.detect)
            if ok and obj then
                frameworkObjects[fw.name] = obj
                detectedFramework = fw.name
                print(('[kxs-namechange] %s framework detected'):format(fw.name))
                return
            end
        end
    end

    detectedFramework = 'standalone'
    print('[kxs-namechange] Standalone mode')
end)

function GetCurrentName()
    local pd = GetPlayerDataFromFramework()

    if detectedFramework == 'qbox' or detectedFramework == 'qbcore' then
        if pd and pd.charinfo then
            return pd.charinfo.firstname or "", pd.charinfo.lastname or ""
        end
    elseif detectedFramework == 'esx' then
        if pd then
            return pd.firstName or pd.firstname or "", pd.lastName or pd.lastname or ""
        end
    end

    return "Unknown", "Player"
end

local function GetPlayerJob()
    local pd = GetPlayerDataFromFramework()
    if pd and pd.job then return pd.job.name end
    return nil
end

local function IsJobAllowed()
    local jobName = GetPlayerJob()
    if not jobName then return false end

    local allowed = Config.AllowedJobs
    for i = 1, #allowed do
        if jobName == allowed[i] then return true end
    end
    return false
end

local function Trim(s)
    return tostring(s):gsub("^%s+", ""):gsub("%s+$", "")
end

local function ContainsBadWord(name)
    local lower = name:lower()
    local words = Config.BadWords
    for i = 1, #words do
        if lower:find(words[i]:lower()) then return true end
    end
    return false
end

function Notify(msg)
    if Config.NotificationType == 'framework' then
        if detectedFramework == 'qbox' then
            pcall(function() exports.qbx_core:Notify(msg, 'inform', 5000) end)
        elseif detectedFramework == 'qbcore' then
            GetFrameworkObj().Functions.Notify(msg, "primary", 5000)
        elseif detectedFramework == 'esx' then
            GetFrameworkObj().ShowNotification(msg)
        else
            TriggerEvent('chat:addMessage', { args = { '[kxs-namechange]', msg } })
        end
    else
        TriggerEvent('chat:addMessage', { args = { '[kxs-namechange]', msg } })
    end
end

function HideUI()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
end

function OpenNameChanger()
    if isOpen then return end

    if cooldownActive then
        Notify("Please wait before changing your name again.")
        return
    end

    if Config.JobLocked and not IsJobAllowed() then
        Notify("You don't have the required job to use this.")
        return
    end

    local firstName, lastName = GetCurrentName()
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "open",
        firstName = firstName,
        lastName = lastName,
        minLength = Config.MinNameLength,
        maxLength = Config.MaxNameLength,
    })
end

RegisterNUICallback('closeui', function(_, cb)
    cb(1)
    HideUI()
end)

RegisterNUICallback('submit', function(data, cb)
    local newFirst = Trim(data.firstName or "")
    local newLast = Trim(data.lastName or "")
    local minLen = Config.MinNameLength
    local maxLen = Config.MaxNameLength

    if #newFirst < minLen or #newLast < minLen then
        cb(json.encode({ ok = false, err = "Names must be at least " .. minLen .. " characters." }))
        return
    end

    if #newFirst > maxLen or #newLast > maxLen then
        cb(json.encode({ ok = false, err = "Names cannot exceed " .. maxLen .. " characters." }))
        return
    end

    if not newFirst:match(NAME_PATTERN) or not newLast:match(NAME_PATTERN) then
        cb(json.encode({ ok = false, err = "Names can only contain letters, hyphens, and apostrophes." }))
        return
    end

    if ContainsBadWord(newFirst) or ContainsBadWord(newLast) then
        cb(json.encode({ ok = false, err = "That name contains a restricted word." }))
        return
    end

    cb(json.encode({ ok = true }))
    TriggerServerEvent('kxs-namechange:server:changeName', newFirst, newLast)
end)

RegisterNetEvent('kxs-namechange:client:nameChanged', function(firstName, lastName)
    HideUI()
    Notify("Name successfully changed to " .. firstName .. " " .. lastName)

    if Config.Cooldown > 0 then
        cooldownActive = true
        SetTimeout(Config.Cooldown * 1000, function()
            cooldownActive = false
        end)
    end
end)

RegisterNetEvent('kxs-namechange:client:nameChangeFailed', function(reason)
    SendNUIMessage({ action = "error", message = reason or "Name change failed." })
end)

RegisterNetEvent('kxs-namechange:client:useItem', function()
    OpenNameChanger()
end)

if not Config.UseItem then
    RegisterCommand(Config.Command, function()
        OpenNameChanger()
    end, false)
end

RegisterCommand('changename', function()
    OpenNameChanger()
end, false)

local DISABLED_CONTROLS = { 1, 2, 142, 18, 322, 106 }

Citizen.CreateThread(function()
    while true do
        if isOpen then
            Wait(0)
            for i = 1, #DISABLED_CONTROLS do
                DisableControlAction(0, DISABLED_CONTROLS[i], true)
            end
            if IsDisabledControlJustReleased(0, 322) then
                HideUI()
            end
        else
            Wait(500)
        end
    end
end)
