-- Add the Trail of light status, created by Skamer.
-- Thank to grid authors to have this wonderful addon.
local AddonName = "druid-harmony"
local DruidHarmony = Grid2.statusPrototype:new(AddonName)

local Grid2 = Grid2

-- Wow APi
local GetSpellCooldown = GetSpellCooldown
local GetSpellInfo = GetSpellInfo
local GetSpellTexture = GetSpellTexture
local GetSpellInfo = GetSpellInfo
local GetSpellDescription = GetSpellDescription
local GetTalentInfo = GetTalentInfo
local GetSpecialization = GetSpecialization
local UnitGUID = UnitGUID
local UnitBuff = UnitBuff

-- data
local RejuvenationSpellID = 774
local Rejuvenation = GetSpellInfo(RejuvenationSpellID)

--local RejuvenationGermSpellID = 155777

local LifebloomSpellID = 33763
local Lifebloom = GetSpellInfo(LifebloomSpellID)
local RegrowthSpellID = 8936
local Regrowth = GetSpellInfo(RegrowthSpellID)
local SpringBlossomsSpellID = 207386
local SpringBlossoms = GetSpellInfo(SpringBlossomsSpellID)
local WildGrowthSpellID = 48438
local WildGrowth = GetSpellInfo(WildGrowthSpellID)
local SwiftmendSpellID = 18562
local SwiftmendCharges = 0

local OnUpdateFrame = nil

local DruidHarmonySpellID = 77495
local DruidHarmonyName = GetSpellInfo(DruidHarmonySpellID)
local DruidHarmonyIcon = GetSpellTexture(DruidHarmonySpellID)

--
local playerGUID = nil
local IsRestoSpec = false
local HotData = {}

DruidHarmony.UpdateAllUnits = Grid2.statusLibrary.UpdateAllUnits

local function OnUpdate()
  if not IsRestoSpec then
    return
  end

  local swiftmendCharges = GetSpellCharges(SwiftmendSpellID)
  if SwiftmendCharges ~= swiftmendCharges then
    SwiftmendCharges = swiftmendCharges
	DruidHarmony:UpdateAllUnits()
  end
end

function DruidHarmony:OnEnable()
  IsRestoSpec = GetSpecialization() == 4
  playerGUID = UnitGUID("player")

  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("RAID_ROSTER_UPDATE")
  self:RegisterEvent("GROUP_ROSTER_UPDATE")
  self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  self:RegisterEvent("PLAYER_TALENT_UPDATE")
  
  if OnUpdateFrame == nil then
	OnUpdateFrame = CreateFrame("Frame", nil, Grid2LayoutFrame)
  end
  OnUpdateFrame:SetScript("OnUpdate", OnUpdate)
end

function DruidHarmony:OnDisable()
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  self:UnregisterEvent("RAID_ROSTER_UPDATE")
  self:UnregisterEvent("GROUP_ROSTER_UPDATE")  
  self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  self:UnregisterEvent("PLAYER_TALENT_UPDATE")
  
  OnUpdateFrame:SetScript("OnUpdate", nil)
end

local function CheckBuff(unit, buff)
  local name = UnitBuff(unit, buff, nil, "PLAYER")
  if name ~= nil then
    return 1
  else
    return 0
  end
end

local function GetActiveHots(unit)
  return CheckBuff(unit, Rejuvenation) + CheckBuff(unit, WildGrowth) + CheckBuff(unit, Lifebloom) + CheckBuff(unit, SpringBlossoms) + CheckBuff(unit, Regrowth)
end

local function UpdateRoster()
  if not IsRestoSpec then
    return
  end

  wipe(HotData)
  for unit in Grid2:IterateRosterUnits() do
    local unitGUID = UnitGUID(unit)
    HotData[unitGUID] = GetActiveHots(unit)
  end
  DruidHarmony:UpdateAllUnits()
end

function DruidHarmony:PLAYER_ENTERING_WORLD()
  UpdateRoster()
end

function DruidHarmony:RAID_ROSTER_UPDATE()
  UpdateRoster()
end

function DruidHarmony:GROUP_ROSTER_UPDATE()
  UpdateRoster()
end

function DruidHarmony:PLAYER_TALENT_UPDATE()
  IsRestoSpec = GetSpecialization() == 4
end

function DruidHarmony:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, message, _, sourceGUID, sourceName, _, _, destGUID, destName, destFlags, destFlags2, ...)
  if not IsRestoSpec then
    return
  end
  
  if sourceGUID ~= playerGUID then
    return
  end

  local spellID, spellName, _, healAmount = ...
  if message == "SPELL_AURA_APPLIED" or message == "SPELL_AURA_REMOVED" then
    local activeHots = GetActiveHots(destName)
	local unitGUID = UnitGUID(destName)
	if unitGUID == nil then
	  return
	end
	HotData[unitGUID] = activeHots
  end

  DruidHarmony:UpdateAllUnits()
end

function DruidHarmony:IsActive(unit)
  return IsRestoSpec and UnitAffectingCombat("player");
end

function DruidHarmony:GetText(unit)
  local unitGUID = UnitGUID(unit)
  local activeHots = HotData[unitGUID]
  
  if activeHots == nil then
    activeHots = 0
  end
 
  local text = ""
  if activeHots > 0 and SwiftmendCharges == 0 then
    text = ""..activeHots
  elseif activeHots > 0 and SwiftmendCharges > 0 then
    text = "SM"..SwiftmendCharges.." - "..activeHots
  elseif SwiftmendCharges > 0 then
    text = "SM"..SwiftmendCharges
  end

  return text
end

function DruidHarmony:GetIcon()
  return DruidHarmonyIcon
end

function DruidHarmony:GetColor(unit)
  local unitGUID = UnitGUID(unit)
  local activeHots = HotData[unitGUID]
  
  if activeHots == nil then
    return 0, 0, 0, 0
  end

  if activeHots == 1 then
    return 1, 0, 0, 1
  elseif activeHots == 2 then
    return 1, 1, 0, 1
  elseif activeHots == 3 then
    return 0, 1, 0, 1
  elseif activeHots >= 4 then
    return 0, 1, 1, 1
  else
    return 1, 1, 1, 1
  end
end

local function CreateStatusDruidHarmony(baseKey, dbx)
  Grid2:RegisterStatus(DruidHarmony, {"text", "color"}, baseKey, dbx)
  return DruidHarmony
end

Grid2.setupFunc[AddonName] = CreateStatusDruidHarmony

Grid2:DbSetStatusDefaultValue(AddonName, {type = AddonName,  color1= {r=0,g=1,b=0,a=1}, color2= {r=1, g=1, b=1, a=1} } )
-- Hook to set the option properties
local PrevLoadOptions = Grid2.LoadOptions
function Grid2:LoadOptions()
  PrevLoadOptions(self)
  Grid2Options:RegisterStatusOptions(AddonName, "buff", nil, {title=AddonName, titleIcon = DruidHarmonyIcon, titleDesc=GetSpellDescription(DruidHarmonySpellID)})
end
