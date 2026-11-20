local function nilFunc() end
local previewTimer = C_Timer.NewTimer(0, nilFunc)
local previewTime = 3; -- seconds

local function resetPreviewCombatAlpha()
    if DivineWindow.Utilities.skipAfterReset() == true then return end;

    if (DivineWindow.Interface.frame) then
        if (UnitAffectingCombat("player")) then
            DivineWindow.Interface.frame:SetAlpha(DivineWindowLocalVars.inComabtAlpha);
        else
            DivineWindow.Interface.frame:SetAlpha(DivineWindowLocalVars.outOfCombatAlpha);
        end
    end
    previewTimer:Cancel()
end

function DivineWindow.ConfigurationScreen.setScale(value)
    DivineWindowLocalVars.scale = value;
    DivineWindow.Interface.frame:SetScale(value);
end

function DivineWindow.ConfigurationScreen.setInCombatAlpha(value)
    DivineWindowLocalVars.inComabtAlpha = value;
    DivineWindow.Interface.frame:SetAlpha(value);
    previewTimer:Cancel()
    previewTimer = C_Timer.NewTimer(previewTime, resetPreviewCombatAlpha)
end

function DivineWindow.ConfigurationScreen.setOutOfCombatAlpha(value)
    DivineWindowLocalVars.outOfCombatAlpha = value;
    DivineWindow.Interface.frame:SetAlpha(value);
    previewTimer:Cancel()
    previewTimer = C_Timer.NewTimer(previewTime, resetPreviewCombatAlpha)
end

function DivineWindow.ConfigurationScreen.setWindowShadingAlpha(value)
    DivineWindowLocalVars.windowGlassShading = value;
    _G["DivineWindow_Interface_" .. DivineWindow.Constants.WindowDetailType.SHADES]:SetAlpha(value);
    _G["DivineWindow_Interface_" .. DivineWindow.Constants.WindowDetailType.BASE_SHADES]:SetAlpha(value);
end

function DivineWindow.ConfigurationScreen.setWindowGrainAlpha(value)
    DivineWindowLocalVars.windowGlassGrain = value;
    _G["DivineWindow_Interface_" .. DivineWindow.Constants.WindowDetailType.GRAIN]:SetAlpha(value);
end

function DivineWindow.ConfigurationScreen.setWindowColorAlpha(value)
    DivineWindowLocalVars.windowColorAlpha = value;
end

function DivineWindow.ConfigurationScreen.setWindowBackgroundAlpha(value)
    DivineWindowLocalVars.windowBackgroundAlpha = value;
    _G["DivineWindow_Interface_" .. DivineWindow.Constants.WindowDetailType.BACKGROUND]:SetAlpha(value);
end

function DivineWindow.ConfigurationScreen.toggleMoving()
    DivineWindow.ConfigurationScreen.setMoving(not DivineWindow.ConfigurationScreen.isMoving);
end

function DivineWindow.ConfigurationScreen.setMoving(enabled)
    DivineWindow.ConfigurationScreen.isMoving = enabled and true or false;

    local placementBoxFrame = _G["DivineWindow_Interface_Window_PLACEMENT_BOX"];
    local interfaceFrame = DivineWindow.Interface.frame;
    local buttonFrame = _G[DivineWindow.ConfigurationScreen.FrameNames.INTERFACE_BACKGROUND_MOVE_BUTTON];
    local currLanguage = DivineWindow.Locales[DivineWindow.language];

    if (not interfaceFrame) then
        return;
    end

    if (DivineWindow.ConfigurationScreen.isMoving) then
        interfaceFrame:SetFrameStrata("TOOLTIP");
        interfaceFrame:EnableMouse(true)
        interfaceFrame:SetMovable(true)
        interfaceFrame:SetAlpha(1);
        interfaceFrame:Show();
        placementBoxFrame:Show()

        if (buttonFrame) then
            buttonFrame:SetText(currLanguage.GeneralTab.moveButton_off);
        end
    else
        interfaceFrame:SetFrameStrata("LOW");
        interfaceFrame:EnableMouse(false)
        interfaceFrame:SetMovable(false)
        interfaceFrame:StopMovingOrSizing()
        placementBoxFrame:Hide()

        if (UnitAffectingCombat("player")) then
            DivineWindow.Interface.frame:SetAlpha(DivineWindow.Interface.getInCombatAlpha());
        else
            DivineWindow.Interface.frame:SetAlpha(DivineWindow.Interface.getOutOfCombatAlpha());
        end
        if (DivineWindowLocalVars.active ~= true) then
            interfaceFrame:Hide()
        end
        if (buttonFrame) then
            buttonFrame:SetText(currLanguage.GeneralTab.moveButton_on);
        end
    end
end

-- Blizzard's Edit Mode (retail): make the window movable while Edit Mode is open, like the
-- move button in the configuration screen does. Clients without Edit Mode skip this.
if (EventRegistry and EventRegistry.RegisterCallback and EditModeManagerFrame) then
    local startedByEditMode = false;

    EventRegistry:RegisterCallback("EditMode.Enter", function()
        if (not DivineWindow.ConfigurationScreen.isMoving) then
            startedByEditMode = true;
            DivineWindow.ConfigurationScreen.setMoving(true);
        end
    end, DivineWindow);

    EventRegistry:RegisterCallback("EditMode.Exit", function()
        -- leave it alone when moving was switched on from the configuration screen
        if (startedByEditMode) then
            startedByEditMode = false;
            DivineWindow.ConfigurationScreen.setMoving(false);
        end
    end, DivineWindow);
end

DivineWindow.Utilities.debugPrint("Src/ConfigurationScreen/GeneralSettings.lua", "file")
