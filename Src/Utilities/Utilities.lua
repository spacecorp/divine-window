function DivineWindow.Utilities.dump(o)
  if type(o) == 'table' then
    local s = '{ ';
    for k, v in pairs(o) do
      if type(k) ~= 'number' then k = '"' .. k .. '"' end
      s = s .. '[' .. k .. '] = ' .. DivineWindow.Utilities.dump(v) .. ',';
    end
    return s .. '} ';
  else
    return tostring(o);
  end
end

function DivineWindow.Utilities.printToUser(message)
  print("\124cffFF9900[Divine Window]: " .. message)
end

function DivineWindow.Utilities.debugPrint(message, type)
  if (DivineWindow.debugMode) then
    if (type == "file") then
      DivineWindow.Utilities.printToUser("[DW loaded file]: " .. message)
    else
      DivineWindow.Utilities.printToUser("[DW Debug]: " .. message)
    end
  end
end

function DivineWindow.Utilities.skipAfterReset()
  if (DivineWindowLocalVars == {} or DivineWindowGlobalVars == {}) then
    return true
  end

  return false;
end

function DivineWindow.Utilities.parseText(s, tab)
  return (s:gsub('($%b{})', function(w) return tab[w:sub(3, -2)] or w end))
end

function DivineWindow.Utilities.mergeTable(t1, t2)
  for i = 1, #t2 do
    t1[#t1 + 1] = t2[i]
  end
  return t1
end

local function getCharacterinfo(target)
  local genderTable = { "neuter or unknown", "male", "female" };
  local localizedPlayerClass, playerClass, _ = UnitClass(target);
  local name, _, _ = UnitName(target)
  local unitLevel = UnitLevel(target)
  local gender = genderTable[UnitSex(target)]
  local race, _ = UnitRace(target);

  return name, gender, playerClass, race, unitLevel
end

function DivineWindow.Utilities.round(number)
  return number >= 0 and math.floor(number + 0.5) or math.ceil(number - 0.5)
end

function DivineWindow.Utilities.getPlayerInformation()
  return getCharacterinfo("player")
end

function DivineWindow.Utilities.tableIsEmpty(table)
  if (table == nil or table == {} or type(table) == nil) then
    return true
  end

  for _, _ in pairs(table) do
    return false
  end

  return true
end

function DivineWindow.Utilities.capitalizeString(str)
  local newString = string.lower(str)
  return (newString:gsub("^%l", string.upper))
end

function DivineWindow.Utilities.tableContainsValue(table, val)
  if (table == nil) then
    return false
  end
  
  for index, value in ipairs(table) do
    if value == val then
      return true
    end
  end

  return false
end

function DivineWindow.Utilities.tableContainsKey(table, key)
  for k, v in pairs(table) do
    if k == key then
      return true
    end
  end

  return false
end

function DivineWindow.Utilities.tableContainsSameData(table1, table2)
  if #table1 ~= #table2 then return false end
  -- Consider an early "return true" if table1 == table2 here
  local t1_counts = {}
  -- Check if the same elements occur the same number of times
  for _, v1 in ipairs(table1) do
    t1_counts[v1] = (t1_counts[v1] or 0) + 1
  end
  for _, v2 in ipairs(table2) do
    local count = t1_counts[v2] or 0
    if count == 0 then return false end
    t1_counts[v2] = count - 1
  end
  return true
end

function DivineWindow.Utilities.getWindowConfiguration(specialisation)
  if (not DivineWindowLocalVars or not specialisation) then
    return nil
  end

  local specialisationExists = DivineWindowLocalVars.specialisation and
      DivineWindow.Utilities.tableIsEmpty(DivineWindowLocalVars.specialisation) == false;

  if (specialisationExists) then
    local specialisationTable = DivineWindowLocalVars.specialisation and
        DivineWindowLocalVars.specialisation[specialisation];
    if (specialisationTable and specialisationTable.isSetUp) then
      return specialisationTable;
    end
  end

  return nil
end

-- Some WoW versions (e.g. Classic Era) have no class specialisations. Those use one set of
-- settings stored under this name, e.g. DivineWindowLocalVars.specialisation.General and
-- DivineWindow.Windows.PALADIN.DefaultSettings.General.
DivineWindow.GENERAL_SPECIALISATION = "General";

function DivineWindow.Utilities.hasSpecialisations()
  if (not (GetSpecialization and GetNumSpecializations and GetSpecializationInfo)) then
    return false
  end

  local numberOfSpecialisations = GetNumSpecializations();
  if (not numberOfSpecialisations or numberOfSpecialisations <= 0) then
    return false
  end

  local _, firstSpecialisationName = GetSpecializationInfo(1);
  if (firstSpecialisationName == nil) then
    return false
  end

  -- Versions where talents come from a skill tree instead (e.g. WoW Forever) may still have
  -- these functions, but the player never has an active specialisation there.
  local activeSpecialisationId = GetSpecialization();
  return activeSpecialisationId ~= nil and activeSpecialisationId > 0
end

-- True once the specialisation information can be read (always, on versions without them).
function DivineWindow.Utilities.specialisationsReady()
  if (C_SpecializationInfo and C_SpecializationInfo.IsInitialized and GetSpecialization) then
    return C_SpecializationInfo.IsInitialized()
  end

  return true
end

-- Names of all specialisations of the player's class, or { "General" } without specialisations.
function DivineWindow.Utilities.getSpecialisationNames()
  if (not DivineWindow.Utilities.hasSpecialisations()) then
    return { DivineWindow.GENERAL_SPECIALISATION }
  end

  local names = {};
  for i = 1, GetNumSpecializations() do
    local _, name = GetSpecializationInfo(i);
    names[i] = name;
  end
  return names
end

function DivineWindow.Utilities.getActiveSpecialisationName()
  if (not DivineWindow.Utilities.hasSpecialisations()) then
    return DivineWindow.GENERAL_SPECIALISATION
  end

  local activeSpecialisationId = GetSpecialization();
  if (not activeSpecialisationId) then
    return nil
  end

  local _, name = GetSpecializationInfo(activeSpecialisationId);
  return name
end

-- Text for tabs and titles: the specialisation name, or "Window configuration" for General.
function DivineWindow.Utilities.getSpecialisationDisplayName(specialisation)
  if (specialisation == DivineWindow.GENERAL_SPECIALISATION) then
    return DivineWindow.Locales[DivineWindow.language].Labels.generalSpecialisation or specialisation
  end

  return specialisation
end

-- Every class may use every window, so this only checks that the player's specialisation (or
-- "General" on versions without specialisations) is known. Class addons only provide defaults.
function DivineWindow.Utilities.classHasSupportedSpecialisation()
  local hasSpecialisation = DivineWindow.specialisation ~= nil;
  DivineWindow.Utilities.debugPrint("Has specialisation: " .. tostring(hasSpecialisation))
  return hasSpecialisation
end

function DivineWindow.Utilities.ShowError(message)
  DivineWindow.Utilities.printToUser("[Divine Window] Error: " .. message)
end

DivineWindow.Utilities.debugPrint("Src/Utilities/Utilities.lua", "file")
