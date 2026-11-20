-- DivineWindow.Locales.English.PALADIN
local function handleBuffDebuffExpirationTime(auraDuration, auraRemainingTime, facets)
    if (not auraDuration or not auraRemainingTime or auraDuration <= 0 or auraRemainingTime <= 0) then
        return 0;
    end

    return math.ceil(facets / auraDuration * auraRemainingTime);
end

local function handleBuffDeBuffStacks(auraStacks, auraTotalStacks, facets)
    if (not auraStacks or auraStacks <= 0) then
        return 0;
    end

    -- Auras don't report a maximum, so then every stack lights up one more facet.
    if (not auraTotalStacks or auraTotalStacks <= 0) then
        return math.min(auraStacks, facets);
    end

    return math.min(facets, math.ceil(facets * auraStacks / auraTotalStacks));
end


local function handleCooldown(auraDuration, auraRemainingTime, facets)
    if (not auraDuration or not auraRemainingTime or auraDuration <= 0 or auraRemainingTime <= 0) then
        return 0;
    end
    return math.ceil(facets / auraDuration * auraRemainingTime);
end

local function handleCooldownStacks(auraStacks, auraTotalStacks, facets)
    if (not auraStacks or not auraTotalStacks or auraTotalStacks <= 0) then
        return 0;
    end
    return math.min(facets, math.ceil(facets * auraStacks / auraTotalStacks));
end


local function handleOnOff(isOn, facets)
    if (isOn) then
        return facets;
    end

    return nil;
end

local function getChosenWindowTextureBasePath(specialisation)
    if (DivineWindow.Utilities.tableIsEmpty(DivineWindow.ConfigurationScreen.AvailableWindows)) then
        return;
    end
    
    if (
            DivineWindowLocalVars
            and DivineWindowLocalVars.specialisation
            and DivineWindowLocalVars.specialisation[specialisation]
            and DivineWindowLocalVars.specialisation[specialisation].chosenWindow) then
        local category = DivineWindowLocalVars.specialisation[specialisation].chosenWindow[1];
        local window = DivineWindowLocalVars.specialisation[specialisation].chosenWindow[2];

        if (not (category and window)) then
            return nil, nil, nil;
        end

        -- The window's addon may be missing or disabled while saved settings still point to it.
        local windows = DivineWindow.Windows[category];
        local windowData = windows and windows[window];
        if (not windowData) then
            return nil, nil, nil;
        end

        return windowData.Directory, category, window;
    end

    return nil, nil, nil;
end

function DivineWindow.Interface.resetTextures()
    if (DivineWindow.SteppedTexture.isSupported) then
        DivineWindow.SteppedTexture.hideAll();
    end

    -- every PART_x texture in Interface/Index.xml (some windows, e.g. Xal'atath, use up to PART_12)
    for i = 1, 12 do
        local textureLocation = _G["DivineWindow_Interface_PART_" .. i];
        if (textureLocation) then
            textureLocation:SetTexture(nil, false);
        end
    end

    _G["DivineWindow_Interface_FX_1"]:SetTexture(nil, false);
    _G["DivineWindow_Interface_FX_2"]:SetTexture(nil, false);
end

function DivineWindow.Interface.setBaseTextures(
    chosenWindow
)
    DivineWindow.Interface.resetTextures()
    local basePath, category, window = getChosenWindowTextureBasePath(chosenWindow);

    if (not (basePath and category and window)) then
        return;
    end

    if (not (basePath and category and window)) then
        return;
    end

    local shading = _G["DivineWindow_Interface_SHADES"];
    local window = _G["DivineWindow_Interface_WINDOW"];
    local grain = _G["DivineWindow_Interface_GRAIN"];
    local shadingFile = basePath .. "\\Shading.blp";
    local grainFile = basePath .. "\\Grain.blp";
    local windowFile = basePath .. "\\Window.blp";

    shading:SetTexture(shadingFile, false);
    window:SetTexture(windowFile, false);
    grain:SetTexture(grainFile, false);
end

-- Midnight (12.0+): cooldowns and charges are secret in combat, so render them with stacked facet
-- textures whose visibility the game decides (see Interface/SteppedTexture.lua).
function DivineWindow.Interface.handleSteppedCooldown(countType, spellName, chosenWindow, windowPart, inverted)
    local Stepped = DivineWindow.SteppedTexture;
    local basePath, category, window = getChosenWindowTextureBasePath(chosenWindow);

    if (not (basePath and category and window)) then
        return;
    end

    local facets = DivineWindow.Windows[category][window].FacetCount[windowPart];
    local spellId = Stepped.getSpellId(spellName);

    if (not (facets and spellId)) then
        return;
    end

    local alpha = DivineWindowLocalVars.windowColorAlpha or 1;
    local pathPrefix = basePath .. "\\" .. windowPart .. "\\";
    local drawLayer = string.find(windowPart, "^FX_") and "OVERLAY" or "BORDER";

    if (countType == DivineWindow.Constants.CountType.COOLDOWN_TIMER) then
        local duration = Stepped.getCooldownDuration(spellId);
        if (not duration) then
            -- no cooldown running: empty, or fully lit when inverted
            if (inverted) then
                Stepped.showIndex(windowPart, drawLayer, pathPrefix, facets, facets, alpha);
            end
            return;
        end

        local curves = inverted and Stepped.getInvertedBandCurves(facets, 1, alpha) or
            Stepped.getBandCurves(facets, 1, alpha);
        Stepped.showFromCurves(windowPart, drawLayer, pathPrefix, facets, curves,
            function(curve) return duration:EvaluateRemainingPercent(curve) end);
        return;
    end

    if (countType == DivineWindow.Constants.CountType.COOLDOWN_STACKS) then
        local charges = C_Spell.GetSpellCharges(spellId);
        if (not charges) then
            return;
        end

        local current, maxCharges = charges.currentCharges, charges.maxCharges;
        if (Stepped.isSecret(maxCharges) or not maxCharges or maxCharges <= 0) then
            return;
        end

        -- curve:Evaluate() rejects secret values from addon (tainted) code and there is no
        -- game-side curve API for charge counts, so leave the part hidden while it is secret.
        if (not Stepped.isSecret(current)) then
            local index = handleCooldownStacks(current, maxCharges, facets);
            if (inverted) then
                index = facets - index;
            end
            Stepped.showIndex(windowPart, drawLayer, pathPrefix, facets, index, alpha);
        end
    end
end

function DivineWindow.Interface.handleWindowFacet(
    countType,
    isOn,
    auraDuration,
    auraRemainingTime,
    auraStacks,
    auraTotalStacks,
    chosenWindow, windowPart, test, inverted
)
    local textureLocation = _G["DivineWindow_Interface_" .. windowPart];
    local currentFacet;

    if (not textureLocation) then
        return;
    end

    local colorOpacity = DivineWindowLocalVars.windowColorAlpha or 1;
    local basePath, category, window = getChosenWindowTextureBasePath(chosenWindow);

    if (not (basePath and category and window)) then
        return;
    end

    local facets = DivineWindow.Windows[category][window].FacetCount[windowPart];


    if (not (facets and basePath)) then
        return;
    end

    if (countType == DivineWindow.Constants.CountType.ON_OFF) then
        currentFacet = handleOnOff(isOn, facets);
    end

    if (countType == DivineWindow.Constants.CountType.BUFF_DEBUFF_STACKS) then
        currentFacet = handleBuffDeBuffStacks(auraStacks, auraTotalStacks, facets);
    end

    if (countType == DivineWindow.Constants.CountType.BUFF_DEBUFF_EXPIRATION_TIME) then
        currentFacet = handleBuffDebuffExpirationTime(auraDuration, auraRemainingTime, facets);
    end

    if (countType == DivineWindow.Constants.CountType.COOLDOWN_TIMER) then
        currentFacet = handleCooldown(auraDuration, auraRemainingTime, facets);
    end

    if (countType == DivineWindow.Constants.CountType.COOLDOWN_STACKS) then
        currentFacet = handleCooldownStacks(auraStacks, auraTotalStacks, facets);
    end

    if (countType == DivineWindow.Constants.CountType.CHANNELING) then
        currentFacet = handleBuffDebuffExpirationTime(auraDuration, auraRemainingTime, facets);
    end

    -- A channeling timer only ever shows while channeling; inverting only reverses it during the channel.
    local isIdleChannel = countType == DivineWindow.Constants.CountType.CHANNELING and
        not (auraDuration and auraRemainingTime and auraDuration > 0 and auraRemainingTime > 0);

    -- Inverted: fully lit while off, emptying as the timer/stacks fill up (and the other way round).
    if (inverted and not isIdleChannel) then
        currentFacet = facets - math.min(currentFacet or 0, facets);
    end

    if (currentFacet == nil or currentFacet <= 0) then
        textureLocation:SetTexture(nil, false)
        return;
    end

    local textureFile =
        basePath .. "\\" .. windowPart .. "\\" .. currentFacet .. ".blp"

    textureLocation:SetTexture(textureFile, false);
    textureLocation:SetAlpha(colorOpacity);
end
