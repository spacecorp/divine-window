local function toggleDebug()
    DivineWindowGlobalVars.debugMode = not DivineWindowGlobalVars.debugMode
    local debugText = DivineWindowGlobalVars.debugMode and "on" or "off"
    DivineWindow.Utilities.printToUser('DW Debug mode: ' .. debugText);
end

local function resetSavedVariables()
    DivineWindow.Interface.off();
    DivineWindow.ConfigurationScreen:hide();

    DivineWindowGlobalVars = {};
    DivineWindow.Utilities.printToUser("DW Saved Variables have been reset");
end

local function resetSavedVariablesPerCharacter()
    DivineWindow.Interface.off();
    DivineWindow.ConfigurationScreen:hide();
    DivineWindowLocalVars = {};
    DivineWindow.Utilities.printToUser("DW Saved Variables have been reset for this character");
end

local function resetAll()
    resetSavedVariables();
    resetSavedVariablesPerCharacter();
end

-- /dw spellinfo <spell name>: prints what this WoW version's API returns for a spell (icons) and,
-- for 5 seconds, for the spell being channeled. Used to support other versions, e.g. WoW Forever.
local function show(value)
    if (issecretvalue and issecretvalue(value)) then
        return "<secret>";
    end
    return tostring(value);
end

local function spellInfo(spellName)
    local p = DivineWindow.Utilities.printToUser;
    if (not spellName or spellName == "") then
        p("Syntax: /dw spellinfo <spell name>   (then channel a spell within 5 seconds)");
        return;
    end

    p("---- spellinfo: " .. spellName .. " (" .. (GetBuildInfo and select(1, GetBuildInfo()) or "?") .. ") ----");

    if (C_Spell and C_Spell.GetSpellInfo) then
        local info = C_Spell.GetSpellInfo(spellName);
        if (info) then
            p("C_Spell.GetSpellInfo: name=" .. show(info.name) .. " spellID=" .. show(info.spellID) ..
                " iconID=" .. show(info.iconID) .. " originalIconID=" .. show(info.originalIconID));
        else
            p("C_Spell.GetSpellInfo: nil");
        end
        if (info and info.spellID and C_Spell.GetSpellTexture) then
            p("C_Spell.GetSpellTexture(id): " .. show(C_Spell.GetSpellTexture(info.spellID)));
        end
    else
        p("C_Spell.GetSpellInfo: missing");
    end
    if (C_Spell and C_Spell.GetSpellTexture) then
        p("C_Spell.GetSpellTexture(name): " .. show(C_Spell.GetSpellTexture(spellName)));
    end
    if (GetSpellTexture) then
        p("GetSpellTexture(name): " .. show(GetSpellTexture(spellName)));
    end

    -- spellbook entries with this name
    if (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then
        local found = 0;
        local lines = C_SpellBook.GetNumSpellBookSkillLines();
        p("C_SpellBook skill lines: " .. show(lines));
        for line = 1, lines or 0 do
            local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line);
            if (lineInfo) then
                for i = lineInfo.itemIndexOffset + 1, lineInfo.itemIndexOffset + lineInfo.numSpellBookItems do
                    local item = C_SpellBook.GetSpellBookItemInfo(i, Enum.SpellBookSpellBank.Player);
                    if (item and item.name == spellName) then
                        found = found + 1;
                        p("  spellbook: line=" .. line .. " '" .. show(lineInfo.name) .. "' spellID=" ..
                            show(item.spellID) .. " iconID=" .. show(item.iconID) .. " type=" .. show(item.itemType) ..
                            " passive=" .. show(item.isPassive));
                    end
                end
            end
        end
        p("  spellbook matches: " .. found);
    else
        p("C_SpellBook: missing");
    end

    -- cast/channel info: watched for 5 seconds so there is time to start casting or channeling
    local events = {
        "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED",
        "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
        "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP",
    };
    local watcher = CreateFrame("Frame");
    for _, event in ipairs(events) do
        -- unknown events raise an error on some versions
        pcall(watcher.RegisterUnitEvent, watcher, event, "player");
    end
    watcher:SetScript("OnEvent", function(_, event, unit, castGUID, spellId)
        local name = spellId and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellId);
        p("event " .. event .. ": spellID=" .. show(spellId) .. " name=" .. show(name));
    end);

    local seenChannel, seenCast = false, false;
    local samples = 0;
    local ticker;
    ticker = C_Timer.NewTicker(0.25, function()
        samples = samples + 1;

        if (UnitChannelInfo and not seenChannel) then
            local name, _, _, startMS, endMS, _, _, spellId = UnitChannelInfo("player");
            if (name ~= nil) then
                seenChannel = true;
                p("UnitChannelInfo: name=" .. show(name) .. " start=" .. show(startMS) .. " end=" .. show(endMS) ..
                    " spellID=" .. show(spellId) .. " now=" .. show(GetTime()));
            end
        end
        if (UnitCastingInfo and not seenCast) then
            local name, _, _, startMS, endMS, _, _, _, spellId = UnitCastingInfo("player");
            if (name ~= nil) then
                seenCast = true;
                p("UnitCastingInfo: name=" .. show(name) .. " start=" .. show(startMS) .. " end=" .. show(endMS) ..
                    " spellID=" .. show(spellId) .. " now=" .. show(GetTime()));
            end
        end

        if (samples >= 20) then
            ticker:Cancel();
            watcher:UnregisterAllEvents();
            p("---- done: channel seen=" .. tostring(seenChannel) .. ", cast seen=" .. tostring(seenCast) .. " ----");
        end
    end);
end

local function cmd(msg)
    local _, _, cmd, args = string.find(msg, "%s?(%w+)%s?(.*)")

    if cmd == "on" then
        DivineWindow.Interface.on();
    elseif cmd == "off" then
        DivineWindow.Interface.off();
    elseif cmd == "debug" then
        toggleDebug();
    elseif cmd == "config" then
        DivineWindow.ConfigurationScreen:show();
        DivineWindow.Interface.show();
    elseif cmd == "test" then
        DivineWindow.Utilities.printToUser('Testing unlock table:')
        DivineWindow.ConfigurationScreen.addToLockTable(args, nil, true)
    elseif cmd == "spellinfo" then
        spellInfo(args);
    elseif cmd == "dump" then
        DivineWindow.Utilities.printToUser('---- local vars ----')
        DevTools_Dump(DivineWindowLocalVars);
        DivineWindow.Utilities.printToUser('---- global vars ----')
        DevTools_Dump(DivineWindowGlobalVars);
    elseif cmd == "resetGlobal" then
        if (args == "confirm") then
            resetSavedVariables();
        else
            DivineWindow.Utilities.printToUser("To reset the global saved variables, type: /dw resetGlobal confirm");
        end
    elseif cmd == "resetCharacter" then
        if (args == "confirm") then
            resetSavedVariablesPerCharacter();
        else
            DivineWindow.Utilities.printToUser("To reset the character saved variables, type: /dw resetCharacter confirm");
        end
    elseif cmd == "reset" then
        if (args == "confirm" or DivineWindowGlobalVars.debugMode == true) then
            resetAll();
        else
            DivineWindow.Utilities.printToUser("To reset all saved variables, type: /dw reset confirm");
        end
    else
        -- If not handled above, display some sort of help message
        DivineWindow.Utilities.printToUser("To show or hide the button; interface, use one of these commands:");
        DivineWindow.Utilities.printToUser("Syntax: /dw show");
        DivineWindow.Utilities.printToUser("Syntax: /dw hide");
        DivineWindow.Utilities.printToUser("Syntax: /dw config");
        DivineWindow.Utilities.printToUser("", "And to reset the saved settings:");
        DivineWindow.Utilities.printToUser("Syntax: /dw resetGlobal confirm");
        DivineWindow.Utilities.printToUser("Syntax: /dw resetCharacter confirm");
        DivineWindow.Utilities.printToUser("Syntax: /dw resetreset confirm");
    end
end

SlashCmdList["DW"] = cmd;

SLASH_DW1 = "/dw";
SLASH_DW2 = "/divinewindow";

DivineWindow.Utilities.debugPrint("Src/Commands/Commands.lua", "file");
