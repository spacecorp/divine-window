-- x positions of the last two columns of a spell row
local INVERT_COLUMN_X = 650;
local DELETE_COLUMN_X = 710;

local function rearrangeEditRows(specialisation, parentFrame)
    local windowSpellConfiguration = DivineWindow.Utilities.getWindowConfiguration(specialisation);
    local hiddenItems = 0;

    if (windowSpellConfiguration and windowSpellConfiguration.isSetUp) then
        for index, spellConfiguration in ipairs(windowSpellConfiguration.spells) do
            local newIndex = index - hiddenItems;
            local deleted = spellConfiguration.deleted;

            local spellBox = _G[
            DivineWindow.ConfigurationScreen.FrameNames.SPELL_SPELL_NAME_DROPDOWN_NAME ..
            specialisation .. "_" .. index];
            local countTypeBox = _G[
            DivineWindow.ConfigurationScreen.FrameNames.SPELL_COUNTDOWN_TYPE_DROPDOWN_NAME ..
            specialisation .. "_" .. index];
            local windowPartBox = _G[DivineWindow.ConfigurationScreen.FrameNames.SPELL_WINDOW_PART_DROPDOWN_NAME ..
            specialisation .. "_" .. index];
            local deleteRowButton = _G[
            DivineWindow.ConfigurationScreen.FrameNames.SPELL_DELETE_ROW .. specialisation .. '_' .. index]
            local previewButton = _G
                [DivineWindow.ConfigurationScreen.FrameNames.SPELL_PREVIEW_BUTTON_NAME .. specialisation .. '_' .. index];
            local invertCheckbox = _G
                [DivineWindow.ConfigurationScreen.FrameNames.SPELL_INVERT_CHECKBOX_NAME .. specialisation .. '_' .. index];

            -- if row is deleted; then just hide them for now, as we cannot remove interface items
            if (deleted) then
                hiddenItems = hiddenItems + 1;
                if (previewButton) then previewButton:Hide(); end
                if (spellBox) then spellBox:Hide(); end
                if (countTypeBox) then countTypeBox:Hide(); end
                if (windowPartBox) then windowPartBox:Hide(); end
                if (deleteRowButton) then deleteRowButton:Hide(); end
                if (invertCheckbox) then invertCheckbox:Hide(); end
            else
                previewButton:SetPoint("TOPLEFT", parentFrame, "TOP", 15, (-40 * newIndex) + 36);
                spellBox:SetPoint("TOPLEFT", parentFrame, "TOP", 60, (-40 * newIndex) + 36);
                countTypeBox:SetPoint("TOPLEFT", parentFrame, "TOP", 260, (-40 * newIndex) + 40);
                windowPartBox:SetPoint("TOPLEFT", parentFrame, "TOP", 445, (-40 * newIndex) + 40);
                if (invertCheckbox) then
                    invertCheckbox:SetPoint("TOPLEFT", parentFrame, "TOP", INVERT_COLUMN_X, (-40 * newIndex) + 38);
                end
                deleteRowButton:SetPoint("TOPLEFT", parentFrame, "TOP", DELETE_COLUMN_X, (-40 * newIndex) + 36);
            end
        end
    end
end

local function addEditBox(parentFrame, name, text, specialisation, saveIndex)
    local editBox = CreateFrame("EditBox", name, parentFrame, "InputBoxTemplate")
    editBox:SetWidth(200)
    editBox:SetHeight(20)
    editBox:SetAutoFocus(false)
    editBox:SetText(text)
    editBox:SetMaxLetters(100)
    editBox:SetMultiLine(false)
    editBox:Show()

    -- Typing only searches; the spell is saved when one is picked from the list.
    DivineWindow.SpellSearch.attach(editBox,
        function()
            return DivineWindowLocalVars.specialisation[specialisation].spells[saveIndex].name or "";
        end,
        function(spellName, spellId)
            local spell = DivineWindowLocalVars.specialisation[specialisation].spells[saveIndex];
            spell.name = spellName;
            spell.spellId = spellId;
        end)
    return editBox
end

local function windowPartMenuInfo_OnClick(specialisation)
    return function(self, parent, saveIndex)
        DivineWindowLocalVars.specialisation[specialisation].spells[saveIndex].windowPart =
            self.value;
        UIDropDownMenu_SetSelectedValue(parent, self.value);
    end
end


local function countTypeMenuInfo_OnClick(specialisation)
    return function(self, parent, saveIndex)
        DivineWindowLocalVars.specialisation[specialisation].spells[saveIndex].countType =
            self.value;
        UIDropDownMenu_SetSelectedValue(parent, self.value);
    end
end

local function powerBarMenuInfo_OnClick(specialisation)
    return function(self, parent, side)
        DivineWindowLocalVars.specialisation[specialisation].powerBar[side] =
            self
            .value;
        UIDropDownMenu_SetSelectedValue(parent, self.value);
    end
end

local function powerBarColorMenuInfo_OnClick(specialisation)
    return function(self, parent, side)
        DivineWindowLocalVars.specialisation[specialisation].powerBarColor[side] =
            self
            .value;
        UIDropDownMenu_SetSelectedValue(parent, self.value);
    end
end



local function powerBarMenuInfo(side, specialisation, initialValue)
    local playerClass = select(2, UnitClass("player"));
    return function(self)
        local info = UIDropDownMenu_CreateInfo()

        info.arg2 = side;
        info.tooltipTitle = DivineWindow.Locales[DivineWindow.language].PowerTypeTitle[side];

        info.text, info.menuList, info.isTitle =
            DivineWindow.Locales[DivineWindow.language].PowerTypeTitle[side],
            "POWER_BAR_" .. side, true;

        UIDropDownMenu_AddButton(info);

        for _, supportedPowerType in pairs(DivineWindow.Support.PowerType[playerClass]) do
            info                      = {}
            info.arg1                 = self;
            info.arg2                 = side;
            info.func                 = powerBarMenuInfo_OnClick(specialisation);
            local powerBarTranslation = DivineWindow.Locales[DivineWindow.language].PowerType[supportedPowerType]
            info.value, info.text     = supportedPowerType, powerBarTranslation or nil;
            UIDropDownMenu_AddButton(info);
        end
    end
end


local function powerBarColorMenuInfo(side, specialisation, initialValue)
    local playerClass = select(2, UnitClass("player"));
    return function(self)
        local info = UIDropDownMenu_CreateInfo()

        info.arg2 = side;
        info.tooltipTitle = DivineWindow.Locales[DivineWindow.language].PowerTypeColorTitle[side];

        info.text, info.menuList, info.isTitle =
            DivineWindow.Locales[DivineWindow.language].PowerTypeColorTitle[side],
            "POWER_BAR_" .. side, true;

        UIDropDownMenu_AddButton(info);

        for _, supportedPowerTypeColor in pairs(DivineWindow.Constants.PowerTypeColors) do
            info                           = {}
            info.arg1                      = self;
            info.arg2                      = side;
            info.func                      = powerBarColorMenuInfo_OnClick(specialisation);
            local powerBarColorTranslation = DivineWindow.Locales[DivineWindow.language].PowerTypeColor
                [supportedPowerTypeColor]
            info.value, info.text          = supportedPowerTypeColor, powerBarColorTranslation or nil;
            UIDropDownMenu_AddButton(info);
        end
    end
end

local function countTypeMenuInfo(saveToIndex, specialisation)
    return function(self)
        local info = UIDropDownMenu_CreateInfo()
        info.arg2 = saveToIndex;
        info.tooltipTitle = DivineWindow.Locales[DivineWindow.language].CountTypeTitle.tooltipTitle;

        info.text, info.menuList, info.isTitle = DivineWindow.Locales[DivineWindow.language].CountTypeTitle.tooltipTitle,
            "COUNT_TYPE_" .. saveToIndex, true;

        UIDropDownMenu_AddButton(info);

        for _, countType in pairs(DivineWindow.Constants.CountType) do
            info                       = {}
            info.arg1                  = self;
            info.arg2                  = saveToIndex;
            info.func                  = countTypeMenuInfo_OnClick(specialisation);
            local countTypeTranslation = DivineWindow.Locales[DivineWindow.language].CountType[countType]

            info.value, info.text      = countType, countTypeTranslation or nil;
            UIDropDownMenu_AddButton(info);
        end
    end
end

local function windowPartMenuInfo(saveToIndex, specialisation, chosenWindow)
    return function(self)
        -- prevent errors when there is no window selected
        if (DivineWindow.Utilities.tableIsEmpty(DivineWindow.ConfigurationScreen.AvailableWindows)) then
            return;
        end

        -- Read the window that is selected right now: the one passed in was captured when the
        -- row was created and goes stale once a (different) window is picked afterwards.
        local savedConfiguration = DivineWindowLocalVars.specialisation and
            DivineWindowLocalVars.specialisation[specialisation];
        local currentWindow = (savedConfiguration and savedConfiguration.chosenWindow) or chosenWindow or {};

        local info = UIDropDownMenu_CreateInfo()
        wipe(info);
        info.arg2 = saveToIndex;
        info.tooltipTitle = DivineWindow.Locales[DivineWindow.language].WindowDetailTitle.tooltipTitle;

        info.text, info.menuList, info.isTitle =
            DivineWindow.Locales[DivineWindow.language].WindowDetailTitle.tooltipTitle,
            "WINDOW_PART" .. saveToIndex, true;

        UIDropDownMenu_AddButton(info);

        -- look over all constanst in DivineWindow.Constants.WindowParts
        for _, windowPart in pairs(DivineWindow.Constants.WindowPart) do
            info              = {}
            info.arg1         = self;
            info.arg2         = saveToIndex;
            info.func         = windowPartMenuInfo_OnClick(specialisation);

            local category    = currentWindow[1];
            local window      = currentWindow[2];

            -- The window's addon may be missing or disabled while saved settings still point to it.
            local categoryLocales = DivineWindow.Locales[DivineWindow.language][category];
            local windowLocales = categoryLocales and categoryLocales[window];
            local translation = windowLocales and windowLocales.WindowPart and
                windowLocales.WindowPart[windowPart];

            if (translation == nil) then
                info.disabled = true;
            end

            local windowPartTranslation = translation or
                DivineWindow.Locales[DivineWindow.language].WindowDetailTitle.unavailable;

            info.value, info.text       = windowPart, windowPartTranslation or nil;
            UIDropDownMenu_AddButton(info);
        end
    end
end

local function createCountTypeDropDownBox(dropdownName, parentFrame, saveIndex, specialisation, initialValue)
    local dropDown = CreateFrame("Frame", dropdownName, parentFrame, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropDown, 150) -- Use in place of dropDown:SetWidth
    UIDropDownMenu_Initialize(dropDown, countTypeMenuInfo(saveIndex, specialisation))
    UIDropDownMenu_SetSelectedValue(dropDown, initialValue);
    UIDropDownMenu_JustifyText(dropDown, "LEFT")

    return dropDown;
end


local function createWindowPartDropDownBox(dropdownName, parentFrame, saveIndex, specialisation, initialValue,
                                           chosenWindow)
    local dropDown = CreateFrame("Frame", dropdownName, parentFrame, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropDown, 150) -- Use in place of dropDown:SetWidth
    UIDropDownMenu_Initialize(dropDown, windowPartMenuInfo(saveIndex, specialisation, chosenWindow))
    UIDropDownMenu_SetSelectedValue(dropDown, initialValue);
    UIDropDownMenu_JustifyText(dropDown, "LEFT")
    return dropDown;
end

local function createPowerBarDropDownBox(dropdownName, parentFrame, side, specialisation, initialValue)
    local dropDown = CreateFrame("Frame", dropdownName, parentFrame, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropDown, 150) -- Use in place of dropDown:SetWidth
    UIDropDownMenu_Initialize(dropDown, powerBarMenuInfo(side, specialisation, initialValue))
    UIDropDownMenu_SetSelectedValue(dropDown, initialValue);
    UIDropDownMenu_JustifyText(dropDown, "LEFT")
    return dropDown;
end

local function createPowerBarColorDropDownBox(dropdownName, parentFrame, side, specialisation, initialValue)
    local dropDown = CreateFrame("Frame", dropdownName, parentFrame, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropDown, 150) -- Use in place of dropDown:SetWidth
    UIDropDownMenu_Initialize(dropDown, powerBarColorMenuInfo(side, specialisation, initialValue))
    UIDropDownMenu_SetSelectedValue(dropDown, initialValue);
    UIDropDownMenu_JustifyText(dropDown, "LEFT")
    return dropDown;
end


local function resizeScrollFrame(items, specialisation, frameToSize)
    local frame = frameToSize or
        _G
        [DivineWindow.ConfigurationScreen.FrameNames.SPECIALISATION_SCREEN_SCROLL_NAME .. tostring(DivineWindow.ConfigurationScreen.activeTab)];

    -- set new scroll frame height
    frame:SetHeight(30 * items);
end

local function deleteRow(index, specialisation)
    DivineWindowLocalVars.specialisation[specialisation].spells[index].deleted = true;
    _G[DivineWindow.ConfigurationScreen.FrameNames.SPELL_PREVIEW_BUTTON_NAME .. specialisation .. "_" .. index]
        :SetHeight(0);
    _G[DivineWindow.ConfigurationScreen.FrameNames.SPELL_SPELL_NAME_DROPDOWN_NAME .. specialisation .. "_" .. index]
        :SetHeight(0);
    _G[DivineWindow.ConfigurationScreen.FrameNames.SPELL_COUNTDOWN_TYPE_DROPDOWN_NAME .. specialisation .. "_" .. index]
        :SetHeight(0);
    _G[DivineWindow.ConfigurationScreen.FrameNames.SPELL_WINDOW_PART_DROPDOWN_NAME .. specialisation .. "_" .. index]
        :SetHeight(0);
    _G[DivineWindow.ConfigurationScreen.FrameNames.SPELL_DELETE_ROW .. specialisation .. '_' .. index]:SetHeight(0);
    local invertCheckbox = _G[DivineWindow.ConfigurationScreen.FrameNames.SPELL_INVERT_CHECKBOX_NAME ..
        specialisation .. '_' .. index];
    if (invertCheckbox) then invertCheckbox:Hide(); end

    local windowSpellConfiguration = DivineWindow.Utilities.getWindowConfiguration(specialisation);
    resizeScrollFrame(#windowSpellConfiguration.spells, specialisation);
end

local PREVIEW_DURATION = 5; -- seconds

local function createPreviewButton(buttonName, parentFrame, index, specialisation)
    local previewButton = CreateFrame("Button", buttonName, parentFrame, "UIPanelButtonTemplate")
    previewButton:SetText("");
    previewButton:Show();
    previewButton:SetNormalTexture(3004126);
    previewButton:SetSize(20, 20)

    previewButton:SetScript("OnClick", function()
        local spell = DivineWindowLocalVars.specialisation[specialisation].spells[index]
        if (not (spell and spell.countType and spell.windowPart)) then
            return;
        end

        -- The interface update loop draws the preview (see DivineWindow.Interface.onUpdate), so it
        -- is not wiped and redrawn by that loop in between, which made it flicker.
        DivineWindow.Interface.startPreview(specialisation, spell.countType, spell.windowPart, PREVIEW_DURATION,
            spell.inverted);
    end)

    return previewButton;
end

-- Inverts the part: full while the timer/aura is off, emptying instead of filling up.
local function createInvertCheckbox(checkboxName, parentFrame, index, specialisation)
    local labels = DivineWindow.Locales[DivineWindow.language].Labels;
    local checkbox = CreateFrame("CheckButton", checkboxName, parentFrame, "UICheckButtonTemplate")
    checkbox:SetSize(24, 24);

    local spell = DivineWindowLocalVars.specialisation[specialisation].spells[index];
    checkbox:SetChecked(spell and spell.inverted == true);
    checkbox:Show();

    checkbox:SetScript("OnClick", function(self)
        local spellToChange = DivineWindowLocalVars.specialisation[specialisation].spells[index];
        if (spellToChange) then
            spellToChange.inverted = self:GetChecked() and true or nil;
        end
    end)
    checkbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
        GameTooltip:SetText(labels.invert, 1, 1, 1);
        GameTooltip:AddLine(labels.invertTooltip, nil, nil, nil, true);
        GameTooltip:Show();
    end)
    checkbox:SetScript("OnLeave", function() GameTooltip:Hide(); end)

    return checkbox;
end

local function createDeleteButton(buttonName, parentFrame, index, specialisation)
    local deleteButton = CreateFrame("Button", buttonName, parentFrame, "UIPanelButtonTemplate")
    deleteButton:SetText("X");
    deleteButton:SetWidth(20)
    deleteButton:Show();
    deleteButton:SetScript("OnClick", function()
        deleteRow(index, specialisation)
        rearrangeEditRows(specialisation, parentFrame);
    end)

    return deleteButton;
end

local function createText(textString, parentFrame)
    local text = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetText(textString)
    text:SetWidth(200)
    text:SetHeight(20)
    text:Show()
    return text
end

local function addRow(self, specialisation, parentFrame, chosenWindow)
    local windowSpellConfiguration = DivineWindow.Utilities.getWindowConfiguration(specialisation); -- always request latest ones, not in memory
    if (windowSpellConfiguration and windowSpellConfiguration.isSetUp) then
        local numOfSpellsSaved = #windowSpellConfiguration.spells;
        local newId = numOfSpellsSaved + 1;

        -- insert empty data set
        table.insert(DivineWindowLocalVars.specialisation[specialisation].spells, {
            name = "",
            countType = nil,
            windowPart = nil
        });

        local previewButton = createPreviewButton(
            DivineWindow.ConfigurationScreen.FrameNames.SPELL_PREVIEW_BUTTON_NAME ..
            specialisation .. '_' .. newId,
            parentFrame,
            newId,
            specialisation);

        local spellBox = addEditBox(parentFrame,
            DivineWindow.ConfigurationScreen.FrameNames.SPELL_SPELL_NAME_DROPDOWN_NAME .. specialisation .. "_" .. newId,
            "",
            specialisation,
            newId);
        local countTypeBox = createCountTypeDropDownBox(
            DivineWindow.ConfigurationScreen.FrameNames.SPELL_COUNTDOWN_TYPE_DROPDOWN_NAME ..
            specialisation .. "_" .. newId,
            parentFrame, newId, specialisation);
        local windowPartBox = createWindowPartDropDownBox(
            DivineWindow.ConfigurationScreen.FrameNames.SPELL_WINDOW_PART_DROPDOWN_NAME .. specialisation .. "_" .. newId,
            parentFrame, newId, specialisation, nil, chosenWindow);

        local deleteRowButton = createDeleteButton(
            DivineWindow.ConfigurationScreen.FrameNames.SPELL_DELETE_ROW .. specialisation .. '_' .. newId,
            parentFrame, newId,
            specialisation);
        local invertCheckbox = createInvertCheckbox(
            DivineWindow.ConfigurationScreen.FrameNames.SPELL_INVERT_CHECKBOX_NAME .. specialisation .. '_' .. newId,
            parentFrame, newId, specialisation);

        previewButton:SetPoint("TOPLEFT", parentFrame, "TOP", 15, (-40 * newId) + 36);
        spellBox:SetPoint("TOPLEFT", parentFrame, "TOP", 60, -40 * newId);
        countTypeBox:SetPoint("TOPLEFT", parentFrame, "TOP", 260, (-40 * newId) + 4);
        windowPartBox:SetPoint("TOPLEFT", parentFrame, "TOP", 445, (-40 * newId) + 4);
        invertCheckbox:SetPoint("TOPLEFT", parentFrame, "TOP", INVERT_COLUMN_X, (-40 * newId) + 2);
        deleteRowButton:SetPoint("TOPLEFT", parentFrame, "TOP", DELETE_COLUMN_X, -40 * newId);
        spellBox:SetFocus();
        resizeScrollFrame(#windowSpellConfiguration.spells, specialisation);
    end
end

function DivineWindow.ConfigurationScreen.generateEditBoxPerSpecialisation(specialisationFrameScrollBox, specialisation,
                                                                           chosenWindow)
    if (not specialisation or specialisation.isSetup == false) then
        return;
    end

    local windowSpellConfiguration = DivineWindow.Utilities.getWindowConfiguration(specialisation);
    if (windowSpellConfiguration and windowSpellConfiguration.isSetUp) then
        local hiddenItems = 0;

        for index, spellConfiguration in ipairs(windowSpellConfiguration.spells) do
            local spellName = spellConfiguration.name;
            local countType = spellConfiguration.countType;
            local windowPart = spellConfiguration.windowPart;
            local deleted = spellConfiguration.deleted;
            local newIndex = index - hiddenItems;

            if (deleted) then
                hiddenItems = hiddenItems + 1;
            else
                -- same row positions as rearrangeEditRows, so rows don't jump when one is added
                local spellBox = addEditBox(specialisationFrameScrollBox,
                    DivineWindow.ConfigurationScreen.FrameNames.SPELL_SPELL_NAME_DROPDOWN_NAME ..
                    specialisation .. "_" .. index,
                    spellName, specialisation,
                    index);
                local countTypeBox = createCountTypeDropDownBox(
                    DivineWindow.ConfigurationScreen.FrameNames.SPELL_COUNTDOWN_TYPE_DROPDOWN_NAME ..
                    specialisation .. "_" .. index,
                    specialisationFrameScrollBox, index, specialisation, countType);
                local windowPartBox = createWindowPartDropDownBox(
                    DivineWindow.ConfigurationScreen.FrameNames.SPELL_WINDOW_PART_DROPDOWN_NAME ..
                    specialisation .. "_" .. index,
                    specialisationFrameScrollBox, index, specialisation, windowPart, chosenWindow);
                local deleteRowButton = createDeleteButton(
                    DivineWindow.ConfigurationScreen.FrameNames.SPELL_DELETE_ROW .. specialisation .. '_' .. index,
                    specialisationFrameScrollBox, index,
                    specialisation);
                local previewButton = createPreviewButton(
                    DivineWindow.ConfigurationScreen.FrameNames.SPELL_PREVIEW_BUTTON_NAME ..
                    specialisation .. '_' .. index,
                    specialisationFrameScrollBox, index,
                    specialisation);
                local invertCheckbox = createInvertCheckbox(
                    DivineWindow.ConfigurationScreen.FrameNames.SPELL_INVERT_CHECKBOX_NAME ..
                    specialisation .. '_' .. index,
                    specialisationFrameScrollBox, index,
                    specialisation);

                previewButton:SetPoint("TOPLEFT", specialisationFrameScrollBox, "TOP", 15, (-40 * newIndex) + 36);
                spellBox:SetPoint("TOPLEFT", specialisationFrameScrollBox, "TOP", 60, (-40 * newIndex) + 36);
                countTypeBox:SetPoint("TOPLEFT", specialisationFrameScrollBox, "TOP", 260, (-40 * newIndex) + 40);
                windowPartBox:SetPoint("TOPLEFT", specialisationFrameScrollBox, "TOP", 445, (-40 * newIndex) + 40);
                invertCheckbox:SetPoint("TOPLEFT", specialisationFrameScrollBox, "TOP", INVERT_COLUMN_X,
                    (-40 * newIndex) + 38);
                deleteRowButton:SetPoint("TOPLEFT", specialisationFrameScrollBox, "TOP", DELETE_COLUMN_X,
                    (-40 * newIndex) + 36);
            end
        end

        resizeScrollFrame(#windowSpellConfiguration.spells, specialisation, specialisationFrameScrollBox);
    end
end

-- Fit a tab to its text; Blizzard's tab template keeps its own text width otherwise ("Window ...").
local function sizeTabToText(tab, text)
    if (PanelTemplates_TabResize) then
        PanelTemplates_TabResize(tab, 0);
    else
        tab:SetWidth((string.len(text) * 8) + 10);
    end
end

local function generateSpecialisationTab(tabIndex, specialisation)
    local leftPowerBarValue = nil;
    local rightPowerBarValue = nil;
    local leftPowerBarColorValue = nil;
    local rightPowerBarColorValue = nil;
    local chosenWindow = nil;
    local tabAnchorName;
    local parentFrame = DivineWindow.ConfigurationScreen.frame;
    local frameName = DivineWindow.ConfigurationScreen.FrameNames.SPECIALISATION_SCREEN_NAME .. tostring(tabIndex);
    local scrollFrameName = DivineWindow.ConfigurationScreen.FrameNames.SPECIALISATION_SCREEN_SCROLL_NAME ..
        tostring(tabIndex);
    local tabName = DivineWindow.ConfigurationScreen.FrameNames.SPECIALISATION_SCREEN_TAB_BUTTON_NAME ..
        tostring(tabIndex);

    -- get initial values
    local windowSpellConfiguration = DivineWindow.Utilities.getWindowConfiguration(specialisation);
    if (windowSpellConfiguration and windowSpellConfiguration.isSetUp) then
        leftPowerBarValue = windowSpellConfiguration.powerBar.left;
        rightPowerBarValue = windowSpellConfiguration.powerBar.right;
        leftPowerBarColorValue = windowSpellConfiguration.powerBarColor.left;
        rightPowerBarColorValue = windowSpellConfiguration.powerBarColor.right;
        chosenWindow = windowSpellConfiguration.chosenWindow;
    end


    -- return panel;

    local specialisationFrame = CreateFrame("ScrollFrame", frameName, parentFrame, "UIPanelScrollFrameTemplate")
    local scrollChildFrame = CreateFrame("Frame", scrollFrameName, specialisationFrame)

    scrollChildFrame:SetPoint("TOPLEFT", 16, -16)
    scrollChildFrame:SetWidth(specialisationFrame:GetWidth() - 18)

    local leftPowerBar = createPowerBarDropDownBox(
        DivineWindow.ConfigurationScreen.FrameNames.SPECIALISATION_SCREEN_POWER_BAR_LEFT_NAME .. tostring(tabIndex),
        specialisationFrame, "left", specialisation, leftPowerBarValue);
    local leftPowerBarColor = createPowerBarColorDropDownBox(
        DivineWindow.ConfigurationScreen.FrameNames.SPECIALISATION_SCREEN_POWER_BAR_LEFT_COLOR_NAME .. tostring(tabIndex),
        specialisationFrame, "left", specialisation, leftPowerBarColorValue);
    local rightPowerBar = createPowerBarDropDownBox(
        DivineWindow.ConfigurationScreen.FrameNames.SPECIALISATION_SCREEN_POWER_BAR_RIGHT_NAME .. tostring(tabIndex),
        specialisationFrame, "right", specialisation, rightPowerBarValue);
    local rightPowerBarColor = createPowerBarColorDropDownBox(
        DivineWindow.ConfigurationScreen.FrameNames.SPECIALISATION_SCREEN_POWER_BAR_RIGHT_COLOR_NAME ..
        tostring(tabIndex),
        specialisationFrame, "right", specialisation, rightPowerBarColorValue);


    local function recreateEditBoxes(newWindow)
        if (not newWindow) then
            return;
        end
        chosenWindow = newWindow; -- rows added later must use the newly picked window
        -- iterate over all spells and recreate the edit boxes
        local windowSpellConfiguration = DivineWindow.Utilities.getWindowConfiguration(specialisation);
        if (windowSpellConfiguration and windowSpellConfiguration.isSetUp) then
            for index, spellConfiguration in ipairs(windowSpellConfiguration.spells) do
                local dropdown = DivineWindow.ConfigurationScreen.FrameNames.SPELL_WINDOW_PART_DROPDOWN_NAME ..
                    specialisation .. "_" .. index;

                -- deleted rows never got a dropdown
                if (_G[dropdown]) then
                    UIDropDownMenu_Initialize(
                        _G[dropdown],
                        windowPartMenuInfo(index, specialisation, newWindow))
                    UIDropDownMenu_SetSelectedValue(_G[dropdown], spellConfiguration.windowPart);
                end
            end
        end
    end

    local selectedWindow = DivineWindow.ConfigurationScreen.createWindowDropdown(
        DivineWindow.ConfigurationScreen.FrameNames.SPECIALISATION_SCREEN_WINDOW_DROPDOWN_NAME .. tostring(tabIndex),
        specialisationFrame, specialisation, chosenWindow, recreateEditBoxes);

    leftPowerBar:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 270, -60);
    rightPowerBar:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 453, -60);
    leftPowerBarColor:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 270, -90);
    rightPowerBarColor:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 453, -90);
    selectedWindow:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 20, -62);


    local labels = DivineWindow.Locales[DivineWindow.language].Labels;

    -- add labels for various elements;
    createText(labels.window, specialisationFrame):SetPoint("TOPLEFT", selectedWindow, "TOPLEFT", -25, 22);
    createText(labels.leftPowerBar, specialisationFrame):SetPoint("TOPLEFT", leftPowerBar, "TOPLEFT", -35, 22);
    createText(labels.rightPowerBar, specialisationFrame):SetPoint("TOPLEFT", rightPowerBar, "TOPLEFT", -33, 22);
    createText(labels.preview, specialisationFrame):SetPoint("TOPLEFT", parentFrame, "TOPLEFT", -62, -130);
    createText(labels.spellName, specialisationFrame):SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 60,
        -130);
    createText(labels.timer, specialisationFrame):SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 230, -130);
    createText(labels.windowPart, specialisationFrame):SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 450, -130);
    createText(labels.invert, specialisationFrame):SetPoint("TOPLEFT", parentFrame, "TOPLEFT", INVERT_COLUMN_X - 88, -130);
    createText(labels.delete, specialisationFrame):SetPoint("TOPLEFT", parentFrame, "TOPLEFT", DELETE_COLUMN_X - 70, -130);

    -- create some lines:
    local line = specialisationFrame:CreateLine()
    line:SetColorTexture(1, 0, 0)
    line:SetStartPoint("CENTER", -20, 20) -- start topleft
    --

    local tab = CreateFrame("Button", tabName, parentFrame, "PanelTabButtonTemplate")
    local ContentSlider = CreateFrame("Slider",
        DivineWindow.ConfigurationScreen.FrameNames.SPECIALISATION_SCREEN_SLIDER_NAME .. tostring(tabIndex),
        specialisationFrame,
        "OptionsSliderTemplate")
    ContentSlider:Show()

    specialisationFrame:SetWidth(parentFrame:GetWidth())
    specialisationFrame:SetHeight(parentFrame:GetHeight())
    specialisationFrame:SetPoint("TOPLEFT", 20, -150)
    specialisationFrame:SetPoint("BOTTOMRIGHT", -27, 50)


    -- set scrollchilds
    specialisationFrame:SetScrollChild(scrollChildFrame)

    local addRowButton = CreateFrame("Button",
        DivineWindow.ConfigurationScreen.FrameNames.SPELL_ADD_ROW .. specialisation,
        specialisationFrame, "UIPanelButtonTemplate")
    addRowButton:SetPoint("TOPLEFT", specialisationFrame, "BOTTOMLEFT", 5, 0);

    addRowButton:SetText(labels.addRow);
    addRowButton:SetWidth(100)
    addRowButton:SetHeight(30)
    addRowButton:Show();
    addRowButton:SetScript("OnClick", function(self)
        addRow(self, specialisation, scrollChildFrame, chosenWindow)
        rearrangeEditRows(specialisation, scrollChildFrame);
    end)

    specialisationFrame:Hide()

    --- tabs
    if (tabIndex == 1) then
        tabAnchorName = DivineWindow.ConfigurationScreen.FrameNames.GENERAL_TAB_NAME;
    else
        tabAnchorName = DivineWindow.ConfigurationScreen.FrameNames.SPECIALISATION_SCREEN_TAB_BUTTON_NAME .. tabIndex - 1;
    end

    tab:SetPoint("LEFT", tabAnchorName, "RIGHT", 10, 0)
    local tabText = DivineWindow.Utilities.getSpecialisationDisplayName(specialisation);
    tab:SetText(tabText)
    sizeTabToText(tab, tabText);
    tab:SetScript("OnClick", DivineWindow.ConfigurationScreen.setActiveTab(tabIndex, specialisation))
    tab:RegisterForClicks("AnyDown")
    tab:Show();

    DivineWindow.ConfigurationScreen.generateEditBoxPerSpecialisation(scrollChildFrame, specialisation, chosenWindow);
end

function DivineWindow.ConfigurationScreen.removeDeletedItems()
    for _, specialisation in ipairs(DivineWindow.Utilities.getSpecialisationNames()) do
        local windowSpellConfiguration = DivineWindow.Utilities.getWindowConfiguration(specialisation);

        if (windowSpellConfiguration) then
            for index, spellConfiguration in ipairs(windowSpellConfiguration.spells) do
                if (spellConfiguration.deleted) then
                    table.remove(DivineWindowLocalVars.specialisation[specialisation].spells, index);
                end
            end
        end
    end
end

-- only use when talents are initialized;
function DivineWindow.ConfigurationScreen.generateScreensForAllSpecialisations()
    local specialisationNames = DivineWindow.Utilities.getSpecialisationNames();
    local numberOfSpecialisations = #specialisationNames;
    for i, specialisation in ipairs(specialisationNames) do
        generateSpecialisationTab(i, specialisation);
    end

    local infoTab = CreateFrame("Button", DivineWindow.ConfigurationScreen.FrameNames.ABOUT_TAB_NAME,
        DivineWindow.ConfigurationScreen.frame, "PanelTabButtonTemplate")
    local buttonAnchor =
        _G[DivineWindow.ConfigurationScreen.FrameNames.SPECIALISATION_SCREEN_TAB_BUTTON_NAME ..
        numberOfSpecialisations];
    infoTab:SetPoint("LEFT", buttonAnchor, "RIGHT", 10, 0)
    infoTab:SetText(DivineWindow.Locales[DivineWindow.language].InfoTab.tabTitle)
    sizeTabToText(infoTab, DivineWindow.Locales[DivineWindow.language].InfoTab.tabTitle);

    infoTab:SetScript("OnClick",
        function() DivineWindow.ConfigurationScreen.openConfigTab(numberOfSpecialisations + 1) end);
    infoTab:RegisterForClicks("AnyDown")
    infoTab:Show();

    -- Let Blizzard's tab code manage the tabs: it shows the "selected" artwork on the active tab
    -- only. Unmanaged tabs show both the normal and the selected artwork on top of each other.
    local frame = DivineWindow.ConfigurationScreen.frame;
    local tabs = { _G[DivineWindow.ConfigurationScreen.FrameNames.GENERAL_TAB_NAME] };
    for i = 1, numberOfSpecialisations do
        table.insert(tabs, _G[DivineWindow.ConfigurationScreen.FrameNames.SPECIALISATION_SCREEN_TAB_BUTTON_NAME .. i]);
    end
    table.insert(tabs, infoTab);

    for id, tabButton in ipairs(tabs) do
        tabButton:SetID(id);
    end
    frame.Tabs = tabs;

    if (PanelTemplates_SetNumTabs and PanelTemplates_SetTab) then
        PanelTemplates_SetNumTabs(frame, #tabs);
        PanelTemplates_SetTab(frame, (DivineWindow.ConfigurationScreen.activeTab or 0) + 1);
    end
end

DivineWindow.Utilities.debugPrint("Src/ConfigurationScreen/SpecialisationSettings.lua", "file")
