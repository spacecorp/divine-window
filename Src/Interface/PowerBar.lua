local FACETS = 22;

local function getValues(powerType)
    if (powerType == DivineWindow.Constants.PowerTypes.HEALTH) then
        return UnitHealth("player"), UnitHealthMax("player");
    end

    local powerTypeId = Enum.PowerType[powerType];
    return UnitPower("player", powerTypeId), UnitPowerMax("player", powerTypeId);
end

local function getPowerBarPathPrefix(side, color)
    local powerBarDir = side == DivineWindow.Constants.WindowPowerBarType.LEFT_BAR and "LeftPowerBar" or "RightPowerBar";

    return "Interface\\AddOns\\DivineWindow\\Src\\Windows\\" .. powerBarDir .. "\\" .. color .. "\\";
end

-- Returns the facet (0..FACETS) and whether the bar is full, for a readable (non-secret) value.
local function getFacet(value, maxValue)
    if (not maxValue or maxValue <= 0) then
        return 0, false;
    end

    local percentage = math.ceil((value / maxValue) * 100);
    return math.ceil((FACETS / 100) * percentage), percentage == 100;
end

-- Evaluates a curve against the player's health/power percentage (0..1) on the game side.
-- Addon code is tainted, so curve:Evaluate(secretValue) is not allowed; these APIs are.
local function evaluatePercent(powerType, curve)
    if (powerType == DivineWindow.Constants.PowerTypes.HEALTH) then
        return UnitHealthPercent("player", false, curve);
    end

    return UnitPowerPercent("player", Enum.PowerType[powerType], false, curve);
end

-- Midnight (12.0+): health and most power is secret in combat; the game picks the facet via curves.
local function handleSteppedPowerBar(side, powerType, value, maxValue, pathPrefix, colorOpacity)
    local Stepped = DivineWindow.SteppedTexture;
    local fxKey = side .. "_FX";
    local fxFile = pathPrefix .. "fx.blp";

    if (Stepped.isSecret(value) or Stepped.isSecret(maxValue)) then
        if (not (UnitHealthPercent and UnitPowerPercent)) then
            return;
        end

        Stepped.showFromCurves(side, "BORDER", pathPrefix, FACETS, Stepped.getBandCurves(FACETS, 1, colorOpacity),
            function(curve) return evaluatePercent(powerType, curve) end);
        -- the old code showed the effect from 100% (rounded up), i.e. above 99%
        Stepped.showSingle(fxKey, "OVERLAY", fxFile,
            evaluatePercent(powerType, Stepped.getThresholdCurve(0.99, 1, colorOpacity)));
        return;
    end

    if (not maxValue or maxValue <= 0) then
        return;
    end

    local currentFacet, isFull = getFacet(value, maxValue);
    Stepped.showIndex(side, "BORDER", pathPrefix, FACETS, currentFacet, colorOpacity);
    Stepped.showSingle(fxKey, "OVERLAY", fxFile, isFull and colorOpacity or 0);
end

function DivineWindow.Interface.handlePowerBar(side, powerType, color)
    local colorOpacity = DivineWindowLocalVars.windowColorAlpha or 1;
    local texture = _G["DivineWindow_Interface_" .. DivineWindow.Constants.WindowPowerBarType[side]];
    local fx = _G["DivineWindow_Interface_" .. DivineWindow.Constants.WindowPowerBarType[side .. '_FX']];
    local pathPrefix = getPowerBarPathPrefix(side, color);
    local value, maxValue = getValues(powerType);

    if (DivineWindow.SteppedTexture.isSupported) then
        texture:SetTexture(nil, false);
        fx:SetTexture(nil, false);
        handleSteppedPowerBar(side, powerType, value, maxValue, pathPrefix, colorOpacity);
        return;
    end

    local currentFacet, isFull = getFacet(value, maxValue);
    texture:SetTexture(pathPrefix .. currentFacet .. ".blp", false);

    if (isFull) then
        fx:SetTexture(pathPrefix .. "fx.blp", false);
    else
        fx:SetTexture("", false);
    end
    texture:SetAlpha(colorOpacity);
    fx:SetAlpha(colorOpacity);
end
