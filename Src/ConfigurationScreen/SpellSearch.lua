-- Searchable spell picker for the "Buff/Debuff or Spell" inputs of the specialisation settings.
--
-- Typing only filters the list; the saved value is the exact name of the spell that is picked
-- (or, explicitly, the typed text via the "Use ... as typed" row), so half-typed searches are never saved.
--
-- Top part: the player's own spells (spellbook + the class auras from the spell data).
-- Below the line: every other player class aura and NPC/boss aura, once at least
-- MIN_QUERY_LENGTH characters are typed.
--
-- The aura list ships with the addon in SpellData/Data/<Flavor>.lua (generated from the game's
-- database, see SpellData/Tools) as one raw string. It is parsed once, the first time a spell input
-- gets focus, after which the string is released. Only VISIBLE_ROWS buttons exist; scrolling reuses them.
DivineWindow.SpellSearch = {}
local Search = DivineWindow.SpellSearch

local VISIBLE_ROWS = 14
local ROW_HEIGHT = 18
local POPUP_WIDTH = 340
local MIN_QUERY_LENGTH = 2
local MAX_RESULTS = 300
local FILTER_DELAY = 0.1

local ITEM_SPELL, ITEM_MANUAL, ITEM_SEPARATOR, ITEM_HINT = 1, 2, 3, 4

-- Midnight (12.0+) hides most auras of others in combat; those entries get a "*".
local hasSecretAuras = issecretvalue ~= nil

local getSpellTexture = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture

-- Icon of a spell. The spell data holds retail spell IDs; other versions (e.g. WoW Forever) have their
-- own spell database where those IDs may not exist, so fall back to the spellbook icon and the name.
local function spellIcon(id, name, knownIcon)
    if (knownIcon) then
        return knownIcon;
    end

    local texture = id and getSpellTexture and getSpellTexture(id);
    if (texture) then
        return texture;
    end

    if (name and getSpellTexture) then
        texture = getSpellTexture(name);
        if (texture) then
            return texture;
        end
    end

    if (name and C_Spell and C_Spell.GetSpellInfo) then
        local info = C_Spell.GetSpellInfo(name);
        if (info and info.iconID) then
            return info.iconID;
        end
    elseif (name and GetSpellInfo) then
        local _, _, icon = GetSpellInfo(name);
        return icon;
    end

    return nil;
end

-- Parsed spell data, parallel arrays (no table per spell): name, lowercase name, id, class token, rank.
local data = { count = 0, names = {}, lowers = {}, ids = {}, classes = {}, ranks = {}, icons = {}, loaded = false }

-- Search state of the open popup.
local popup
local state = {
    editBox = nil, -- the input the popup belongs to
    onSelect = nil, -- function(name, spellId)
    savedText = "", -- restored when the popup closes without a pick
    items = {},     -- rendered rows
    offset = 0,     -- index of the first visible item - 1
    highlight = nil, -- item index selected by the arrow keys
    filterToken = 0,
    filterPending = false,
    -- narrowing cache: matches of the last query, reused when the user keeps typing
    lastQuery = nil,
    lastMatches = nil,
}

-- The player's own spells: list of { name, lower, id, rank } built on every open (spellbook may change).
local own = { list = {}, byName = {} }

local function locale()
    return DivineWindow.Locales[DivineWindow.language].SpellSearch;
end

local function playerClass()
    return select(2, UnitClass("player"));
end

local function rankNumber(rank)
    return rank and tonumber(string.match(rank, "(%d+)")) or 0;
end

local function classLabel(classToken)
    if (not classToken) then
        return "|cff808080(" .. locale().npc .. ")|r";
    end

    local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken]) or classToken;
    local color = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classToken))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]);
    if (not color) then
        return "(" .. className .. ")";
    end

    return string.format("|cff%02x%02x%02x(%s)|r", color.r * 255, color.g * 255, color.b * 255, className);
end

-- Data ------------------------------------------------------------------------------------------

local function loadData()
    if (data.loaded) then
        return data.count > 0;
    end
    data.loaded = true;

    local source = DivineWindow_SpellData and DivineWindow_SpellData.spells;
    if (type(source) ~= "string") then
        return false;
    end

    local names, lowers, ids, classes, ranks, icons = data.names, data.lowers, data.ids, data.classes, data.ranks,
        data.icons;
    local n = 0;
    -- name, spell ID, class token, rank, icon file ID (the icon comes from the game's database, as some
    -- versions, e.g. WoW Forever, only return icons for spells the player can use)
    for name, id, classToken, rank, icon in
    string.gmatch(source, "([^\t\n]+)\t(%d+)\t([^\t\n]*)\t([^\t\n]*)\t?(%d*)") do
        n = n + 1;
        names[n] = name;
        lowers[n] = string.lower(name);
        ids[n] = tonumber(id);
        classes[n] = classToken ~= "" and classToken or false;
        ranks[n] = rank ~= "" and rank or false;
        icons[n] = tonumber(icon) or false;
    end
    data.count = n;

    -- The raw string is no longer needed; let it be collected.
    DivineWindow_SpellData.spells = nil;
    return n > 0;
end

local function addOwnSpell(name, id, rank, icon)
    if (not name or name == "") then
        return;
    end

    local existing = own.byName[name];
    if (existing) then
        if (rankNumber(rank) > rankNumber(existing.rank)) then
            existing.id, existing.rank = id, rank;
        end
        existing.icon = existing.icon or icon;
        return;
    end

    local entry = { name = name, lower = string.lower(name), id = id, rank = rank, icon = icon };
    own.byName[name] = entry;
    table.insert(own.list, entry);
end

local function eachSpellbookSpell(callback)
    if (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then
        local bank = Enum.SpellBookSpellBank.Player;
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(line);
            if (info and not info.shouldHide) then
                for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local item = C_SpellBook.GetSpellBookItemInfo(i, bank);
                    if (item and item.spellID and not item.isPassive
                            and item.itemType == Enum.SpellBookItemType.Spell) then
                        callback(item.name, item.spellID, item.subName, item.iconID);
                    end
                end
            end
        end
    elseif (GetNumSpellTabs) then
        local book = BOOKTYPE_SPELL or "spell";
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, numSpells = GetSpellTabInfo(tab);
            for i = offset + 1, offset + numSpells do
                local name, subName = GetSpellBookItemName(i, book);
                local itemType, spellId = GetSpellBookItemInfo(i, book);
                if (name and itemType == "SPELL" and spellId and not (IsPassiveSpell and IsPassiveSpell(i, book))) then
                    callback(name, spellId, subName, GetSpellBookItemTexture and GetSpellBookItemTexture(i, book));
                end
            end
        end
    end
end

local function buildOwnSpells()
    own.list, own.byName = {}, {};

    eachSpellbookSpell(function(name, id, subName, icon)
        local rank = subName and string.find(subName, "%d") and subName or nil;
        addOwnSpell(name, id, rank, icon);
    end);

    local classToken = playerClass();
    for i = 1, data.count do
        if (data.classes[i] == classToken) then
            addOwnSpell(data.names[i], data.ids[i], data.ranks[i] or nil, data.icons[i] or nil);
        end
    end

    table.sort(own.list, function(a, b) return a.lower < b.lower end);
end

-- Searching -------------------------------------------------------------------------------------

-- Indices into data whose name contains the query; reuses the previous result while the user keeps typing.
local function findOtherSpells(query)
    local candidates = nil;
    if (state.lastQuery and string.find(query, state.lastQuery, 1, true) == 1) then
        candidates = state.lastMatches;
    end

    local lowers, matches = data.lowers, {};
    if (candidates) then
        for _, i in ipairs(candidates) do
            if (string.find(lowers[i], query, 1, true)) then
                matches[#matches + 1] = i;
            end
        end
    else
        for i = 1, data.count do
            if (string.find(lowers[i], query, 1, true)) then
                matches[#matches + 1] = i;
            end
        end
    end

    state.lastQuery, state.lastMatches = query, matches;
    return matches;
end

local function buildItems(text)
    local L = locale();
    local query = string.lower(strtrim(text or ""));
    local items = {};
    local exactMatch = false;
    local manualIndex;

    if (query ~= "") then
        table.insert(items, { kind = ITEM_MANUAL, text = strtrim(text) });
        manualIndex = #items;
    end

    -- own spells: everything when nothing is typed, prefix matches first
    local ownCount = 0;
    for pass = 1, (query == "" and 1 or 2) do
        for _, entry in ipairs(own.list) do
            local position = query == "" and 1 or string.find(entry.lower, query, 1, true);
            if (position and (query == "" or (pass == 1) == (position == 1))) then
                table.insert(items, { kind = ITEM_SPELL, name = entry.name, id = entry.id, rank = entry.rank, icon = entry.icon, own = true });
                ownCount = ownCount + 1;
                exactMatch = exactMatch or entry.lower == query;
            end
        end
    end

    if (ownCount == 0 and query == "") then
        table.insert(items, { kind = ITEM_HINT, text = L.noOwnSpells });
    end

    table.insert(items, { kind = ITEM_SEPARATOR });

    if (string.len(query) < MIN_QUERY_LENGTH) then
        table.insert(items, { kind = ITEM_HINT, text = data.count > 0 and L.startTyping or L.noSpellData });
    elseif (data.count == 0) then
        table.insert(items, { kind = ITEM_HINT, text = L.noSpellData });
    else
        local matches = findOtherSpells(query);
        local shown, total = 0, 0;

        -- prefix matches first, then the rest; data is sorted by name, so each group is alphabetical
        for pass = 1, 2 do
            for _, i in ipairs(matches) do
                local isPrefix = string.find(data.lowers[i], query, 1, true) == 1;
                if (isPrefix == (pass == 1) and not own.byName[data.names[i]]) then
                    total = total + 1;
                    exactMatch = exactMatch or data.lowers[i] == query;
                    if (shown < MAX_RESULTS) then
                        shown = shown + 1;
                        table.insert(items, {
                            kind = ITEM_SPELL,
                            name = data.names[i],
                            id = data.ids[i],
                            rank = data.ranks[i] or nil,
                            class = data.classes[i] or nil,
                            icon = data.icons[i] or nil,
                            secret = hasSecretAuras,
                        });
                    end
                end
            end
        end

        if (total == 0) then
            table.insert(items, { kind = ITEM_HINT, text = L.noResults });
        elseif (total > shown) then
            table.insert(items, { kind = ITEM_HINT, text = string.format(L.moreResults, total - shown) });
        end
    end

    -- typing an exact spell name needs no "use as typed" row
    if (manualIndex and exactMatch) then
        table.remove(items, manualIndex);
    end

    return items;
end

local function isSelectable(item)
    return item ~= nil and (item.kind == ITEM_SPELL or item.kind == ITEM_MANUAL);
end

local function firstSpellItem(items)
    for index, item in ipairs(items) do
        if (item.kind == ITEM_SPELL) then
            return index;
        end
    end
    return nil;
end

-- Popup -----------------------------------------------------------------------------------------

local function renderRow(row, item, index)
    local L = locale();
    row.item = item;
    row.icon:Hide();
    row.line:Hide();
    row.text:SetText("");
    row.text:SetTextColor(1, 1, 1);
    row:EnableMouse(isSelectable(item));

    if (index == state.highlight) then
        row.selected:Show();
    else
        row.selected:Hide();
    end

    if (item.kind == ITEM_SEPARATOR) then
        row.line:Show();
    elseif (item.kind == ITEM_HINT) then
        row.text:SetText(item.text);
        row.text:SetTextColor(0.6, 0.6, 0.6);
    elseif (item.kind == ITEM_MANUAL) then
        row.text:SetText(string.format(L.useAsTyped, item.text));
        row.text:SetTextColor(0.5, 1, 0.5);
    else
        local label = item.name;
        if (item.rank) then
            label = label .. " |cffa0a0a0(" .. item.rank .. ")|r";
        end
        if (not item.own) then
            label = label .. " " .. classLabel(item.class);
        end
        if (item.secret) then
            label = label .. " |cffffd100*|r";
        end
        row.text:SetText(label);

        -- looked up once per item; rows are re-rendered while scrolling
        if (item.iconTexture == nil) then
            item.iconTexture = spellIcon(item.id, item.name, item.icon) or false;
        end

        local texture = item.iconTexture;
        if (texture) then
            row.icon:SetTexture(texture);
            row.icon:Show();
        end
    end
end

local function refresh()
    local items = state.items;
    local maxOffset = math.max(0, #items - VISIBLE_ROWS);
    state.offset = math.min(math.max(0, state.offset), maxOffset);

    for r = 1, VISIBLE_ROWS do
        local row = popup.rows[r];
        local index = state.offset + r;
        local item = items[index];
        if (item) then
            renderRow(row, item, index);
            row:Show();
        else
            row:Hide();
        end
    end

    local visible = math.min(#items, VISIBLE_ROWS);
    popup:SetHeight(visible * ROW_HEIGHT + 12 + (popup.note:IsShown() and 16 or 0));

    if (maxOffset > 0) then
        local trackHeight = visible * ROW_HEIGHT;
        local thumbHeight = math.max(12, trackHeight * VISIBLE_ROWS / #items);
        popup.thumb:SetHeight(thumbHeight);
        popup.thumb:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -3, -6 - (trackHeight - thumbHeight) * state.offset / maxOffset);
        popup.thumb:Show();
    else
        popup.thumb:Hide();
    end
end

-- autoHighlight: preselect the best match, so Enter picks it (not for the unfiltered list).
local function setItems(items, autoHighlight)
    state.items = items;
    state.offset = 0;
    state.highlight = autoHighlight and firstSpellItem(items) or nil;
    state.filterPending = false;

    local anySecret = false;
    for _, item in ipairs(items) do
        if (item.secret) then
            anySecret = true;
            break;
        end
    end
    if (anySecret) then
        popup.note:Show();
    else
        popup.note:Hide();
    end

    refresh();
end

local function ensureVisible(index)
    if (index <= state.offset) then
        state.offset = index - 1;
    elseif (index > state.offset + VISIBLE_ROWS) then
        state.offset = index - VISIBLE_ROWS;
    end
end

local function moveHighlight(step)
    local items = state.items;
    local index = state.highlight or (step > 0 and 0 or #items + 1);

    repeat
        index = index + step;
    until (index < 1 or index > #items or isSelectable(items[index]));

    if (items[index]) then
        state.highlight = index;
        ensureVisible(index);
        refresh();
    end
end

local function close()
    state.filterToken = state.filterToken + 1;
    if (popup) then
        popup:Hide();
    end
    state.editBox, state.onSelect = nil, nil;
end

local function choose(item)
    local editBox, onSelect = state.editBox, state.onSelect;
    if (not (editBox and isSelectable(item))) then
        return;
    end

    local name = item.kind == ITEM_MANUAL and item.text or item.name;
    local spellId = item.kind == ITEM_SPELL and item.id or nil;

    state.savedText = name;
    editBox:SetText(name);
    close();
    editBox:ClearFocus();

    if (onSelect) then
        onSelect(name, spellId);
    end
end

local function createPopup()
    local parent = _G["DivineWindow_ConfigurationScreen"] or UIParent;
    local frame = CreateFrame("Frame", "DivineWindow_SpellSearchPopup", parent,
        BackdropTemplateMixin and "BackdropTemplate" or nil);
    frame:SetFrameStrata("FULLSCREEN_DIALOG");
    frame:SetWidth(POPUP_WIDTH);
    frame:SetClampedToScreen(true);
    frame:EnableMouse(true);
    frame:EnableMouseWheel(true);
    if (frame.SetBackdrop) then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        });
        frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95);
    end

    frame.rows = {};
    for r = 1, VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, frame);
        row:SetHeight(ROW_HEIGHT);
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6 - (r - 1) * ROW_HEIGHT);
        row:SetPoint("RIGHT", frame, "RIGHT", -10, 0);
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD");

        row.selected = row:CreateTexture(nil, "BACKGROUND");
        row.selected:SetAllPoints();
        row.selected:SetColorTexture(1, 0.82, 0, 0.18);

        row.icon = row:CreateTexture(nil, "ARTWORK");
        row.icon:SetSize(ROW_HEIGHT - 2, ROW_HEIGHT - 2);
        row.icon:SetPoint("LEFT", row, "LEFT", 2, 0);

        row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
        row.text:SetPoint("LEFT", row, "LEFT", ROW_HEIGHT + 4, 0);
        row.text:SetPoint("RIGHT", row, "RIGHT", -2, 0);
        row.text:SetJustifyH("LEFT");
        row.text:SetWordWrap(false);

        row.line = row:CreateTexture(nil, "ARTWORK");
        row.line:SetHeight(1);
        row.line:SetPoint("LEFT", row, "LEFT", 4, 0);
        row.line:SetPoint("RIGHT", row, "RIGHT", -4, 0);
        row.line:SetColorTexture(0.6, 0.6, 0.6, 0.6);

        row:SetScript("OnClick", function(self) choose(self.item) end);
        frame.rows[r] = row;
    end

    frame.thumb = frame:CreateTexture(nil, "OVERLAY");
    frame.thumb:SetWidth(3);
    frame.thumb:SetColorTexture(0.8, 0.8, 0.8, 0.5);

    frame.note = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall");
    frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 6);
    frame.note:SetPoint("RIGHT", frame, "RIGHT", -8, 0);
    frame.note:SetJustifyH("LEFT");
    frame.note:SetText(locale().secretNote);
    frame.note:Hide();

    frame:SetScript("OnMouseWheel", function(_, delta)
        state.offset = state.offset - delta * 3;
        refresh();
    end);
    frame:SetScript("OnHide", function()
        if (state.editBox) then
            state.editBox:SetText(state.savedText);
            state.editBox:ClearFocus();
        end
        state.editBox, state.onSelect = nil, nil;
    end);
    frame:Hide();

    return frame;
end

local function open(editBox, savedText, onSelect)
    popup = popup or createPopup();
    loadData();
    buildOwnSpells();

    state.editBox, state.onSelect = editBox, onSelect;
    state.savedText = savedText or "";
    state.lastQuery, state.lastMatches = nil, nil;

    popup:ClearAllPoints();
    local spaceBelow = editBox:GetBottom() or 0;
    if (spaceBelow * editBox:GetEffectiveScale() / popup:GetEffectiveScale() < (VISIBLE_ROWS * ROW_HEIGHT + 30)) then
        popup:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", -6, 2);
    else
        popup:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", -6, -2);
    end

    popup:Show();
    -- start from the full list, even when the input shows the currently saved spell
    setItems(buildItems(""), false);
end

local function scheduleFilter(text)
    state.filterToken = state.filterToken + 1;
    state.filterPending = true;
    local token = state.filterToken;
    C_Timer.After(FILTER_DELAY, function()
        if (token == state.filterToken and state.editBox) then
            setItems(buildItems(text), strtrim(text) ~= "");
        end
    end);
end

-- Public ----------------------------------------------------------------------------------------

-- Turns an InputBoxTemplate edit box into a spell picker.
-- getSaved() returns the saved name; onSelect(name, spellId) is called after a pick.
function Search.attach(editBox, getSaved, onSelect)
    if (editBox.SetAltArrowKeyMode) then
        editBox:SetAltArrowKeyMode(false);
    end

    editBox:SetScript("OnEditFocusGained", function(self)
        open(self, getSaved(), onSelect);
        self:HighlightText();
    end);

    editBox:SetScript("OnTextChanged", function(self, userInput)
        if (userInput and state.editBox == self) then
            scheduleFilter(self:GetText());
        end
    end);

    editBox:SetScript("OnArrowPressed", function(self, key)
        if (state.editBox ~= self) then
            return;
        end
        if (key == "DOWN") then
            moveHighlight(1);
        elseif (key == "UP") then
            moveHighlight(-1);
        end
    end);

    editBox:SetScript("OnEnterPressed", function(self)
        if (state.editBox ~= self) then
            self:ClearFocus();
            return;
        end
        local text = self:GetText() or "";

        -- emptied input + Enter clears the spell
        if (strtrim(text) == "") then
            choose({ kind = ITEM_MANUAL, text = "" });
            return;
        end

        -- apply a pending filter first, so Enter picks from what was actually typed
        if (state.filterPending) then
            setItems(buildItems(text), true);
        end
        local item = state.items[state.highlight or 0];
        if (item) then
            choose(item);
        end
    end);

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus();
    end);

    editBox:SetScript("OnEditFocusLost", function(self)
        if (state.editBox ~= self) then
            return;
        end
        -- a click on a popup row may take focus away first; let the click do the pick,
        -- but don't leave the popup open when the mouse was released somewhere else
        if (popup and popup:IsMouseOver()) then
            C_Timer.After(0.5, function()
                if (state.editBox == self and not self:HasFocus()) then
                    close();
                    self:SetText(getSaved() or "");
                end
            end);
            return;
        end
        close();
        self:SetText(getSaved() or "");
    end);
end

DivineWindow.Utilities.debugPrint("Src/ConfigurationScreen/SpellSearch.lua", "file")
