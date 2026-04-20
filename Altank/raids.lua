-- Altank raid/boss feature module.
-- Add encounter-specific features here (boss mechanics, raid warnings, etc).
-- Return true to consume the event and stop further processing in Altank.lua.
local MAGTHERIDONS_LAIR_MAP_ID = 544
local KARAZHAN_MAP_ID = 532
local MAGTHERIDON_NPC_ID = 17257
local BLAST_NOVA_SPELL_ID = 30616
local MIND_EXHAUSTION_SPELL_ID = 44032
local SHADOW_GRASP_SPELL_ID = 30410
local MOROES_NPC_ID = 15687
local PRINCE_MALCHEZAAR_NPC_ID = 15690
local NETHERSPITE_NPC_ID = 15689
local SHADE_OF_ARAN_NPC_ID = 16524
local MAIDEN_OF_VIRTUE_NPC_ID = 16457
local TERESTIAN_ILLHOOF_NPC_ID = 15688
local DIVINE_SHIELD_SPELL_ID = 642
local ICE_BLOCK_SPELL_ID = 45438
local GOUGE_SPELL_ID = 29425
local FLAME_WREATH_SPELL_ID = 29946
local REPENTANCE_SPELL_ID = 29511
local SACRIFICE_SPELL_ID = 30115
local BLAST_NOVA_NAME = GetSpellInfo and GetSpellInfo(BLAST_NOVA_SPELL_ID) or "Blast Nova"
local MIND_EXHAUSTION_NAME = GetSpellInfo and GetSpellInfo(MIND_EXHAUSTION_SPELL_ID) or "Mind Exhaustion"
local SHADOW_GRASP_NAME = GetSpellInfo and GetSpellInfo(SHADOW_GRASP_SPELL_ID) or "Shadow Grasp"
local NETHER_PORTAL_PERSEVERENCE_SPELL_ID = 30466
local NETHER_PORTAL_PERSEVERENCE_ALT_SPELL_ID = 30421
local NETHER_PORTAL_SERENITY_SPELL_ID = 30467
local NETHER_PORTAL_DOMINANCE_SPELL_ID = 30468
local NETHER_PORTAL_PERSEVERENCE_NAME = GetSpellInfo and GetSpellInfo(NETHER_PORTAL_PERSEVERENCE_SPELL_ID) or "Nether Portal - Perseverence"
local NETHER_PORTAL_SERENITY_NAME = GetSpellInfo and GetSpellInfo(NETHER_PORTAL_SERENITY_SPELL_ID) or "Nether Portal - Serenity"
local NETHER_PORTAL_DOMINANCE_NAME = GetSpellInfo and GetSpellInfo(NETHER_PORTAL_DOMINANCE_SPELL_ID) or "Nether Portal - Dominance"
local GOUGE_NAME = GetSpellInfo and GetSpellInfo(GOUGE_SPELL_ID) or "Gouge"
local FLAME_WREATH_NAME = GetSpellInfo and GetSpellInfo(FLAME_WREATH_SPELL_ID) or "Flame Wreath"
local REPENTANCE_NAME = GetSpellInfo and GetSpellInfo(REPENTANCE_SPELL_ID) or "Repentance"
local SACRIFICE_NAME = GetSpellInfo and GetSpellInfo(SACRIFICE_SPELL_ID) or "Sacrifice"
local MAG_CUBE_REQUIRED_PLAYERS = 5
local MAG_BLAST_CAST_WINDOW = 2.8
local MAG_LATE_CLICK_THRESHOLD = 1.2
local NETHERSPITE_BLUE_STACK_DANGER_THRESHOLD = 21
local ENABLE_NETHERSPITE_MODULE = false

local raidState = {
    isInRaidInstance = false,
    isInMagtheridonsLair = false,
    isInKarazhan = false,
    justEnteredRaidInstance = false,
    instanceName = nil,
    instanceMapID = nil,
}

local princeState = {
    engaged = false,
    warnedAt60 = false,
    notifiedAt30 = false,
    warningTicker = nil,
    centerHideTicker = nil,
}

local magState = {
    engaged = false,
    triggeredAt30 = false,
    countdownTicker = nil,
    countdownSequence = 0,
    blastNextAt = 0,
    blastWarnedAt6 = false,
    blastTicker = nil,
}

local cubeState = {
    activeHolders = {},
    blastAttempt = {
        active = false,
        startAt = 0,
        participants = {},
        sequence = 0,
        resolveTimer = nil,
    },
}

local netherspiteState = {
    engaged = false,
    bossStacks = 0,
    playerStacks = 0,
    lastBossHadBuff = false,
    phaseTankGUID = nil,
    phaseTankName = nil,
    currentBeamTankGUID = nil,
    currentBeamTankName = nil,
    lastPhaseBeamTankGUID = nil,
    lastPhaseBeamTankName = nil,
    redPhaseSequence = 0,
    warnedTakeRedSequence = 0,
    warnedMoveOut = false,
    warnedMoveIn = false,
    greenBeamTargetGUID = nil,
    greenBeamTargetName = nil,
    blueBeamTargetGUID = nil,
    blueBeamTargetName = nil,
    blueBeamTargetStacks = 0,
}

local moroesState = {
    engaged = false,
    lastWarnAt = 0,
}
local aranState = {
    engaged = false,
    lastFlameWreathWarnAt = 0,
}
local maidenState = {
    engaged = false,
    lastRepentanceWarnAt = 0,
}
local illhoofState = {
    engaged = false,
    lastSacrificeWarnAt = 0,
}

local centerUI = {
    frame = nil,
    text = nil,
}

local netherspiteUI = {
    frame = nil,
    redIcon = nil,
    redStacks = nil,
    greenIcon = nil,
    greenTarget = nil,
    blueIcon = nil,
    blueTarget = nil,
}

local cubeUI = {
    frame = nil,
    title = nil,
    icon = nil,
    countdownText = nil,
    rows = {},
}
local magBlastUI = {
    frame = nil,
    icon = nil,
    text = nil,
}
local findGroupUnitByGUID
local sendEncounterWarning
local getEncounterChatChannel

local function normalizeInstanceName(name)
    if type(name) ~= "string" then
        return ""
    end
    local lower = string.lower(name)
    lower = string.gsub(lower, "[^%w%s]", "")
    lower = string.gsub(lower, "%s+", " ")
    return string.gsub(lower, "^%s*(.-)%s*$", "%1")
end

local function updateRaidState()
    local instanceName, instanceType, _, _, _, _, _, instanceMapID = GetInstanceInfo()
    local isInRaidInstance = instanceType == "raid"
    local normalizedName = normalizeInstanceName(instanceName)
    local isInMagtheridonsLair = isInRaidInstance and (
        instanceMapID == MAGTHERIDONS_LAIR_MAP_ID
        or normalizedName == "magtheridons lair"
    )
    local isInKarazhan = isInRaidInstance and (
        instanceMapID == KARAZHAN_MAP_ID
        or normalizedName == "karazhan"
    )
    local enteredRaidInstance = isInRaidInstance and not raidState.isInRaidInstance

    raidState.isInRaidInstance = isInRaidInstance
    raidState.isInMagtheridonsLair = isInMagtheridonsLair
    raidState.isInKarazhan = isInKarazhan
    raidState.justEnteredRaidInstance = enteredRaidInstance
    raidState.instanceName = instanceName
    raidState.instanceMapID = instanceMapID

    return enteredRaidInstance
end

function Altank_IsInRaidInstance()
    return raidState.isInRaidInstance
end

function Altank_IsInMagtheridonsLair()
    return raidState.isInMagtheridonsLair
end

function Altank_ConsumeRaidEnterFlag()
    local entered = raidState.justEnteredRaidInstance
    raidState.justEnteredRaidInstance = false
    return entered
end

local function parseNpcIDFromGUID(guid)
    if type(guid) ~= "string" or guid == "" then
        return nil
    end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then
        return nil
    end
    return tonumber(npcID)
end

local function isPrinceByName(name)
    local normalized = normalizeInstanceName(name)
    return normalized == "prince malchezaar" or normalized == "prince malchazar"
end

local function isPrinceByGUID(guid)
    return parseNpcIDFromGUID(guid) == PRINCE_MALCHEZAAR_NPC_ID
end

local function isMoroesByName(name)
    local normalized = normalizeInstanceName(name)
    return normalized == "moroes"
end

local function isMoroesByGUID(guid)
    return parseNpcIDFromGUID(guid) == MOROES_NPC_ID
end

local function isMagtheridonByName(name)
    local normalized = normalizeInstanceName(name)
    return normalized == "magtheridon"
end

local function isMagtheridonByGUID(guid)
    return parseNpcIDFromGUID(guid) == MAGTHERIDON_NPC_ID
end

local function isNetherspiteByName(name)
    local normalized = normalizeInstanceName(name)
    return normalized == "netherspite"
end

local function isNetherspiteByGUID(guid)
    return parseNpcIDFromGUID(guid) == NETHERSPITE_NPC_ID
end

local function isNetherspiteRedBeamAura(spellID, spellName)
    if tonumber(spellID) == NETHER_PORTAL_PERSEVERENCE_SPELL_ID or tonumber(spellID) == NETHER_PORTAL_PERSEVERENCE_ALT_SPELL_ID then
        return true
    end
    local normalized = normalizeInstanceName(spellName)
    if normalized == normalizeInstanceName(NETHER_PORTAL_PERSEVERENCE_NAME) then
        return true
    end
    return string.find(normalized, "nether portal", 1, true) ~= nil
        and string.find(normalized, "persever", 1, true) ~= nil
end

local function isNetherspiteGreenBeamAura(spellID, spellName)
    if tonumber(spellID) == NETHER_PORTAL_SERENITY_SPELL_ID then
        return true
    end
    local normalized = normalizeInstanceName(spellName)
    if normalized == normalizeInstanceName(NETHER_PORTAL_SERENITY_NAME) then
        return true
    end
    return string.find(normalized, "nether portal", 1, true) ~= nil
        and string.find(normalized, "seren", 1, true) ~= nil
end

local function isNetherspiteBlueBeamAura(spellID, spellName)
    if tonumber(spellID) == NETHER_PORTAL_DOMINANCE_SPELL_ID then
        return true
    end
    local normalized = normalizeInstanceName(spellName)
    if normalized == normalizeInstanceName(NETHER_PORTAL_DOMINANCE_NAME) then
        return true
    end
    return string.find(normalized, "nether portal", 1, true) ~= nil
        and string.find(normalized, "domin", 1, true) ~= nil
end

local function shortPlayerName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    local short = Ambiguate and Ambiguate(name, "short") or name
    if type(short) == "string" and short ~= "" then
        return short
    end
    return name
end

local function getUnitAuraStacksBySpellIDs(unit, idA, idB)
    if not unit or not UnitExists(unit) or not UnitAura then
        return nil
    end
    for i = 1, 40 do
        local name, _, count, _, _, _, _, _, _, auraSpellID10, auraSpellID11 = UnitAura(unit, i)
        if not name then
            break
        end
        local auraSpellID = (type(auraSpellID11) == "number" and auraSpellID11) or (type(auraSpellID10) == "number" and auraSpellID10)
        if auraSpellID == idA or auraSpellID == idB then
            return tonumber(count) or 1
        end
    end
    return nil
end

local function isShadeOfAranByName(name)
    local normalized = normalizeInstanceName(name)
    return normalized == "shade of aran"
end

local function isShadeOfAranByGUID(guid)
    return parseNpcIDFromGUID(guid) == SHADE_OF_ARAN_NPC_ID
end

local function isMaidenOfVirtueByName(name)
    local normalized = normalizeInstanceName(name)
    return normalized == "maiden of virtue"
end

local function isMaidenOfVirtueByGUID(guid)
    return parseNpcIDFromGUID(guid) == MAIDEN_OF_VIRTUE_NPC_ID
end

local function isIllhoofByName(name)
    local normalized = normalizeInstanceName(name)
    return normalized == "terestian illhoof"
end

local function isIllhoofByGUID(guid)
    return parseNpcIDFromGUID(guid) == TERESTIAN_ILLHOOF_NPC_ID
end

local function isUnitMatch(unit, byGUID, byName)
    if not unit or not UnitExists(unit) then
        return false
    end
    if byGUID(UnitGUID(unit)) then
        return true
    end
    return byName(UnitName(unit))
end

local function findMatchingUnit(byGUID, byName)
    if isUnitMatch("target", byGUID, byName) then
        return "target"
    end
    if isUnitMatch("focus", byGUID, byName) then
        return "focus"
    end
    if isUnitMatch("mouseover", byGUID, byName) then
        return "mouseover"
    end
    for i = 1, 5 do
        local bossUnit = "boss" .. i
        if isUnitMatch(bossUnit, byGUID, byName) then
            return bossUnit
        end
    end
    for i = 1, 40 do
        local nameplateUnit = "nameplate" .. i
        if isUnitMatch(nameplateUnit, byGUID, byName) then
            return nameplateUnit
        end
    end
    return nil
end

local function ensureCenterUI()
    if centerUI.frame and centerUI.text then
        return true
    end

    local frame = CreateFrame("Frame", "AltankEncounterCenterWarning", UIParent)
    frame:SetSize(800, 80)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:Hide()

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetTextColor(1, 0.82, 0, 1)
    text:SetFont(STANDARD_TEXT_FONT, 26, "OUTLINE")

    centerUI.frame = frame
    centerUI.text = text
    return true
end

local function ensureNetherspiteUI()
    if netherspiteUI.frame and netherspiteUI.redIcon and netherspiteUI.redStacks and netherspiteUI.greenTarget and netherspiteUI.blueTarget then
        return true
    end

    local point, relativePoint, xOfs, yOfs = "CENTER", "CENTER", 0, 165
    if type(AltankDB) == "table" and type(AltankDB.netherspiteFramePoint) == "table" then
        local saved = AltankDB.netherspiteFramePoint
        if type(saved.point) == "string" and saved.point ~= "" then
            point = saved.point
        end
        if type(saved.relativePoint) == "string" and saved.relativePoint ~= "" then
            relativePoint = saved.relativePoint
        end
        if type(saved.x) == "number" then
            xOfs = saved.x
        end
        if type(saved.y) == "number" then
            yOfs = saved.y
        end
    end

    local frame = CreateFrame("Frame", "AltankNetherspiteStackTracker", UIParent, "BackdropTemplate")
    frame:SetSize(238, 98)
    frame:SetPoint(point, UIParent, relativePoint, xOfs, yOfs)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.7)
    frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.9)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint(1)
        if type(AltankDB) ~= "table" then
            AltankDB = {}
        end
        AltankDB.netherspiteFramePoint = {
            point = p or "CENTER",
            relativePoint = rp or "CENTER",
            x = x or 0,
            y = y or 0,
        }
    end)
    frame:Hide()

    local function createBeamBlock(anchorX, spellID, defaultIcon, borderR, borderG, borderB)
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(62, 62)
        icon:SetPoint("TOPLEFT", frame, "TOPLEFT", anchorX, -8)
        icon:SetTexture((GetSpellTexture and GetSpellTexture(spellID)) or defaultIcon)

        local border = frame:CreateTexture(nil, "OVERLAY")
        border:SetPoint("TOPLEFT", icon, "TOPLEFT", -5, 5)
        border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 5, -5)
        border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        border:SetTexCoord(0, 1, 0, 1)
        border:SetVertexColor(borderR, borderG, borderB, 0.95)

        return icon
    end

    local redIcon = createBeamBlock(10, NETHER_PORTAL_PERSEVERENCE_SPELL_ID, "Interface\\Icons\\Spell_Shadow_Shadesofdarkness", 1, 0.2, 0.2)
    local greenIcon = createBeamBlock(88, NETHER_PORTAL_SERENITY_SPELL_ID, "Interface\\Icons\\Spell_Nature_HealingWaveLesser", 0.2, 1, 0.2)
    local blueIcon = createBeamBlock(166, NETHER_PORTAL_DOMINANCE_SPELL_ID, "Interface\\Icons\\Spell_Frost_FrostWard", 0.2, 0.45, 1)

    local redStacks = frame:CreateFontString(nil, "OVERLAY")
    redStacks:SetPoint("CENTER", redIcon, "CENTER", 0, 0)
    redStacks:SetJustifyH("CENTER")
    redStacks:SetTextColor(1, 1, 1, 1)
    redStacks:SetFont(STANDARD_TEXT_FONT, 28, "OUTLINE")
    redStacks:SetText("")

    local greenTarget = frame:CreateFontString(nil, "OVERLAY")
    greenTarget:SetPoint("TOP", greenIcon, "BOTTOM", 0, -4)
    greenTarget:SetJustifyH("CENTER")
    greenTarget:SetTextColor(0.2, 1, 0.2, 1)
    greenTarget:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    greenTarget:SetText("")

    local blueTarget = frame:CreateFontString(nil, "OVERLAY")
    blueTarget:SetPoint("TOP", blueIcon, "BOTTOM", 0, -4)
    blueTarget:SetJustifyH("CENTER")
    blueTarget:SetTextColor(0.2, 0.6, 1, 1)
    blueTarget:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    blueTarget:SetText("")

    netherspiteUI.frame = frame
    netherspiteUI.redIcon = redIcon
    netherspiteUI.redStacks = redStacks
    netherspiteUI.greenIcon = greenIcon
    netherspiteUI.greenTarget = greenTarget
    netherspiteUI.blueIcon = blueIcon
    netherspiteUI.blueTarget = blueTarget
    return true
end

local function hideNetherspiteTracker()
    if netherspiteUI.frame then
        netherspiteUI.frame:Hide()
    end
end

local function printEncounterConsole(message)
    if type(message) ~= "string" or message == "" then
        return
    end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100[Altank]|r " .. message)
    end
end

local function classColorHexByToken(classToken)
    if classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
        local c = RAID_CLASS_COLORS[classToken]
        return string.format("%02x%02x%02x", (c.r or 1) * 255, (c.g or 1) * 255, (c.b or 1) * 255)
    end
    return "ffffff"
end

local function isMindExhaustion(spellID, spellName)
    return tonumber(spellID) == MIND_EXHAUSTION_SPELL_ID or spellName == MIND_EXHAUSTION_NAME
end

local function isShadowGrasp(spellID, spellName)
    if tonumber(spellID) == SHADOW_GRASP_SPELL_ID then
        return true
    end
    if type(spellName) == "string" and spellName ~= "" then
        local normalized = normalizeInstanceName(spellName)
        return normalized == normalizeInstanceName(SHADOW_GRASP_NAME) or normalized == "shadow grasp"
    end
    return false
end

local function isBlastNova(spellID, spellName)
    if spellID and spellID == BLAST_NOVA_SPELL_ID then
        return true
    end
    if type(spellName) == "string" and spellName ~= "" then
        return normalizeInstanceName(spellName) == normalizeInstanceName(BLAST_NOVA_NAME) or normalizeInstanceName(spellName) == "blast nova"
    end
    return false
end

local function resolveClassTokenByGUID(guid)
    local unit = findGroupUnitByGUID(guid)
    if not unit then
        return nil
    end
    local _, classToken = UnitClass(unit)
    return classToken
end

local function ensureMagCubeUI()
    if cubeUI.frame and cubeUI.title then
        return true
    end

    local point, relativePoint, xOfs, yOfs = "CENTER", "CENTER", 430, 30
    if type(AltankDB) == "table" and type(AltankDB.magCubeFramePoint) == "table" then
        local saved = AltankDB.magCubeFramePoint
        if type(saved.point) == "string" and saved.point ~= "" then
            point = saved.point
        end
        if type(saved.relativePoint) == "string" and saved.relativePoint ~= "" then
            relativePoint = saved.relativePoint
        end
        if type(saved.x) == "number" then
            xOfs = saved.x
        end
        if type(saved.y) == "number" then
            yOfs = saved.y
        end
    end

    local frame = CreateFrame("Frame", "AltankMagCubeTracker", UIParent, "BackdropTemplate")
    frame:SetSize(260, 168)
    frame:SetPoint(point, UIParent, relativePoint, xOfs, yOfs)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint(1)
        if p and rp and x and y then
            AltankDB = AltankDB or {}
            AltankDB.magCubeFramePoint = {
                point = p,
                relativePoint = rp,
                x = x,
                y = y,
            }
        end
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.78)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
    title:SetJustifyH("LEFT")
    title:SetTextColor(1, 0.84, 0, 1)
    title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    title:SetText("Mag Cubes (0/5)")

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -8)
    icon:SetTexture((GetSpellTexture and GetSpellTexture(BLAST_NOVA_SPELL_ID)) or "Interface\\Icons\\Spell_Fire_SelfDestruct")

    local countdownText = frame:CreateFontString(nil, "OVERLAY")
    countdownText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -48, -10)
    countdownText:SetJustifyH("CENTER")
    countdownText:SetTextColor(1, 0.82, 0, 1)
    countdownText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    countdownText:SetText("")

    cubeUI.frame = frame
    cubeUI.title = title
    cubeUI.icon = icon
    cubeUI.countdownText = countdownText
    for i = 1, 8 do
        local row = frame:CreateFontString(nil, "OVERLAY")
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -14 - (i * 17))
        row:SetJustifyH("LEFT")
        row:SetTextColor(1, 1, 1, 1)
        row:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
        row:SetText("")
        cubeUI.rows[i] = row
    end
    return true
end

local function hideMagCubeTracker()
    if cubeUI.frame then
        cubeUI.frame:Hide()
    end
end

local function ensureMagBlastUI()
    if magBlastUI.frame and magBlastUI.icon and magBlastUI.text then
        return true
    end

    local frame = CreateFrame("Frame", "AltankMagBlastNovaTimer", UIParent, "BackdropTemplate")
    frame:SetSize(86, 86)
    frame:SetPoint("CENTER", UIParent, "CENTER", 330, 30)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.82)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.95)
    frame:Hide()

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(52, 52)
    icon:SetPoint("TOP", frame, "TOP", 0, -8)
    icon:SetTexture((GetSpellTexture and GetSpellTexture(BLAST_NOVA_SPELL_ID)) or "Interface\\Icons\\Spell_Fire_SelfDestruct")

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("BOTTOM", frame, "BOTTOM", 0, 8)
    text:SetFont(STANDARD_TEXT_FONT, 22, "OUTLINE")
    text:SetTextColor(1, 0.82, 0, 1)
    text:SetText("")

    magBlastUI.frame = frame
    magBlastUI.icon = icon
    magBlastUI.text = text
    return true
end

local function hideMagBlastUI()
    if magBlastUI.frame then
        magBlastUI.frame:Hide()
    end
end

local function stopMagBlastTicker()
    if magState.blastTicker then
        magState.blastTicker:Cancel()
        magState.blastTicker = nil
    end
end

local function updateMagBlastCycleTimer()
    if not raidState.isInMagtheridonsLair or not magState.engaged then
        if cubeUI.countdownText then
            cubeUI.countdownText:SetText("")
        end
        if cubeUI.icon then
            cubeUI.icon:Hide()
        end
        return
    end
    if not magState.blastNextAt or magState.blastNextAt <= 0 then
        if cubeUI.countdownText then
            cubeUI.countdownText:SetText("")
        end
        if cubeUI.icon then
            cubeUI.icon:Hide()
        end
        return
    end

    local now = GetTime() or 0
    local remaining = math.ceil((magState.blastNextAt or 0) - now)
    if remaining <= 0 then
        magState.blastNextAt = 0
        magState.blastWarnedAt6 = false
        if cubeUI.countdownText then
            cubeUI.countdownText:SetText("")
        end
        if cubeUI.icon then
            cubeUI.icon:Hide()
        end
        return
    end

    if ensureMagCubeUI() then
        if cubeUI.countdownText then
            cubeUI.countdownText:SetText(tostring(remaining))
        end
        if cubeUI.icon then
            cubeUI.icon:Show()
        end
    end

    if remaining <= 11 and not magState.blastWarnedAt6 then
        magState.blastWarnedAt6 = true
        sendEncounterWarning("ready cube.", 1.5)
    end
end

local function startMagBlastCycleTimer()
    magState.blastNextAt = (GetTime() or 0) + 60
    magState.blastWarnedAt6 = false
    updateMagBlastCycleTimer()
    if not magState.blastTicker then
        magState.blastTicker = C_Timer.NewTicker(0.2, function()
            updateMagBlastCycleTimer()
        end)
    end
end

local function getActiveCubeHoldersList()
    local holders = {}
    for guid, holder in pairs(cubeState.activeHolders) do
        if type(holder) == "table" and holder.name and holder.name ~= "" then
            local classToken = holder.classToken or resolveClassTokenByGUID(guid)
            if classToken then
                holder.classToken = classToken
            end
            holders[#holders + 1] = holder
        end
    end
    table.sort(holders, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
    return holders
end

local function refreshMagCubeTracker()
    local holders = getActiveCubeHoldersList()
    local shouldShow = raidState.isInMagtheridonsLair and (magState.engaged or cubeState.blastAttempt.active or #holders > 0)
    if not shouldShow then
        hideMagCubeTracker()
        return
    end
    if not ensureMagCubeUI() then
        return
    end

    cubeUI.title:SetText(string.format("Mag Cubes (%d/%d)", #holders, MAG_CUBE_REQUIRED_PLAYERS))
    for i = 1, #cubeUI.rows do
        local row = cubeUI.rows[i]
        local holder = holders[i]
        if holder then
            local hex = classColorHexByToken(holder.classToken)
            local guid = holder.guid
            local tag = ""
            local participant = guid and cubeState.blastAttempt.participants[guid] or nil
            if participant and participant.late then
                tag = " |cffff5555(late)|r"
            end
            row:SetText("|cff" .. hex .. holder.name .. "|r" .. tag)
        else
            row:SetText("")
        end
    end
    cubeUI.frame:Show()
end

local function stopMagCubeResolveTimer()
    local blast = cubeState.blastAttempt
    if blast.resolveTimer then
        blast.resolveTimer:Cancel()
        blast.resolveTimer = nil
    end
end

local function resetMagCubeBlastAttempt()
    stopMagCubeResolveTimer()
    cubeState.blastAttempt.active = false
    cubeState.blastAttempt.startAt = 0
    cubeState.blastAttempt.participants = {}
end

local function resetMagCubeState()
    resetMagCubeBlastAttempt()
    cubeState.activeHolders = {}
    refreshMagCubeTracker()
end

local function countParticipants(participants)
    local count = 0
    for _ in pairs(participants) do
        count = count + 1
    end
    return count
end

local function countActiveCubeHolders()
    local count = 0
    for _ in pairs(cubeState.activeHolders) do
        count = count + 1
    end
    return count
end

local function collectParticipantNames(participants, key)
    local names = {}
    for _, p in pairs(participants) do
        if p and p.name and p[key] then
            names[#names + 1] = p.name
        end
    end
    table.sort(names)
    return names
end

local function finishMagCubeBlastAttempt(wentOff)
    local blast = cubeState.blastAttempt
    if not blast.active then
        return
    end

    stopMagCubeResolveTimer()
    local participantCount = countParticipants(blast.participants)
    local early = collectParticipantNames(blast.participants, "early")
    local late = collectParticipantNames(blast.participants, "late")

    if wentOff then
        local message = string.format("Blast Nova went off. Cubes: %d/%d.", participantCount, MAG_CUBE_REQUIRED_PLAYERS)
        if #early > 0 then
            message = message .. " Early cancel: " .. table.concat(early, ", ") .. "."
        end
        if #late > 0 then
            message = message .. " Late: " .. table.concat(late, ", ") .. "."
        end
        printEncounterConsole(message)
    elseif participantCount < MAG_CUBE_REQUIRED_PLAYERS or #early > 0 then
        local message = string.format("Cube timing issue: %d/%d clicked for Blast Nova.", participantCount, MAG_CUBE_REQUIRED_PLAYERS)
        if #early > 0 then
            message = message .. " Early cancel: " .. table.concat(early, ", ") .. "."
        end
        if #late > 0 then
            message = message .. " Late: " .. table.concat(late, ", ") .. "."
        end
        printEncounterConsole(message)
    end

    resetMagCubeBlastAttempt()
    refreshMagCubeTracker()
end

local function addMagCubeHolder(guid, name)
    if type(guid) ~= "string" or guid == "" then
        return
    end
    local shortName = Ambiguate(name or "Unknown", "short")
    cubeState.activeHolders[guid] = {
        guid = guid,
        name = shortName,
        classToken = resolveClassTokenByGUID(guid),
        startAt = GetTime() or 0,
    }

    local blast = cubeState.blastAttempt
    if blast.active then
        local participant = blast.participants[guid]
        if not participant then
            participant = {
                guid = guid,
                name = shortName,
                appliedAt = GetTime() or 0,
                late = false,
                early = false,
            }
            blast.participants[guid] = participant
        end
        local elapsed = (GetTime() or 0) - (blast.startAt or 0)
        if elapsed > MAG_LATE_CLICK_THRESHOLD then
            participant.late = true
        end
    end

    refreshMagCubeTracker()
end

local function removeMagCubeHolder(guid)
    if type(guid) ~= "string" or guid == "" then
        return
    end
    cubeState.activeHolders[guid] = nil
    local blast = cubeState.blastAttempt
    if blast.active and blast.participants[guid] then
        if countActiveCubeHolders() < MAG_CUBE_REQUIRED_PLAYERS then
            blast.participants[guid].early = true
        end
    end
    refreshMagCubeTracker()
end

local function startMagCubeBlastAttempt()
    local blast = cubeState.blastAttempt
    resetMagCubeBlastAttempt()

    blast.sequence = (blast.sequence or 0) + 1
    local sequence = blast.sequence
    blast.active = true
    blast.startAt = GetTime() or 0
    blast.participants = {}

    for guid, holder in pairs(cubeState.activeHolders) do
        blast.participants[guid] = {
            guid = guid,
            name = holder.name,
            appliedAt = holder.startAt or blast.startAt,
            late = false,
            early = false,
        }
    end

    sendEncounterWarning("click now")
    C_Timer.After(0.4, function()
        if cubeState.blastAttempt.active and cubeState.blastAttempt.sequence == sequence then
            sendEncounterWarning("click now")
        end
    end)

    blast.resolveTimer = C_Timer.NewTimer(MAG_BLAST_CAST_WINDOW, function()
        if cubeState.blastAttempt.active and cubeState.blastAttempt.sequence == sequence then
            finishMagCubeBlastAttempt(false)
        end
    end)
    refreshMagCubeTracker()
end

local function handleMagtheridonCubeCombatLog(subEvent, sourceGUID, sourceName, destGUID, destName, spellID, spellName)
    if not raidState.isInMagtheridonsLair then
        return
    end

    if isShadowGrasp(spellID, spellName) then
        if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_APPLIED_DOSE" or subEvent == "SPELL_AURA_REFRESH" then
            addMagCubeHolder(destGUID, destName)
            return
        end
        if subEvent == "SPELL_AURA_REMOVED" then
            removeMagCubeHolder(destGUID)
            return
        end
    end

    if not isMagtheridonByGUID(sourceGUID) and not isMagtheridonByName(sourceName) then
        return
    end

    if subEvent == "SPELL_CAST_START" and isBlastNova(spellID, spellName) then
        startMagCubeBlastAttempt()
        startMagBlastCycleTimer()
        return
    end
    if (subEvent == "SPELL_CAST_SUCCESS" or subEvent == "SPELL_DAMAGE") and isBlastNova(spellID, spellName) then
        finishMagCubeBlastAttempt(true)
        return
    end
    if subEvent == "SPELL_INTERRUPT" and destGUID and isMagtheridonByGUID(destGUID) and isBlastNova(spellID, spellName) then
        finishMagCubeBlastAttempt(false)
        return
    end
end

local function updateNetherspiteTracker(stacks)
    if not ensureNetherspiteUI() then
        return
    end

    local redStacks = tonumber(stacks) or 0
    local greenName = netherspiteState.greenBeamTargetName
    local blueName = netherspiteState.blueBeamTargetName
    local blueStacks = tonumber(netherspiteState.blueBeamTargetStacks) or 0
    local hasGreenTarget = type(greenName) == "string" and greenName ~= ""
    local hasBlueTarget = type(blueName) == "string" and blueName ~= ""
    local hasAnyData = redStacks > 0 or hasGreenTarget or hasBlueTarget

    if not hasAnyData then
        hideNetherspiteTracker()
        return
    end

    netherspiteUI.redStacks:SetText(redStacks > 0 and tostring(redStacks) or "")
    netherspiteUI.greenTarget:SetText(hasGreenTarget and greenName or "")
    netherspiteUI.blueTarget:SetText(hasBlueTarget and blueName or "")
    if hasBlueTarget and blueStacks >= NETHERSPITE_BLUE_STACK_DANGER_THRESHOLD then
        netherspiteUI.blueTarget:SetTextColor(1, 0.2, 0.2, 1)
    else
        netherspiteUI.blueTarget:SetTextColor(0.2, 0.6, 1, 1)
    end
    netherspiteUI.frame:Show()
end

local function showCenterWarning(message, durationSeconds)
    if type(message) ~= "string" or message == "" or not ensureCenterUI() then
        return
    end
    centerUI.text:SetText(message)
    centerUI.frame:Show()
    if princeState.centerHideTicker then
        princeState.centerHideTicker:Cancel()
        princeState.centerHideTicker = nil
    end
    local duration = (type(durationSeconds) == "number" and durationSeconds > 0) and durationSeconds or 0.9
    princeState.centerHideTicker = C_Timer.NewTimer(duration, function()
        if centerUI.frame then
            centerUI.frame:Hide()
        end
        princeState.centerHideTicker = nil
    end)
end

local function sendRaidWarning(message)
    local prefixedMessage = "|cffffd100[Altank]|r " .. message
    if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] then
        RaidNotice_AddMessage(RaidWarningFrame, prefixedMessage, ChatTypeInfo["RAID_WARNING"])
    end
    if SendChatMessage then
        local canSendRaidWarning = (IsInRaid and IsInRaid()) and (
            (UnitIsGroupLeader and UnitIsGroupLeader("player"))
            or (UnitIsGroupAssistant and UnitIsGroupAssistant("player"))
        )
        if canSendRaidWarning then
            SendChatMessage("[Altank] " .. message, "RAID_WARNING")
        else
            local channel = getEncounterChatChannel()
            if channel then
                SendChatMessage("[Altank] " .. message, channel)
            end
        end
    end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(prefixedMessage)
    end
end

getEncounterChatChannel = function()
    if IsInRaid(LE_PARTY_CATEGORY_HOME) then
        return "RAID"
    end
    if IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return "PARTY"
    end
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    return nil
end

local function sendEncounterChat(message)
    if type(message) ~= "string" or message == "" or not SendChatMessage then
        return
    end

    local channel = getEncounterChatChannel()
    if channel then
        SendChatMessage("[Altank] " .. message, channel)
    end
end

sendEncounterWarning = function(message, durationSeconds)
    sendRaidWarning(message)
end

local function sendNetherspiteWarning(message)
    if type(message) ~= "string" or message == "" then
        return
    end
    showCenterWarning(message, 1.2)
end

local function isFlameWreath(spellID, spellName)
    if tonumber(spellID) == FLAME_WREATH_SPELL_ID then
        return true
    end
    local normalized = normalizeInstanceName(spellName)
    return normalized == normalizeInstanceName(FLAME_WREATH_NAME) or normalized == "flame wreath"
end

local function maybeWarnAranFlameWreath(subEvent, sourceGUID, sourceName, spellID, spellName)
    if subEvent ~= "SPELL_CAST_START" then
        return
    end
    if not (isShadeOfAranByGUID(sourceGUID) or isShadeOfAranByName(sourceName)) then
        return
    end
    if not isFlameWreath(spellID, spellName) then
        return
    end
    local now = GetTime and GetTime() or 0
    if (now - (aranState.lastFlameWreathWarnAt or 0)) < 2 then
        return
    end
    aranState.engaged = true
    aranState.lastFlameWreathWarnAt = now
    sendEncounterWarning("Flame Wreath - DO NOT MOVE", 2.5)
    if C_Timer and C_Timer.After then
        C_Timer.After(1.0, function()
            sendEncounterWarning("Flame Wreath - DO NOT MOVE", 2.5)
        end)
    else
        sendEncounterWarning("Flame Wreath - DO NOT MOVE", 2.5)
    end
end

local function maybeWarnMaidenRepentance(subEvent, sourceGUID, sourceName, spellID, spellName)
    if not raidState.isInKarazhan then
        return
    end
    if subEvent ~= "SPELL_CAST_START" then
        return
    end
    if not (isMaidenOfVirtueByGUID(sourceGUID) or isMaidenOfVirtueByName(sourceName)) then
        return
    end

    local isRepentance = tonumber(spellID) == REPENTANCE_SPELL_ID
        or spellName == REPENTANCE_NAME
        or normalizeInstanceName(spellName) == "repentance"
    if not isRepentance then
        return
    end

    local now = GetTime and GetTime() or 0
    if (now - (maidenState.lastRepentanceWarnAt or 0)) < 1.5 then
        return
    end

    maidenState.engaged = true
    maidenState.lastRepentanceWarnAt = now
    sendEncounterWarning("move in", 2)
end

local function maybeWarnIllhoofSacrifice(subEvent, sourceGUID, sourceName, spellID, spellName)
    if not raidState.isInKarazhan then
        return
    end
    if subEvent ~= "SPELL_CAST_START" then
        return
    end
    if not (isIllhoofByGUID(sourceGUID) or isIllhoofByName(sourceName)) then
        return
    end

    local isSacrifice = tonumber(spellID) == SACRIFICE_SPELL_ID
        or spellName == SACRIFICE_NAME
        or normalizeInstanceName(spellName) == "sacrifice"
    if not isSacrifice then
        return
    end

    local now = GetTime and GetTime() or 0
    if (now - (illhoofState.lastSacrificeWarnAt or 0)) < 1.5 then
        return
    end

    illhoofState.engaged = true
    illhoofState.lastSacrificeWarnAt = now
    sendEncounterWarning("kill the chain now.", 2)
    sendEncounterChat("kill the chain now.")
end

local function isPlayerTankRole()
    if UnitGroupRolesAssigned then
        local role = UnitGroupRolesAssigned("player")
        if role and role ~= "NONE" then
            return role == "TANK"
        end
    end
    return false
end

local function forEachGroupUnit(callback)
    if type(callback) ~= "function" then
        return
    end

    callback("player")

    if IsInRaid() then
        local count = GetNumGroupMembers() or 0
        for i = 1, count do
            callback("raid" .. i)
        end
        return
    end

    if IsInGroup() then
        local count = GetNumSubgroupMembers() or 0
        for i = 1, count do
            callback("party" .. i)
        end
    end
end

findGroupUnitByGUID = function(guid)
    if type(guid) ~= "string" or guid == "" then
        return nil
    end

    local foundUnit = nil
    forEachGroupUnit(function(unit)
        if not foundUnit and unit and UnitExists(unit) and UnitGUID(unit) == guid then
            foundUnit = unit
        end
    end)
    return foundUnit
end

local function isTankRoleUnit(unit)
    if not unit or not UnitExists(unit) then
        return false
    end
    if UnitGroupRolesAssigned then
        local role = UnitGroupRolesAssigned(unit)
        if role == "TANK" then
            return true
        end
    end
    local _, classToken = UnitClass(unit)
    if classToken == "WARRIOR" or classToken == "PALADIN" or classToken == "DRUID" or classToken == "DEATHKNIGHT" then
        return true
    end
    return UnitIsUnit(unit, "player") and isPlayerTankRole()
end

local function getCurrentNetherspiteTankUnit()
    local bossUnit = findMatchingUnit(isNetherspiteByGUID, isNetherspiteByName)
    if not bossUnit then
        return nil
    end

    local bestUnit = nil
    local bestScore = nil
    forEachGroupUnit(function(unit)
        if not unit or not UnitExists(unit) or (UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)) then
            return
        end
        if not isTankRoleUnit(unit) then
            return
        end

        local isTanking, status, scaledPercent, rawPercent, threatValue = UnitDetailedThreatSituation(unit, bossUnit)
        local score = threatValue or rawPercent or scaledPercent or 0
        if isTanking then
            score = score + 1000000
        elseif status then
            score = score + (status * 1000)
        end

        if score > 0 and (not bestScore or score > bestScore) then
            bestScore = score
            bestUnit = unit
        end
    end)

    return bestUnit
end

local function isPlayerCurrentNetherspiteTank()
    local tankUnit = getCurrentNetherspiteTankUnit()
    if not tankUnit or not UnitIsUnit(tankUnit, "player") then
        return false
    end
    local playerGUID = UnitGUID("player")
    return playerGUID and netherspiteState.currentBeamTankGUID and playerGUID == netherspiteState.currentBeamTankGUID
end

local function isPlayerNetherspitePhaseTank()
    local playerGUID = UnitGUID("player")
    return playerGUID and netherspiteState.phaseTankGUID and playerGUID == netherspiteState.phaseTankGUID
end

local function getNextNetherspiteTankUnit(excludedGUID)
    local bossUnit = findMatchingUnit(isNetherspiteByGUID, isNetherspiteByName)
    local bestUnit = nil
    local bestScore = nil
    local fallbackUnit = nil

    forEachGroupUnit(function(unit)
        if not unit or not UnitExists(unit) or not isTankRoleUnit(unit) then
            return
        end
        if (UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)) or UnitGUID(unit) == excludedGUID then
            return
        end

        if not fallbackUnit then
            fallbackUnit = unit
        end

        if not bossUnit then
            return
        end

        local isTanking, status, scaledPercent, rawPercent, threatValue = UnitDetailedThreatSituation(unit, bossUnit)
        local score = threatValue or rawPercent or scaledPercent or 0
        if isTanking then
            score = score + 1000000
        elseif status then
            score = score + (status * 1000)
        end

        if score > 0 and (not bestScore or score > bestScore) then
            bestScore = score
            bestUnit = unit
        end
    end)

    return bestUnit or fallbackUnit
end

local warnNetherspiteNextTankIfNeeded

local function assignNetherspitePhaseTank(unit)
    if not unit or not UnitExists(unit) then
        return
    end
    netherspiteState.redPhaseSequence = (netherspiteState.redPhaseSequence or 0) + 1
    netherspiteState.phaseTankGUID = UnitGUID(unit)
    netherspiteState.phaseTankName = UnitName(unit)
    netherspiteState.warnedMoveOut = false
    netherspiteState.warnedMoveIn = false
end

local function ensureNetherspitePhaseTankAssigned()
    if netherspiteState.currentBeamTankGUID and findGroupUnitByGUID(netherspiteState.currentBeamTankGUID) then
        if not netherspiteState.phaseTankGUID then
            netherspiteState.phaseTankGUID = netherspiteState.currentBeamTankGUID
            netherspiteState.phaseTankName = netherspiteState.currentBeamTankName
            netherspiteState.redPhaseSequence = math.max(1, (netherspiteState.redPhaseSequence or 0))
        end
        return
    end

    if netherspiteState.phaseTankGUID and findGroupUnitByGUID(netherspiteState.phaseTankGUID) then
        return
    end

    local nextTankUnit = getNextNetherspiteTankUnit(netherspiteState.lastPhaseBeamTankGUID)
    if nextTankUnit then
        assignNetherspitePhaseTank(nextTankUnit)
        warnNetherspiteNextTankIfNeeded()
    end
end

local function refreshNetherspiteTracker()
    if not netherspiteState.engaged then
        hideNetherspiteTracker()
        return
    end
    ensureNetherspitePhaseTankAssigned()
    local playerGUID = UnitGUID("player")
    local stacksToShow = 0

    if playerGUID and netherspiteState.currentBeamTankGUID and netherspiteState.currentBeamTankGUID == playerGUID then
        stacksToShow = netherspiteState.playerStacks or 0
    elseif isPlayerNetherspitePhaseTank() and netherspiteState.lastBossHadBuff and (netherspiteState.bossStacks or 0) > 0 then
        stacksToShow = netherspiteState.bossStacks or 0
    end

    updateNetherspiteTracker(stacksToShow)
end

local function getNetherspiteBossRedStacksFromAura()
    local bossUnit = findMatchingUnit(isNetherspiteByGUID, isNetherspiteByName)
    if not bossUnit then
        return nil
    end
    return getUnitAuraStacksBySpellIDs(bossUnit, NETHER_PORTAL_PERSEVERENCE_SPELL_ID, NETHER_PORTAL_PERSEVERENCE_ALT_SPELL_ID)
end

warnNetherspiteNextTankIfNeeded = function()
    if not raidState.isInKarazhan or not netherspiteState.engaged then
        return
    end

    local sequence = netherspiteState.redPhaseSequence or 0
    if sequence <= 0 or netherspiteState.warnedTakeRedSequence == sequence then
        return
    end

    local phaseTankUnit = findGroupUnitByGUID(netherspiteState.phaseTankGUID)
    if not phaseTankUnit or not UnitIsUnit(phaseTankUnit, "player") then
        return
    end

    netherspiteState.warnedTakeRedSequence = sequence
end

local function magCountdownProfileForPlayer()
    local _, classToken = UnitClass("player")
    local isTank = isPlayerTankRole()
    local profile = {
        startSeconds = 10,
        cueAt = nil,
        cueText = nil,
        cueSpellID = nil,
        cancelAfterSeconds = nil,
        cancelText = nil,
        finalText = "Cave In NOW!",
    }

    if classToken == "MAGE" then
        profile.cueAt = 2
        profile.cueText = "Use Ice Block NOW!"
        profile.cueSpellID = ICE_BLOCK_SPELL_ID
        profile.cancelAfterSeconds = 3.5
        profile.cancelText = "Cancel Ice Block"
        return profile
    end

    if isTank and classToken == "PALADIN" then
        profile.startSeconds = 4
        profile.cueAt = 0
        profile.cueText = "Use Bubble NOW!"
        profile.cueSpellID = DIVINE_SHIELD_SPELL_ID
        profile.finalText = nil
        return profile
    end
    if isTank and classToken == "WARRIOR" then
        profile.cueAt = 0
        profile.cueText = "Use Last Stand + Shield Wall NOW!"
        profile.finalText = nil
        return profile
    end
    if isTank and classToken == "DRUID" then
        profile.cueAt = 0
        profile.cueText = "Use Barkskin NOW!"
        profile.finalText = nil
        return profile
    end

    return profile
end

local function spellIconTag(spellID, size)
    if not GetSpellTexture or not spellID then
        return ""
    end
    local icon = GetSpellTexture(spellID)
    if not icon then
        return ""
    end
    return " |T" .. icon .. ":" .. tostring(tonumber(size) or 20) .. "|t"
end

local function stopPrinceWarningTicker()
    if princeState.warningTicker then
        princeState.warningTicker:Cancel()
        princeState.warningTicker = nil
    end
end

local function resetPrinceState()
    stopPrinceWarningTicker()
    if princeState.centerHideTicker then
        princeState.centerHideTicker:Cancel()
        princeState.centerHideTicker = nil
    end
    if centerUI.frame then
        centerUI.frame:Hide()
    end
    princeState.engaged = false
    princeState.warnedAt60 = false
    princeState.notifiedAt30 = false
end

local function stopMagCountdown(invalidateSequence)
    if magState.countdownTicker then
        magState.countdownTicker:Cancel()
        magState.countdownTicker = nil
    end
    if invalidateSequence then
        magState.countdownSequence = (magState.countdownSequence or 0) + 1
    end
end

local function resetMagState()
    stopMagCountdown(true)
    stopMagBlastTicker()
    if cubeUI.countdownText then
        cubeUI.countdownText:SetText("")
    end
    if cubeUI.icon then
        cubeUI.icon:Hide()
    end
    magState.engaged = false
    magState.triggeredAt30 = false
    magState.blastNextAt = 0
    magState.blastWarnedAt6 = false
    resetMagCubeState()
end

local function resetNetherspiteState()
    netherspiteState.engaged = false
    netherspiteState.bossStacks = 0
    netherspiteState.playerStacks = 0
    netherspiteState.lastBossHadBuff = false
    netherspiteState.phaseTankGUID = nil
    netherspiteState.phaseTankName = nil
    netherspiteState.currentBeamTankGUID = nil
    netherspiteState.currentBeamTankName = nil
    netherspiteState.lastPhaseBeamTankGUID = nil
    netherspiteState.lastPhaseBeamTankName = nil
    netherspiteState.redPhaseSequence = 0
    netherspiteState.warnedTakeRedSequence = 0
    netherspiteState.warnedMoveOut = false
    netherspiteState.warnedMoveIn = false
    netherspiteState.greenBeamTargetGUID = nil
    netherspiteState.greenBeamTargetName = nil
    netherspiteState.blueBeamTargetGUID = nil
    netherspiteState.blueBeamTargetName = nil
    netherspiteState.blueBeamTargetStacks = 0
    hideNetherspiteTracker()
end

local function handleNetherspiteBeamTarget(color, stacks, hadBuff, destGUID, destName)
    local shortName = shortPlayerName(destName)
    if color == "green" then
        if hadBuff then
            netherspiteState.greenBeamTargetGUID = destGUID
            netherspiteState.greenBeamTargetName = shortName or netherspiteState.greenBeamTargetName
        elseif destGUID and netherspiteState.greenBeamTargetGUID == destGUID then
            netherspiteState.greenBeamTargetGUID = nil
            netherspiteState.greenBeamTargetName = nil
        end
        refreshNetherspiteTracker()
        return
    end

    if color == "blue" then
        if hadBuff then
            netherspiteState.blueBeamTargetGUID = destGUID
            netherspiteState.blueBeamTargetName = shortName or netherspiteState.blueBeamTargetName
            netherspiteState.blueBeamTargetStacks = tonumber(stacks) or 1
        elseif destGUID and netherspiteState.blueBeamTargetGUID == destGUID then
            netherspiteState.blueBeamTargetGUID = nil
            netherspiteState.blueBeamTargetName = nil
            netherspiteState.blueBeamTargetStacks = 0
        end
        refreshNetherspiteTracker()
    end
end

local function resetMoroesState()
    moroesState.engaged = false
    moroesState.lastWarnAt = 0
end

local function resetAranState()
    aranState.engaged = false
    aranState.lastFlameWreathWarnAt = 0
end

local function resetMaidenState()
    maidenState.engaged = false
    maidenState.lastRepentanceWarnAt = 0
end

local function resetIllhoofState()
    illhoofState.engaged = false
    illhoofState.lastSacrificeWarnAt = 0
end

local function showDot(color)
    if color == "red" then
        showCenterWarning("|cffff0000●|r", 0.8)
        return
    end
    if color == "green" then
        showCenterWarning("|cff00ff00●|r", 0.8)
    end
end

local function handleNetherspiteStacks(isBoss, stacks, hadBuff, destGUID, destName)
    if not raidState.isInKarazhan then
        return
    end
    if isBoss then
        local lastHad = netherspiteState.lastBossHadBuff
        netherspiteState.bossStacks = stacks or 0
        netherspiteState.lastBossHadBuff = hadBuff
        if not lastHad and hadBuff then
            local playerNeedsMoveIn = isPlayerNetherspitePhaseTank() or isPlayerCurrentNetherspiteTank()
            if playerNeedsMoveIn then
                showDot("red")
                sendNetherspiteWarning("move in red.")
            end
        end
        refreshNetherspiteTracker()
        if lastHad and not hadBuff then
            local playerGUID = UnitGUID("player")
            local wasPlayerBeamTank = playerGUID and netherspiteState.currentBeamTankGUID and playerGUID == netherspiteState.currentBeamTankGUID
            local wasPlayerPhaseTank = isPlayerNetherspitePhaseTank()
            netherspiteState.phaseTankGUID = nil
            netherspiteState.phaseTankName = nil
            netherspiteState.lastPhaseBeamTankGUID = netherspiteState.currentBeamTankGUID
            netherspiteState.lastPhaseBeamTankName = netherspiteState.currentBeamTankName
            netherspiteState.currentBeamTankGUID = nil
            netherspiteState.currentBeamTankName = nil
            if wasPlayerBeamTank or wasPlayerPhaseTank then
                showDot("green")
                sendNetherspiteWarning("move out of red.")
            end
            refreshNetherspiteTracker()
        end
        return
    end

    local destUnit = findGroupUnitByGUID(destGUID)
    if hadBuff and destUnit and isTankRoleUnit(destUnit) then
        if not netherspiteState.phaseTankGUID then
            assignNetherspitePhaseTank(destUnit)
        end
        netherspiteState.currentBeamTankGUID = destGUID
        netherspiteState.currentBeamTankName = destName
    elseif not hadBuff and destGUID and netherspiteState.currentBeamTankGUID == destGUID then
        netherspiteState.currentBeamTankGUID = nil
        netherspiteState.currentBeamTankName = nil
    end

    if destGUID and destGUID == UnitGUID("player") then
        netherspiteState.playerStacks = stacks or 0
    end

    refreshNetherspiteTracker()
end

local function startPrinceCDWarning()
    stopPrinceWarningTicker()
    sendEncounterWarning("Prince 60%: USE CDS NOW!")
end

local function evaluatePrinceThresholds()
    if not raidState.isInKarazhan then
        resetPrinceState()
        return
    end

    local princeUnit = findMatchingUnit(isPrinceByGUID, isPrinceByName)
    if not princeUnit then
        return
    end
    if UnitIsDead(princeUnit) then
        resetPrinceState()
        return
    end

    if UnitAffectingCombat(princeUnit) then
        princeState.engaged = true
    end
    if not princeState.engaged then
        return
    end

    local maxHealth = UnitHealthMax(princeUnit) or 0
    if maxHealth <= 0 then
        return
    end
    local healthPct = ((UnitHealth(princeUnit) or 0) / maxHealth) * 100

    if not princeState.warnedAt60 and healthPct <= 60 then
        princeState.warnedAt60 = true
        startPrinceCDWarning()
    end
    if not princeState.notifiedAt30 and healthPct <= 30 then
        princeState.notifiedAt30 = true
        sendEncounterWarning("Prince 30%: safe now.")
    end
end

local function startMagCountdown()
    stopMagCountdown(true)
    local sequence = magState.countdownSequence or 0
    local profile = magCountdownProfileForPlayer()
    local remaining = tonumber(profile.startSeconds) or 10
    sendEncounterWarning(string.format("Cave In in %d", remaining))
    magState.countdownTicker = C_Timer.NewTicker(1, function()
        if (magState.countdownSequence or 0) ~= sequence then
            return
        end
        remaining = remaining - 1
        if remaining > 0 then
            if profile.cueAt and remaining == profile.cueAt and profile.cueText then
                sendEncounterWarning(tostring(profile.cueText) .. spellIconTag(profile.cueSpellID, 20))
                if profile.cancelAfterSeconds and profile.cancelText and C_Timer and C_Timer.After then
                    local cancelSequence = sequence
                    C_Timer.After(profile.cancelAfterSeconds, function()
                        if (magState.countdownSequence or 0) ~= cancelSequence then
                            return
                        end
                        sendEncounterWarning(tostring(profile.cancelText))
                    end)
                end
                return
            end
            sendEncounterWarning(string.format("Cave In in %d", remaining))
            return
        end
        stopMagCountdown()
        if profile.cueAt == 0 and profile.cueText then
            sendEncounterWarning("Cave In NOW! " .. profile.cueText .. spellIconTag(profile.cueSpellID, 20), 2)
            return
        end
        sendEncounterWarning(tostring(profile.finalText or "Cave In NOW!"))
    end)
end

local function isPlayerDestName(destName)
    local playerName = UnitName("player")
    if not destName or not playerName then
        return false
    end
    return Ambiguate(destName, "short") == Ambiguate(playerName, "short")
end

local function maybeWarnMoroesGouge(subEvent, sourceGUID, sourceName, destGUID, destName, spellID, spellName)
    if not raidState.isInKarazhan then
        return
    end

    if isMoroesByGUID(sourceGUID) or isMoroesByGUID(destGUID) or isMoroesByName(sourceName) or isMoroesByName(destName) then
        moroesState.engaged = true
    end
    if not moroesState.engaged then
        return
    end

    local isGouge = (spellID == GOUGE_SPELL_ID) or (spellName == GOUGE_NAME) or (normalizeInstanceName(spellName) == "gouge")
    if not isGouge then
        return
    end
    if subEvent ~= "SPELL_AURA_APPLIED" and subEvent ~= "SPELL_CAST_SUCCESS" then
        return
    end
    if not isMoroesByGUID(sourceGUID) and not isMoroesByName(sourceName) then
        return
    end
    if not (destGUID and UnitGUID("player") == destGUID) and not isPlayerDestName(destName) then
        return
    end

    local now = GetTime and GetTime() or 0
    if moroesState.lastWarnAt and (now - moroesState.lastWarnAt) < 1.5 then
        return
    end
    moroesState.lastWarnAt = now
    local myName = UnitName("player")
    local shortName = (myName and Ambiguate and Ambiguate(myName, "short")) or myName or "player"
    local warningMessage = "Moroes Gouge on " .. tostring(shortName) .. "."
    local chatMessage = "Moroes Gouge on me."
    sendEncounterWarning(warningMessage, 1.5)
    sendEncounterChat(chatMessage)
end

local function evaluateMagtheridonThresholds()
    if not raidState.isInMagtheridonsLair then
        resetMagState()
        return
    end

    local magUnit = findMatchingUnit(isMagtheridonByGUID, isMagtheridonByName)
    if not magUnit then
        return
    end
    if UnitIsDead(magUnit) then
        resetMagState()
        return
    end

    if UnitAffectingCombat(magUnit) then
        magState.engaged = true
    end
    if not magState.engaged then
        return
    end

    local maxHealth = UnitHealthMax(magUnit) or 0
    if maxHealth <= 0 then
        return
    end
    local healthPct = ((UnitHealth(magUnit) or 0) / maxHealth) * 100
    if magState.triggeredAt30 or healthPct > 30 then
        return
    end

    magState.triggeredAt30 = true
    startMagCountdown()
end

function Altank_HandleRaidEncounterFeatures(event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "GROUP_ROSTER_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" or event == "NAME_PLATE_UNIT_ADDED" then
        updateRaidState()
        if not raidState.isInKarazhan then
            resetPrinceState()
            resetNetherspiteState()
            resetMoroesState()
            resetAranState()
            resetMaidenState()
            resetIllhoofState()
        end
        if not raidState.isInMagtheridonsLair then
            resetMagState()
        end
        if ENABLE_NETHERSPITE_MODULE then
            refreshNetherspiteTracker()
        end
        evaluatePrinceThresholds()
        evaluateMagtheridonThresholds()
        return false
    end
    if event == "PLAYER_REGEN_ENABLED" then
        resetPrinceState()
        resetMagState()
        resetNetherspiteState()
        resetMoroesState()
        resetAranState()
        resetMaidenState()
        resetIllhoofState()
        return false
    end
    if event == "PLAYER_TARGET_CHANGED" or event == "UNIT_TARGET" or event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT" then
        if ENABLE_NETHERSPITE_MODULE then
            refreshNetherspiteTracker()
        end
        evaluatePrinceThresholds()
        evaluateMagtheridonThresholds()
        return false
    end
    if event == "UNIT_AURA" then
        local unit = ...
        if ENABLE_NETHERSPITE_MODULE and raidState.isInKarazhan and unit == "player" and netherspiteState.engaged then
            local stacks = getUnitAuraStacksBySpellIDs("player", NETHER_PORTAL_PERSEVERENCE_SPELL_ID, NETHER_PORTAL_PERSEVERENCE_ALT_SPELL_ID)
            local playerGUID = UnitGUID("player")
            if stacks and playerGUID then
                handleNetherspiteStacks(false, stacks, true, playerGUID, UnitName("player"))
            elseif playerGUID and netherspiteState.currentBeamTankGUID == playerGUID then
                handleNetherspiteStacks(false, 0, false, playerGUID, UnitName("player"))
            else
                refreshNetherspiteTracker()
            end
        end
        return false
    end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" and (raidState.isInKarazhan or raidState.isInMagtheridonsLair) then
        local _, subEvent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID, spellName, _, auraType, auraAmount = CombatLogGetCurrentEventInfo()
        if raidState.isInMagtheridonsLair and subEvent then
            handleMagtheridonCubeCombatLog(subEvent, sourceGUID, sourceName, destGUID, destName, spellID, spellName)
        end
        if raidState.isInKarazhan and subEvent then
            maybeWarnMoroesGouge(subEvent, sourceGUID, sourceName, destGUID, destName, spellID, spellName)
            maybeWarnAranFlameWreath(subEvent, sourceGUID, sourceName, spellID, spellName)
            maybeWarnMaidenRepentance(subEvent, sourceGUID, sourceName, spellID, spellName)
            maybeWarnIllhoofSacrifice(subEvent, sourceGUID, sourceName, spellID, spellName)
        end
        if subEvent and (
            string.find(subEvent, "_DAMAGE", 1, true)
            or string.find(subEvent, "_MISSED", 1, true)
            or subEvent == "SWING_DAMAGE"
            or subEvent == "SWING_MISSED"
            or subEvent == "SPELL_CAST_START"
            or subEvent == "SPELL_CAST_SUCCESS"
        ) then
            if isPrinceByGUID(sourceGUID) or isPrinceByGUID(destGUID) or isPrinceByName(sourceName) or isPrinceByName(destName) then
                princeState.engaged = true
                evaluatePrinceThresholds()
            end
            if isMagtheridonByGUID(sourceGUID) or isMagtheridonByGUID(destGUID) or isMagtheridonByName(sourceName) or isMagtheridonByName(destName) then
                magState.engaged = true
                evaluateMagtheridonThresholds()
            end
        end
        if ENABLE_NETHERSPITE_MODULE and raidState.isInKarazhan and subEvent then
            if isNetherspiteByGUID(sourceGUID) or isNetherspiteByGUID(destGUID) or isNetherspiteByName(sourceName) or isNetherspiteByName(destName) then
                netherspiteState.engaged = true
                refreshNetherspiteTracker()
            end
            if not netherspiteState.engaged then
                return false
            end
            if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_APPLIED_DOSE" or subEvent == "SPELL_AURA_REFRESH" or subEvent == "SPELL_AURA_REMOVED" then
                local isRedBuff = isNetherspiteRedBeamAura(spellID, spellName)
                local isGreenBuff = isNetherspiteGreenBeamAura(spellID, spellName)
                local isBlueBuff = isNetherspiteBlueBeamAura(spellID, spellName)
                if isRedBuff then
                    local hadBuff = subEvent ~= "SPELL_AURA_REMOVED"
                    if destGUID and isNetherspiteByGUID(destGUID) then
                        local stacks = 0
                        if hadBuff then
                            stacks = tonumber(auraAmount) or 0
                            local auraStacks = getNetherspiteBossRedStacksFromAura()
                            if auraStacks and auraStacks > 0 then
                                stacks = auraStacks
                            elseif stacks <= 0 then
                                if subEvent == "SPELL_AURA_APPLIED_DOSE" then
                                    stacks = math.max(2, (tonumber(netherspiteState.bossStacks) or 1) + 1)
                                elseif subEvent == "SPELL_AURA_REFRESH" then
                                    stacks = math.max(tonumber(netherspiteState.bossStacks) or 1, 1)
                                else
                                    stacks = 1
                                end
                            end
                        end
                        handleNetherspiteStacks(true, stacks, hadBuff, destGUID, destName)
                    elseif destGUID and findGroupUnitByGUID(destGUID) then
                        local stacks = (subEvent == "SPELL_AURA_REMOVED") and 0 or (tonumber(auraAmount) or 1)
                        handleNetherspiteStacks(false, stacks, hadBuff, destGUID, destName)
                    end
                elseif isGreenBuff then
                    local hadBuff = subEvent ~= "SPELL_AURA_REMOVED"
                    if destGUID then
                        handleNetherspiteBeamTarget("green", tonumber(auraAmount) or 1, hadBuff, destGUID, destName)
                    end
                elseif isBlueBuff then
                    local hadBuff = subEvent ~= "SPELL_AURA_REMOVED"
                    if destGUID then
                        local stacks = (subEvent == "SPELL_AURA_REMOVED") and 0 or (tonumber(auraAmount) or 1)
                        handleNetherspiteBeamTarget("blue", stacks, hadBuff, destGUID, destName)
                    end
                end
            end
        end
    end

    -- Add boss-specific logic below.
    return false
end
