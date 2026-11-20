-- Stepped textures for WoW Midnight (12.0+).
--
-- In combat, cooldowns, health and power are "secret values": the addon may not read, compare or
-- calculate with them, so it can no longer pick "facet 7.blp" itself.
-- Instead every facet of a window part is preloaded as its own texture, stacked on the same spot.
-- Each facet gets a curve that returns the window colour opacity only inside its own slice of the
-- value (and 0 elsewhere). The game evaluates the curve against the secret value and the result
-- goes straight into SetAlpha, so exactly one facet is visible without the addon knowing which.
--
-- Facet i of n is visible when value is in ((i - 1) / n * max, i / n * max], which is the same
-- step as the old math.ceil(n * value / max).
DivineWindow.SteppedTexture = {}
local Stepped = DivineWindow.SteppedTexture

-- Only clients with the curve API (retail 12.0+) use this renderer; Classic flavors keep the old path.
Stepped.isSupported = (C_CurveUtil ~= nil and C_CurveUtil.CreateCurve ~= nil)

-- Width of the near-vertical ramp between two facets, as a fraction of the maximum value.
-- Curves are linear, so a tiny ramp behaves like a hard step.
local EPS = 0.0001
local MAX_CACHED_CURVE_SETS = 64

local curveCache = {}
local curveCacheSize = 0
local layers = {}
local spellIdCache = {}

function Stepped.isSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

local function newCurve(points)
    local curve = C_CurveUtil.CreateCurve()

    if (curve.SetType and Enum.LuaCurveType and Enum.LuaCurveType.Linear) then
        curve:SetType(Enum.LuaCurveType.Linear)
    end

    for _, point in ipairs(points) do
        curve:AddPoint(point[1], point[2])
    end

    return curve
end

local function createBandCurve(lo, hi, maxValue, onAlpha)
    local eps = maxValue * EPS
    local points = { { 0, 0 } }

    if (lo > 0) then
        table.insert(points, { lo, 0 })
    end
    table.insert(points, { lo + eps, onAlpha })
    table.insert(points, { hi, onAlpha })
    if (hi < maxValue) then
        table.insert(points, { hi + eps, 0 })
        table.insert(points, { maxValue, 0 })
    end

    return newCurve(points)
end

local function cached(key, build)
    local value = curveCache[key]
    if (value) then
        return value
    end

    -- Max health/power changes now and then; don't let old curve sets pile up.
    if (curveCacheSize >= MAX_CACHED_CURVE_SETS) then
        curveCache = {}
        curveCacheSize = 0
    end

    value = build()
    curveCache[key] = value
    curveCacheSize = curveCacheSize + 1
    return value
end

-- n curves; curve i outputs onAlpha only while the value is inside facet i's slice of [0, maxValue].
function Stepped.getBandCurves(facets, maxValue, onAlpha)
    return cached("band:" .. facets .. ":" .. maxValue .. ":" .. onAlpha, function()
        local curves = {}
        for i = 1, facets do
            curves[i] = createBandCurve((i - 1) / facets * maxValue, i / facets * maxValue, maxValue, onAlpha)
        end
        return curves
    end)
end

-- Same as getBandCurves, but reversed: facet n is lit at 0 and facet 1 near maxValue, i.e. the
-- facet shown is n - ceil(n * value / max) ("invert" option of a window part).
function Stepped.getInvertedBandCurves(facets, maxValue, onAlpha)
    return cached("inverted:" .. facets .. ":" .. maxValue .. ":" .. onAlpha, function()
        local curves = {}
        local eps = maxValue * EPS
        for i = 1, facets - 1 do
            local k = facets - i
            curves[i] = createBandCurve((k - 1) / facets * maxValue, k / facets * maxValue, maxValue, onAlpha)
        end
        -- the last facet is lit only when the value is 0 (nothing left)
        curves[facets] = newCurve({ { 0, onAlpha }, { eps, 0 }, { maxValue, 0 } })
        return curves
    end)
end

-- One curve that outputs onAlpha only above the threshold (used for the "full" power bar effect).
function Stepped.getThresholdCurve(threshold, maxValue, onAlpha)
    return cached("threshold:" .. threshold .. ":" .. maxValue .. ":" .. onAlpha, function()
        return newCurve({ { 0, 0 }, { threshold, 0 }, { threshold + maxValue * EPS, onAlpha }, { maxValue, onAlpha } })
    end)
end

local function createLayerTexture(drawLayer)
    local parent = DivineWindow.Interface.frame
    local texture = parent:CreateTexture(nil, drawLayer)

    -- Same placement as the window part textures in Interface/Index.xml
    texture:SetSize(1024, 1024)
    texture:SetPoint("TOPLEFT", parent, "TOPLEFT", -180, 0)
    texture:SetAlpha(0)

    return texture
end

-- A layer is the stack of facet textures for one window part (or power bar).
-- Textures are only (re)loaded when the window/colour changes, not every update.
local function prepareLayer(key, drawLayer, filesKey, count, fileForIndex)
    local layer = layers[key]
    if (not layer) then
        layer = { textures = {}, filesKey = nil, count = 0 }
        layers[key] = layer
    end

    if (layer.filesKey == filesKey and layer.count == count) then
        return layer
    end

    for i = 1, count do
        local texture = layer.textures[i]
        if (not texture) then
            texture = createLayerTexture(drawLayer)
            layer.textures[i] = texture
        end
        texture:SetTexture(fileForIndex(i), false)
        texture:SetAlpha(0)
    end

    for i = count + 1, #layer.textures do
        layer.textures[i]:SetTexture(nil, false)
        layer.textures[i]:SetAlpha(0)
    end

    layer.filesKey = filesKey
    layer.count = count
    return layer
end

local function prepareFacetLayer(key, drawLayer, pathPrefix, facets)
    return prepareLayer(key, drawLayer, pathPrefix, facets, function(i)
        return pathPrefix .. i .. ".blp"
    end)
end

-- Hide every stepped texture; called at the start of every interface update.
function Stepped.hideAll()
    for _, layer in pairs(layers) do
        for i = 1, layer.count do
            layer.textures[i]:SetAlpha(0)
        end
    end
end

-- Non-secret value: show one known facet (index 0 or nil shows nothing).
function Stepped.showIndex(key, drawLayer, pathPrefix, facets, index, alpha)
    local layer = prepareFacetLayer(key, drawLayer, pathPrefix, facets)

    for i = 1, facets do
        layer.textures[i]:SetAlpha(i == index and alpha or 0)
    end
end

-- Secret value: let the game evaluate each facet's curve, evaluate(curve) returns the (secret) alpha.
function Stepped.showFromCurves(key, drawLayer, pathPrefix, facets, curves, evaluate)
    local layer = prepareFacetLayer(key, drawLayer, pathPrefix, facets)

    for i = 1, facets do
        layer.textures[i]:SetAlpha(evaluate(curves[i]))
    end
end

-- A single texture whose alpha may be secret (e.g. the power bar "fx.blp").
function Stepped.showSingle(key, drawLayer, file, alpha)
    local layer = prepareLayer(key, drawLayer, file, 1, function()
        return file
    end)

    layer.textures[1]:SetAlpha(alpha)
end

-- Spells are configured by name; spell IDs are needed for the duration APIs.
function Stepped.getSpellId(spellName)
    local spellId = spellIdCache[spellName]
    if (spellId) then
        return spellId
    end

    local info = C_Spell.GetSpellInfo(spellName)
    if (info and info.spellID and not Stepped.isSecret(info.spellID)) then
        spellIdCache[spellName] = info.spellID
        return info.spellID
    end

    return nil
end

-- Duration object for the spell's cooldown: the recharge for spells with charges,
-- the regular cooldown otherwise. Returns nil while only the global cooldown is running.
function Stepped.getCooldownDuration(spellId)
    local cooldown = C_Spell.GetSpellCooldown(spellId)
    if (cooldown and not Stepped.isSecret(cooldown.isOnGCD) and cooldown.isOnGCD) then
        return nil
    end

    -- For spells with charges the regular cooldown only runs once every charge is used, and it
    -- counts down to the next charge (the shortest recharge). So the window stays empty while a
    -- charge is left, which is what we want; no need to look at the charges themselves.
    if (C_Spell.GetSpellCooldownDuration) then
        return C_Spell.GetSpellCooldownDuration(spellId)
    end

    return nil
end

DivineWindow.Utilities.debugPrint("Src/Interface/SteppedTexture.lua", "file")
