-- Keeps track of the player's auras through combat on WoW Midnight (12.0+).
--
-- In combat, aura access is secret: looking up a single aura by name or spell ID no longer works,
-- and the name/spell ID of an aura can't be read. Aura instance IDs are NOT secret though, and
-- UNIT_AURA still reports which instance IDs are removed.
--
-- So: while auras are readable (out of combat), remember name -> auraInstanceID. In combat, an aura
-- counts as active as long as its remembered instance has not been removed.
-- Limitation: an aura that is applied *during* combat can't be identified (unless Blizzard marks it
-- as never secret), so it only shows once combat ends.
DivineWindow.AuraTracker = {}
local Tracker = DivineWindow.AuraTracker

local UNIT = "player"
local FILTERS = { "HELPFUL", "HARMFUL" }

-- Only needed on clients with secret values; everything else uses the regular name lookup.
Tracker.isSupported = issecretvalue ~= nil and C_UnitAuras ~= nil and C_UnitAuras.GetUnitAuras ~= nil

local byName = {}     -- aura name -> { [auraInstanceID] = true }
local byInstance = {} -- auraInstanceID -> aura name

local function isSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

local function readableId(id)
    return id ~= nil and not isSecret(id)
end

local function remember(aura)
    local id, name = aura.auraInstanceID, aura.name
    if (not readableId(id) or name == nil or isSecret(name)) then
        return
    end

    byInstance[id] = name
    byName[name] = byName[name] or {}
    byName[name][id] = true
end

local function forget(id)
    if (not readableId(id)) then
        return
    end

    local name = byInstance[id]
    if (not name) then
        return
    end

    byInstance[id] = nil
    local instances = byName[name]
    if (instances) then
        instances[id] = nil
        if (next(instances) == nil) then
            byName[name] = nil
        end
    end
end

-- Re-reads every aura. Names are only learned while readable; instances that are gone are dropped.
local function scan()
    local present = {}

    for _, filter in ipairs(FILTERS) do
        local ok, auras = pcall(C_UnitAuras.GetUnitAuras, UNIT, filter)
        if (not ok or type(auras) ~= "table") then
            return -- can't tell what is present; keep what we know rather than dropping everything
        end

        for _, aura in ipairs(auras) do
            local readOk, id = pcall(function() return aura.auraInstanceID end)
            if (not (readOk and readableId(id))) then
                return
            end
            present[id] = true
            pcall(remember, aura)
        end
    end

    for id in pairs(byInstance) do
        if (not present[id]) then
            forget(id)
        end
    end
end

-- Never let unexpected secret values break the event handler; on failure nothing is changed.
local function fullScan()
    pcall(scan)
end

-- A field of the UNIT_AURA payload, or nil when it is secret (in combat even isFullUpdate
-- and addedAuras can be secret; testing them errors).
local function readableField(updateInfo, key)
    local value = updateInfo[key]
    if (isSecret(value)) then
        return nil, true
    end
    return value, false
end

local function onUnitAura(updateInfo)
    if (not updateInfo) then
        fullScan()
        return
    end

    local isFullUpdate, fullUpdateSecret = readableField(updateInfo, "isFullUpdate")
    -- unknown whether everything changed: rescan; fullScan keeps what it can't read
    if (fullUpdateSecret or isFullUpdate) then
        fullScan()
        return
    end

    local added = readableField(updateInfo, "addedAuras")
    if (type(added) == "table") then
        for _, aura in ipairs(added) do
            pcall(remember, aura)
        end
    end

    local removed = readableField(updateInfo, "removedAuraInstanceIDs")
    if (type(removed) == "table") then
        for _, id in ipairs(removed) do
            forget(id)
        end
    end
end

-- True when the player has an aura with this name that was seen while auras were readable
-- and has not been removed since.
function Tracker.isActive(name)
    return Tracker.isSupported and name ~= nil and byName[name] ~= nil
end

if (Tracker.isSupported) then
    local frame = CreateFrame("Frame")
    frame:RegisterUnitEvent("UNIT_AURA", UNIT)
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event, _, updateInfo)
        if (event == "UNIT_AURA") then
            onUnitAura(updateInfo)
        else
            fullScan()
        end
    end)
end

DivineWindow.Utilities.debugPrint("Src/Interface/AuraTracker.lua", "file")
