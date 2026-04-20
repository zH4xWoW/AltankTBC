-- Altank: enjoy leading without worrying about who pulled what or whether your taunts are landing.
-- author: j - https://www.curseforge.com/members/jeddawey/projects
local addonName = ...

local frame = CreateFrame("Frame")

local ADDON_VERSION = "1.7"
local COMM_PREFIX = "TankSync1"
local VERSION_PREFIX = "AltankVer1"
local CHAT_PREFIX = "|cffffd100[Altank]|r "
local PARTY_PREFIX = "[Altank] "
local AUTHOR_TAG = "made by |cffff0000j|r"
local MISDIRECTION_SPELL_ID = 34477
local RIGHTEOUS_FURY_SPELL_ID = 25780
local RIGHTEOUS_FURY_NAME = GetSpellInfo(RIGHTEOUS_FURY_SPELL_ID)
local PET_GROWL_NAME = GetSpellInfo(2649)
local _, PLAYER_CLASS = UnitClass("player")
local IS_TBC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
local IS_WOTLK = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC
local UNCRUSHABLE_THRESHOLD = 102.4
local COLOR_OK = "ff55ff55"
local COLOR_BAD = "ffff6060"
local COLOR_INFO = "ffbe9c91"

local TAUNT_SPELLS = {
    -- Warrior
    [355] = true,     -- Taunt
    [694] = true,     -- Mocking Blow
    [1161] = true,    -- Challenging Shout
    [386071] = true,  -- Disrupting Shout

    -- Druid
    [6795] = true,    -- Growl
    [5209] = true,    -- Challenging Roar

    -- Paladin
    [62124] = true,   -- Hand of Reckoning
    [31789] = true,   -- Righteous Defense
    [204079] = true,  -- Final Stand

    -- Death Knight
    [56222] = true,   -- Dark Command
    [49576] = true,   -- Death Grip
    [51399] = true,   -- Death Grip (Blood variant)

    -- Monk
    [115546] = true,  -- Provoke

    -- Demon Hunter
    [185245] = true,  -- Torment

    -- Shaman / Warlock / Hunter
    [5730] = true,    -- Stoneclaw Totem
    [59671] = true,   -- Challenging Howl
    [20736] = true,   -- Distracting Shot

    -- Hunter pet Growl ranks
    [2649] = true,
    [14916] = true,
    [14917] = true,
    [14918] = true,
    [14919] = true,
    [14920] = true,
    [14921] = true,
    [14922] = true,
}

local PULL_EVENTS = {
    SWING_DAMAGE = true,
    RANGE_DAMAGE = true,
    SPELL_DAMAGE = true,
    RANGE_MISSED = true,
    SPELL_MISSED = true,
}

local CLASS_BY_SPELL = {
    [355] = "WARRIOR",
    [694] = "WARRIOR",
    [1161] = "WARRIOR",
    [386071] = "WARRIOR",

    [6795] = "DRUID",
    [5209] = "DRUID",

    [62124] = "PALADIN",
    [31789] = "PALADIN",
    [204079] = "PALADIN",

    [2649] = "HUNTER_PET",
    [14916] = "HUNTER_PET",
    [14917] = "HUNTER_PET",
    [14918] = "HUNTER_PET",
    [14919] = "HUNTER_PET",
    [14920] = "HUNTER_PET",
    [14921] = "HUNTER_PET",
    [14922] = "HUNTER_PET",
}

local NAME_COLORS = {
    DRUID = "ffff7c0a",      -- orange
    PALADIN = "ffff69b4",    -- pink
    WARRIOR = "ff8c5a2b",    -- brown
    HUNTER_PET = "ff3399ff", -- blue
}

local MARKER_TOKENS = {
    { flag = COMBATLOG_OBJECT_RAIDTARGET1, token = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t" },
    { flag = COMBATLOG_OBJECT_RAIDTARGET2, token = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0|t" },
    { flag = COMBATLOG_OBJECT_RAIDTARGET3, token = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0|t" },
    { flag = COMBATLOG_OBJECT_RAIDTARGET4, token = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0|t" },
    { flag = COMBATLOG_OBJECT_RAIDTARGET5, token = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0|t" },
    { flag = COMBATLOG_OBJECT_RAIDTARGET6, token = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0|t" },
    { flag = COMBATLOG_OBJECT_RAIDTARGET7, token = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0|t" },
    { flag = COMBATLOG_OBJECT_RAIDTARGET8, token = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t" },
}

local MARKER_TOKEN_BY_INDEX = {
    [1] = " |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t",
    [2] = " |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0|t",
    [3] = " |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0|t",
    [4] = " |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0|t",
    [5] = " |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0|t",
    [6] = " |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0|t",
    [7] = " |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0|t",
    [8] = " |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t",
}

local recent = {}
local RECENT_WINDOW = 1.00
local announcedPullThisCombat = UnitAffectingCombat("player")
local printChat
local sendSync
local shouldPrint
local whisperEnabled = true
local whisperCooldownSeconds = 25
local lastWhisperAt = {}
local activeIncapEvents = {}
local roleMenuHooksInstalled = false
local ENABLE_ROLE_MENU_HOOKS = true
local versionAlerted = {}
local currentAddonVersion = ADDON_VERSION
local lastVersionBroadcastAt = 0
local INCAPACITATION_LOCS = {
    STUN = true,
    FEAR = true,
    CHARM = true,
    CONFUSE = true,
    DISORIENT = true,
    PACIFY = true,
    PACIFYSILENCE = true,
    SILENCE = true,
}

local function isIncapLocType(locType)
    if type(locType) ~= "string" or locType == "" then
        return false
    end
    local upper = string.upper(locType)
    if INCAPACITATION_LOCS[upper] then
        return true
    end
    return string.find(upper, "STUN", 1, true)
        or string.find(upper, "FEAR", 1, true)
        or string.find(upper, "CHARM", 1, true)
        or string.find(upper, "DISORIENT", 1, true)
        or string.find(upper, "CONFUSE", 1, true)
        or string.find(upper, "HORROR", 1, true)
        or string.find(upper, "INCAP", 1, true)
end
local characterStatsUI = {
    frame = nil,
    defenseTitle = nil,
    defenseInfo = nil,
    critTitle = nil,
    critInfo = nil,
    hitTitle = nil,
    hitInfo = nil,
    meleeHitTitle = nil,
    meleeHitInfo = nil,
    hitNoteTitle = nil,
    hitNoteInfo = nil,
    crushTitle = nil,
    crushInfo = nil,
    armorTitle = nil,
    armorInfo = nil,
    altankElements = nil,
    ecsFrame = nil,
    pageButtons = nil,
    currentPage = 1,
    hooksInstalled = false,
}
local righteousFuryWarningUI = {
    frame = nil,
    icon = nil,
    animation = nil,
}
local defensiveStanceWarningUI = {
    frame = nil,
    icon = nil,
    animation = nil,
}
local rangeWarningUI = {
    frame = nil,
    icon = nil,
}
local rangeCheckElapsed = 0
local defensiveCheckElapsed = 0
local RANGE_CHECK_INTERVAL = 0.2
local warriorRangeActionSlot = nil
local DEBUFF_TRACKER_ICON_SIZE = 32
local DEBUFF_TRACKER_ICON_SPACING = 2
local DEBUFF_TRACKER_COLUMNS = 5
local DEBUFF_TRACKER_LOW_TIME_SECONDS = 5

local debuffTrackerUI = {
    frame = nil,
    icons = {},
}
local debuffTrackerState = {
    rosterClasses = {},
    inGroup = false,
    ticker = nil,
    lastVisibleSignature = nil,
}

local DEBUFF_TRACKER_ENTRIES = {
    {
        key = "curse_elements",
        icon = 136130,
        auraNames = {"Curse of the Elements"},
        providerClasses = {WARLOCK = true},
    },
    {
        key = "curse_recklessness",
        icon = 136225,
        auraNames = {"Curse of Recklessness"},
        providerClasses = {WARLOCK = true},
    },
    {
        key = "curse_weakness",
        icon = (GetSpellTexture and GetSpellTexture(702)) or 136138,
        auraNames = {"Curse of Weakness"},
        providerClasses = {WARLOCK = true},
    },
    {
        key = "faerie_fire",
        icon = 136033,
        auraNames = {"Faerie Fire", "Improved Faerie Fire", "Faerie Fire (Feral)"},
        providerClasses = {DRUID = true},
    },
    {
        key = "armor",
        icon = 132354,
        auraNames = {"Sunder Armor", "Expose Armor"},
        providerClasses = {WARRIOR = true, ROGUE = true},
        stackWarningBelow = 5,
    },
    {
        key = "shout_roar",
        icon = 132366,
        auraNames = {"Demoralizing Shout", "Demoralizing Roar"},
        providerClasses = {WARRIOR = true, DRUID = true},
    },
    {
        key = "thunder",
        icon = 136105,
        auraNames = {"Thunder Clap", "Thunderfury"},
        providerClasses = {WARRIOR = true},
    },
}

local ensureDebuffTrackerUI
local updateDebuffTrackerDisplay
local updateDebuffTrackerRosterCache
local startDebuffTrackerTicker

local function ensureDebuffTrackerDB()
    if type(AltankDB) ~= "table" then
        AltankDB = {}
    end
    if type(AltankDB.debuffTrackerFramePoint) ~= "table" then
        AltankDB.debuffTrackerFramePoint = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 225,
            y = -30,
        }
    end
end

local function extractAuraDurationExpiration(r5, r6, r7)
    local duration
    local expirationTime
    if type(r6) == "number" and type(r7) == "number" then
        duration = r6
        expirationTime = r7
    elseif type(r5) == "number" and type(r6) == "number" then
        duration = r5
        expirationTime = r6
    elseif type(r6) == "number" then
        duration = r6
    elseif type(r5) == "number" then
        duration = r5
    end
    return duration, expirationTime
end

local function getTargetDebuffLookup()
    if not UnitDebuff or not UnitExists("target") then
        return nil
    end

    local byName = {}
    for i = 1, 40 do
        local name, icon, count, debuffType, r5, r6, r7 = UnitDebuff("target", i)
        if not name then
            break
        end

        if not byName[name] then
            local duration, expirationTime = extractAuraDurationExpiration(r5, r6, r7)
            byName[name] = {
                name = name,
                icon = icon,
                count = tonumber(count) or 0,
                duration = duration,
                expirationTime = expirationTime,
            }
        end
    end

    return byName
end

local function getTargetDebuffByNames(debuffLookup, auraNames)
    if type(auraNames) ~= "table" or not debuffLookup then
        return nil
    end

    for j = 1, #auraNames do
        local aura = debuffLookup[auraNames[j]]
        if aura then
            return aura
        end
    end

    return nil
end

updateDebuffTrackerRosterCache = function()
    local classes = {}
    local inRaid = IsInRaid and IsInRaid()
    debuffTrackerState.inGroup = inRaid and true or false

    if inRaid then
        local count = GetNumGroupMembers and (GetNumGroupMembers() or 0) or 0
        for i = 1, count do
            local _, _, _, _, _, classToken = GetRaidRosterInfo(i)
            if classToken and classToken ~= "" then
                classes[classToken] = true
            end
        end
    end

    debuffTrackerState.rosterClasses = classes
end

local function debuffTrackerEntryRelevant(entry)
    if not debuffTrackerState.inGroup then
        return true
    end
    if type(entry.providerClasses) ~= "table" then
        return true
    end
    for classToken in pairs(entry.providerClasses) do
        if debuffTrackerState.rosterClasses[classToken] then
            return true
        end
    end
    return false
end

local function setDebuffTrackerCooldown(cooldown, duration, expirationTime)
    if not cooldown then
        return
    end
    if type(duration) == "number" and duration > 0 and type(expirationTime) == "number" and expirationTime > 0 then
        local start = expirationTime - duration
        if start < 0 then
            start = 0
        end
        if CooldownFrame_Set then
            CooldownFrame_Set(cooldown, start, duration, true)
        elseif cooldown.SetCooldown then
            cooldown:SetCooldown(start, duration)
        end
        cooldown:Show()
        return
    end
    if CooldownFrame_Set then
        CooldownFrame_Set(cooldown, 0, 0, false)
    elseif cooldown.SetCooldown then
        cooldown:SetCooldown(0, 0)
    end
    cooldown:Hide()
end

local function layoutDebuffTrackerIcons(visibleKeys)
    local frame = debuffTrackerUI.frame
    if not frame then
        return
    end
    if #visibleKeys == 0 then
        frame:Hide()
        return
    end

    frame:Show()

    for index = 1, #visibleKeys do
        local key = visibleKeys[index]
        local iconState = debuffTrackerUI.icons[key]
        if iconState and iconState.frame then
            local col = (index - 1) % DEBUFF_TRACKER_COLUMNS
            local row = math.floor((index - 1) / DEBUFF_TRACKER_COLUMNS)
            iconState.frame:ClearAllPoints()
            iconState.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 8 + (col * (DEBUFF_TRACKER_ICON_SIZE + DEBUFF_TRACKER_ICON_SPACING)), -8 - (row * (DEBUFF_TRACKER_ICON_SIZE + DEBUFF_TRACKER_ICON_SPACING)))
        end
    end

    local cols = math.min(DEBUFF_TRACKER_COLUMNS, #visibleKeys)
    local rows = math.max(1, math.ceil(#visibleKeys / DEBUFF_TRACKER_COLUMNS))
    local width = 16 + (cols * DEBUFF_TRACKER_ICON_SIZE) + ((cols - 1) * DEBUFF_TRACKER_ICON_SPACING)
    local height = 16 + (rows * DEBUFF_TRACKER_ICON_SIZE) + ((rows - 1) * DEBUFF_TRACKER_ICON_SPACING)
    frame:SetSize(width, height)
end

updateDebuffTrackerDisplay = function()
    if not ensureDebuffTrackerUI() then
        return
    end
    if not (IsInRaid and IsInRaid()) then
        if debuffTrackerUI.frame then
            debuffTrackerUI.frame:Hide()
        end
        debuffTrackerState.lastVisibleSignature = nil
        return
    end

    local hasTarget = UnitExists and UnitExists("target") and UnitCanAttack and UnitCanAttack("player", "target")
    local now = GetTime and GetTime() or 0
    local debuffLookup = hasTarget and getTargetDebuffLookup() or nil
    local visibleKeys = {}

    for i = 1, #DEBUFF_TRACKER_ENTRIES do
        local entry = DEBUFF_TRACKER_ENTRIES[i]
        local iconState = debuffTrackerUI.icons[entry.key]
        if iconState and iconState.frame and iconState.icon then
            local aura = hasTarget and getTargetDebuffByNames(debuffLookup, entry.auraNames) or nil
            local relevant = debuffTrackerEntryRelevant(entry)
            local shouldShow = relevant or aura ~= nil

            if shouldShow then
                visibleKeys[#visibleKeys + 1] = entry.key
                iconState.frame:Show()
            else
                iconState.frame:Hide()
            end

            if aura then
                local remaining = (type(aura.expirationTime) == "number" and aura.expirationTime > 0) and (aura.expirationTime - now) or nil
                iconState.icon:SetTexture(aura.icon or entry.icon)
                iconState.icon:SetDesaturated(false)
                iconState.icon:SetVertexColor(1, 1, 1, 1)
                iconState.frame:SetAlpha(1)

                setDebuffTrackerCooldown(iconState.cooldown, aura.duration, aura.expirationTime)

                if remaining and remaining > 0 then
                    if remaining <= DEBUFF_TRACKER_LOW_TIME_SECONDS then
                        iconState.timerText:SetText(string.format("%.1f", remaining))
                        iconState.timerText:SetTextColor(0.92, 0.13, 0.15, 1)
                        iconState.glow:SetAlpha(1)
                    else
                        iconState.timerText:SetText(tostring(math.floor(remaining + 0.5)))
                        iconState.timerText:SetTextColor(1, 1, 1, 1)
                        iconState.glow:SetAlpha(0)
                    end
                else
                    iconState.timerText:SetText("")
                    iconState.glow:SetAlpha(0)
                end

                if entry.stackWarningBelow and aura.count and aura.count > 0 and aura.count < entry.stackWarningBelow then
                    iconState.stackText:SetText(tostring(aura.count))
                else
                    iconState.stackText:SetText("")
                end
            else
                iconState.icon:SetTexture(entry.icon)
                iconState.icon:SetDesaturated(true)
                iconState.icon:SetVertexColor(0.55, 0.55, 0.55, 1)
                iconState.frame:SetAlpha(0.55)
                iconState.timerText:SetText("")
                iconState.stackText:SetText("")
                iconState.glow:SetAlpha(0)
                setDebuffTrackerCooldown(iconState.cooldown, nil, nil)
            end
        end
    end

    local visibleSignature = table.concat(visibleKeys, "|")
    if visibleSignature ~= debuffTrackerState.lastVisibleSignature then
        debuffTrackerState.lastVisibleSignature = visibleSignature
        layoutDebuffTrackerIcons(visibleKeys)
    end
end

ensureDebuffTrackerUI = function()
    if debuffTrackerUI.frame then
        return true
    end

    ensureDebuffTrackerDB()
    local point = AltankDB.debuffTrackerFramePoint

    local frameContainer = CreateFrame("Frame", "AltankDebuffTrackerFrame", UIParent, "BackdropTemplate")
    frameContainer:SetPoint(point.point or "CENTER", UIParent, point.relativePoint or "CENTER", point.x or 225, point.y or -30)
    frameContainer:SetFrameStrata("MEDIUM")
    frameContainer:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frameContainer:SetBackdropColor(0, 0, 0, 0.55)
    frameContainer:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.85)
    frameContainer:SetMovable(true)
    frameContainer:EnableMouse(true)
    frameContainer:RegisterForDrag("LeftButton")
    frameContainer:SetClampedToScreen(true)
    frameContainer:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frameContainer:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint(1)
        ensureDebuffTrackerDB()
        AltankDB.debuffTrackerFramePoint = {
            point = p or "CENTER",
            relativePoint = rp or "CENTER",
            x = x or 0,
            y = y or 0,
        }
    end)
    frameContainer:Hide()

    debuffTrackerUI.frame = frameContainer

    for i = 1, #DEBUFF_TRACKER_ENTRIES do
        local entry = DEBUFF_TRACKER_ENTRIES[i]
        local iconFrame = CreateFrame("Frame", nil, frameContainer)
        iconFrame:SetSize(DEBUFF_TRACKER_ICON_SIZE, DEBUFF_TRACKER_ICON_SIZE)

        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(iconFrame)
        icon:SetTexture(entry.icon)

        local border = iconFrame:CreateTexture(nil, "OVERLAY")
        border:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 0, 0)
        border:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 0, 0)
        border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        border:SetTexCoord(0.2, 0.8, 0.2, 0.8)
        border:SetVertexColor(0, 0, 0, 0.95)

        local glow = iconFrame:CreateTexture(nil, "OVERLAY")
        glow:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", -5, 5)
        glow:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 5, -5)
        glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        glow:SetBlendMode("ADD")
        glow:SetAlpha(0)

        local cooldown = CreateFrame("Cooldown", nil, iconFrame, "CooldownFrameTemplate")
        cooldown:SetAllPoints(iconFrame)
        if cooldown.SetDrawEdge then
            cooldown:SetDrawEdge(true)
        end
        cooldown:Hide()

        local timerText = iconFrame:CreateFontString(nil, "OVERLAY")
        timerText:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
        timerText:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
        timerText:SetTextColor(1, 1, 1, 1)
        timerText:SetText("")

        local stackText = iconFrame:CreateFontString(nil, "OVERLAY")
        stackText:SetPoint("TOP", iconFrame, "TOP", 0, -2)
        stackText:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
        stackText:SetTextColor(0.93, 0.35, 0.14, 1)
        stackText:SetText("")

        debuffTrackerUI.icons[entry.key] = {
            frame = iconFrame,
            icon = icon,
            cooldown = cooldown,
            timerText = timerText,
            stackText = stackText,
            glow = glow,
        }
    end

    return true
end

startDebuffTrackerTicker = function()
    if debuffTrackerState.ticker then
        return
    end
    debuffTrackerState.ticker = C_Timer.NewTicker(0.2, function()
        if debuffTrackerUI.frame and debuffTrackerUI.frame:IsShown() then
            updateDebuffTrackerDisplay()
        end
    end)
end

local function hasPlayerBuffBySpellID(spellID)
    if not UnitBuff then
        return false
    end
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, auraSpellID10, auraSpellID11 = UnitBuff("player", i)
        if not name then
            break
        end
        local auraSpellID = (type(auraSpellID11) == "number" and auraSpellID11) or (type(auraSpellID10) == "number" and auraSpellID10)
        if auraSpellID and auraSpellID == spellID then
            return true
        end
        if RIGHTEOUS_FURY_NAME and name == RIGHTEOUS_FURY_NAME and spellID == RIGHTEOUS_FURY_SPELL_ID then
            return true
        end
    end
    return false
end

local function getTalentRankByName(talentName)
    if type(talentName) ~= "string" or talentName == "" or not GetNumTalentTabs or not GetTalentInfo or not GetNumTalents then
        return 0
    end

    for tabIndex = 1, GetNumTalentTabs() do
        for talentIndex = 1, GetNumTalents(tabIndex) do
            local name, _, _, _, rank = GetTalentInfo(tabIndex, talentIndex)
            if name == talentName then
                return rank or 0
            end
        end
    end

    return 0
end

local function getTalentMeleeHitBonus(classToken)
    if classToken == "PALADIN" then
        local precisionName = GetSpellInfo and GetSpellInfo(20189) or "Precision"
        if precisionName then
            return getTalentRankByName(precisionName) * 1.0, precisionName
        end
    end

    return 0, nil
end

local function shouldSendWhisper(now, ownerName)
    if not ownerName then
        return false
    end
    local last = lastWhisperAt[ownerName]
    if last and (now - last) < whisperCooldownSeconds then
        return false
    end
    lastWhisperAt[ownerName] = now
    return true
end

local function ensureRighteousFuryWarningUI()
    local ui = righteousFuryWarningUI
    if ui.frame then
        return true
    end

    local frame = CreateFrame("Frame", "AltankRighteousFuryWarning", UIParent)
    frame:SetSize(140, 140)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:Hide()

    local iconTexture = GetSpellTexture and GetSpellTexture(RIGHTEOUS_FURY_SPELL_ID) or nil
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(frame)
    icon:SetTexture(iconTexture or "Interface\\Icons\\Spell_Holy_SealOfFury")

    local border = frame:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", -10, 10)
    border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 10, -10)
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetTexCoord(0, 1, 0, 1)
    border:SetVertexColor(1, 0.2, 0.2, 0.95)

    local pulse = frame:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local alpha = pulse:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1.0)
    alpha:SetToAlpha(0.15)
    alpha:SetDuration(0.55)
    alpha:SetSmoothing("IN_OUT")

    ui.frame = frame
    ui.icon = icon
    ui.animation = pulse
    return true
end

local DEFENSIVE_STANCE_SPELL_ID = 71
local DEFENSIVE_STANCE_NAME = GetSpellInfo(DEFENSIVE_STANCE_SPELL_ID)

local function isInDefensiveStance()
    if GetShapeshiftForm then
        return GetShapeshiftForm() == 2
    end
    if GetShapeshiftFormID then
        return GetShapeshiftFormID() == 18
    end
    if GetShapeshiftFormInfo and GetNumShapeshiftForms then
        local count = GetNumShapeshiftForms() or 0
        for i = 1, count do
            local _, _, _, isActive = GetShapeshiftFormInfo(i)
            if isActive and i == 2 then
                return true
            end
        end
    end
    return false
end

local function isTankWarrior()
    if PLAYER_CLASS ~= "WARRIOR" then
        return false
    end
    if UnitGroupRolesAssigned then
        return UnitGroupRolesAssigned("player") == "TANK"
    end
    return true
end

local function ensureDefensiveStanceWarningUI()
    local ui = defensiveStanceWarningUI
    if ui.frame then
        return true
    end

    local frame = CreateFrame("Frame", "AltankDefensiveStanceWarning", UIParent)
    frame:SetSize(140, 140)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:Hide()

    local iconTexture = GetSpellTexture and GetSpellTexture(DEFENSIVE_STANCE_SPELL_ID) or nil
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(frame)
    icon:SetTexture(iconTexture or "Interface\\Icons\\Ability_Warrior_DefensiveStance")

    local pulse = frame:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local alpha = pulse:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1.0)
    alpha:SetToAlpha(0.15)
    alpha:SetDuration(0.55)
    alpha:SetSmoothing("IN_OUT")

    ui.frame = frame
    ui.icon = icon
    ui.animation = pulse
    return true
end

local function ensureRangeWarningUI()
    local ui = rangeWarningUI
    if ui.frame then
        return true
    end

    local frame = CreateFrame("Frame", "AltankRangeWarning", UIParent)
    frame:SetSize(32, 32)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:Hide()

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(frame)
    icon:SetTexture("Interface\\COMMON\\Indicator-Red")

    ui.frame = frame
    ui.icon = icon
    return true
end

local function updateRighteousFuryWarning()
    if not ensureRighteousFuryWarningUI() then
        return
    end

    local ui = righteousFuryWarningUI
    local inGroup = IsInGroup(LE_PARTY_CATEGORY_HOME) or IsInRaid(LE_PARTY_CATEGORY_HOME) or IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
    local isDeadOrGhost = (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player"))
        or UnitIsDead("player")
        or UnitIsGhost("player")
    local isMounted = IsMounted and IsMounted()
    local isOnTaxi = UnitOnTaxi and UnitOnTaxi("player")
    local shouldWarn = PLAYER_CLASS == "PALADIN"
        and inGroup
        and not isDeadOrGhost
        and not isMounted
        and not isOnTaxi
        and not hasPlayerBuffBySpellID(RIGHTEOUS_FURY_SPELL_ID)

    if shouldWarn then
        if not ui.frame:IsShown() then
            ui.frame:Show()
        end
        if ui.animation and not ui.animation:IsPlaying() then
            ui.animation:Play()
        end
        return
    end

    if ui.animation and ui.animation:IsPlaying() then
        ui.animation:Stop()
    end
    ui.frame:SetAlpha(1)
    ui.frame:Hide()
end

local function isMeleeRangeClass()
    if PLAYER_CLASS ~= "WARRIOR" and PLAYER_CLASS ~= "PALADIN" and PLAYER_CLASS ~= "ROGUE" and PLAYER_CLASS ~= "DRUID" and PLAYER_CLASS ~= "SHAMAN" then
        return false
    end
    if UnitGroupRolesAssigned then
        local role = UnitGroupRolesAssigned("player")
        if role == "HEALER" then
            return false
        end
    end
    return true
end

local function getKnownMeleeRangeSpellName()
    if PLAYER_CLASS == "WARRIOR" then
        local devastate = GetSpellInfo(20243)
        if devastate and devastate ~= "" then
            return devastate
        end
    end
    local attackName = GetSpellInfo(6603)
    if attackName and attackName ~= "" then
        return attackName
    end
    return nil
end

local function findWarriorRangeActionSlot()
    if not GetActionInfo then
        return nil
    end
    local devastateName = GetSpellInfo(20243)
    if not devastateName then
        return nil
    end
    for slot = 1, 120 do
        local actionType, actionId = GetActionInfo(slot)
        if actionType == "spell" and actionId then
            local name = GetSpellInfo(actionId)
            if name == devastateName then
                return slot
            end
        end
    end
    return nil
end

local function isTargetOutOfMeleeRange()
    if PLAYER_CLASS == "WARRIOR" and IsActionInRange then
        if not warriorRangeActionSlot then
            warriorRangeActionSlot = findWarriorRangeActionSlot()
        end
        if warriorRangeActionSlot then
            local inRange = IsActionInRange(warriorRangeActionSlot)
            if inRange == 0 then
                return true
            end
            if inRange == 1 then
                return false
            end
        end
    end
    local spellName = getKnownMeleeRangeSpellName()
    if spellName and IsSpellInRange then
        local inRange = IsSpellInRange(spellName, "target")
        if inRange == 0 then
            return true
        end
        if inRange == 1 then
            return false
        end
    end
    return false
end

local function updateRangeWarning()
    if not ensureRangeWarningUI() then
        return
    end
    local ui = rangeWarningUI
    local shouldWarn = UnitAffectingCombat("player")
        and isMeleeRangeClass()
        and UnitExists("target")
        and UnitCanAttack("player", "target")
        and not UnitIsDead("target")
        and isTargetOutOfMeleeRange()

    if shouldWarn then
        if not ui.frame:IsShown() then
            ui.frame:Show()
        end
        return
    end

    ui.frame:Hide()
end

local function updateDefensiveStanceWarning()
    if not ensureDefensiveStanceWarningUI() then
        return
    end

    local ui = defensiveStanceWarningUI
    local isTank = isTankWarrior()
    local inGroup = IsInGroup(LE_PARTY_CATEGORY_HOME) or IsInRaid(LE_PARTY_CATEGORY_HOME) or IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
    local isDeadOrGhost = (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player"))
        or UnitIsDead("player")
        or UnitIsGhost("player")
    local isMounted = IsMounted and IsMounted()
    local isOnTaxi = UnitOnTaxi and UnitOnTaxi("player")
    local inDef = isInDefensiveStance()
    local shouldWarn = isTank
        and UnitAffectingCombat("player")
        and inGroup
        and not isDeadOrGhost
        and not isMounted
        and not isOnTaxi
        and not inDef

    if shouldWarn then
        if not ui.frame:IsShown() then
            ui.frame:Show()
        end
        if ui.animation and not ui.animation:IsPlaying() then
            ui.animation:Play()
        end
        return
    end

    if ui.animation and ui.animation:IsPlaying() then
        ui.animation:Stop()
    end
    ui.frame:SetAlpha(1)
    ui.frame:Hide()
end

local function updateCharacterTankStats()
    local ui = characterStatsUI
    if ui.userClosed then
        if ui.frame then
            ui.frame:Hide()
        end
        if ui.ecsFrame then
            ui.ecsFrame:Hide()
        end
        return
    end
    if ui.currentPage == 2 then
        return
    end
    if not ui.frame or not ui.defenseTitle or not ui.defenseInfo or not ui.critTitle or not ui.critInfo or not ui.hitTitle or not ui.hitInfo or not ui.meleeHitTitle or not ui.meleeHitInfo or not ui.hitNoteTitle or not ui.hitNoteInfo or not ui.crushTitle or not ui.crushInfo or not ui.armorTitle or not ui.armorInfo then
        return
    end

    local parent = ui.frame:GetParent()
    if not parent or not parent:IsShown() then
        ui.frame:Hide()
        return
    end

    local playerLevel = UnitLevel("player")
    if not playerLevel or playerLevel <= 0 then
        ui.frame:Hide()
        return
    end

    local baseDefense, defenseMod = UnitDefense("player")
    local defenseValue = (baseDefense or 0) + (defenseMod or 0)
    local _, effectiveArmor = UnitArmor("player")
    local defenseCap = 440
    if IS_TBC then
        defenseCap = 490
    elseif IS_WOTLK then
        defenseCap = 540
    end
    local defenseDiff = defenseValue - defenseCap
    local defenseColor = defenseDiff >= 0 and COLOR_OK or COLOR_BAD
    local playerBaseDefenseSkill = playerLevel * 5
    local defenseCritReduction = (defenseValue - playerBaseDefenseSkill) * 0.04
    local resilienceCritReduction = 0
    if GetCombatRatingBonus then
        local resilienceTotal = 0
        local resilienceCount = 0
        if CR_CRIT_TAKEN_MELEE then
            resilienceTotal = resilienceTotal + (GetCombatRatingBonus(CR_CRIT_TAKEN_MELEE) or 0)
            resilienceCount = resilienceCount + 1
        end
        if CR_CRIT_TAKEN_RANGED then
            resilienceTotal = resilienceTotal + (GetCombatRatingBonus(CR_CRIT_TAKEN_RANGED) or 0)
            resilienceCount = resilienceCount + 1
        end
        if CR_CRIT_TAKEN_SPELL then
            resilienceTotal = resilienceTotal + (GetCombatRatingBonus(CR_CRIT_TAKEN_SPELL) or 0)
            resilienceCount = resilienceCount + 1
        end
        if resilienceCount == 0 and CR_RESILIENCE_CRIT_TAKEN then
            resilienceTotal = resilienceTotal + (GetCombatRatingBonus(CR_RESILIENCE_CRIT_TAKEN) or 0)
            resilienceCount = resilienceCount + 1
        end
        if resilienceCount > 0 then
            resilienceCritReduction = resilienceTotal / resilienceCount
        end
    end
    local talentCritReduction = 0
    local classToken = PLAYER_CLASS
    if classToken == "DRUID" and GetNumTalentTabs and GetTalentInfo then
        local survivalName = GetSpellInfo and GetSpellInfo(33856) or "Survival of the Fittest"
        if survivalName then
            talentCritReduction = getTalentRankByName(survivalName) * 1.0
        end
    end
    local totalCritReduction = defenseCritReduction + resilienceCritReduction + talentCritReduction
    local critImmunityTarget = 5.6
    local critOverUnder = totalCritReduction - critImmunityTarget
    local critColor = critOverUnder >= 0 and COLOR_OK or COLOR_BAD
    local armorReduction = 0
    if PaperDollFrame_GetArmorReduction then
        local reduction = PaperDollFrame_GetArmorReduction(effectiveArmor or 0, playerLevel) or 0
        if reduction > 1 then
            armorReduction = reduction
        else
            armorReduction = reduction * 100
        end
    end
    ui.defenseTitle:SetText("|c" .. COLOR_INFO .. "Def|r")
    ui.defenseInfo:SetText(string.format(
        "|c%s%d / %d (%+d)|r",
        defenseColor,
        defenseValue,
        defenseCap,
        defenseDiff
    ))
    ui.critTitle:SetText("|c" .. COLOR_INFO .. "Crit|r")
    ui.critInfo:SetText(string.format(
        "|c%s%.2f%% / 5.60%%|r",
        critColor,
        totalCritReduction
    ))
    local meleeHitFromRating = (GetCombatRatingBonus and CR_HIT_MELEE and GetCombatRatingBonus(CR_HIT_MELEE)) or 0
    local meleeHitFromTalent, meleeHitTalentName = getTalentMeleeHitBonus(classToken)
    local meleeHitBonus = meleeHitFromRating + meleeHitFromTalent
    local expertisePercent = 0
    if GetExpertise then
        local expertise = GetExpertise() or 0
        expertisePercent = expertise * 0.25
    elseif GetCombatRatingBonus and CR_EXPERTISE then
        expertisePercent = GetCombatRatingBonus(CR_EXPERTISE) or 0
    end
    ui.hitTitle:SetText("|c" .. COLOR_INFO .. "Armor|r")
    ui.hitInfo:SetText(string.format("|c" .. COLOR_INFO .. "%.2f%% DR|r", armorReduction))
    ui.armorTitle:SetText("|c" .. COLOR_INFO .. "Exp|r")
    ui.armorInfo:SetText(string.format("|c" .. COLOR_INFO .. "%.2f%% / 6.50%%|r", expertisePercent))
    ui.meleeHitTitle:SetText("|c" .. COLOR_INFO .. "Hit|r")
    ui.meleeHitInfo:SetText(string.format("|c" .. COLOR_INFO .. "%.2f%% / 9.00%%|r", meleeHitBonus))
    ui.hitNoteTitle:SetText("|c" .. COLOR_INFO .. "Hit Note|r")
    ui.hitNoteInfo:SetText("|c" .. COLOR_INFO .. "Draenei +1%, Moonkin +3%|r")

    ui.crushTitle:SetText("|c" .. COLOR_INFO .. "Crush|r")
    if IS_WOTLK then
        ui.crushInfo:SetText("|c" .. COLOR_INFO .. "N/A (WotLK)|r")
        ui.frame:Show()
        return
    end

    local enemyAttackSkill = (playerLevel + 3) * 5
    local enemyMissChance = 5 + ((defenseValue - enemyAttackSkill) * 0.04)

    local blockChance = GetBlockChance() or 0
    local parryChance = GetParryChance() or 0
    local dodgeChance = GetDodgeChance() or 0
    local uncrushableTotal = enemyMissChance + blockChance + parryChance + dodgeChance
    local uncrushableDiff = uncrushableTotal - UNCRUSHABLE_THRESHOLD
    local uncrushableColor = uncrushableDiff >= 0 and COLOR_OK or COLOR_BAD

    ui.crushInfo:SetText(string.format(
        "|c%s%.2f%% / %.2f%% (%+.2f%%)|r",
        uncrushableColor,
        uncrushableTotal,
        UNCRUSHABLE_THRESHOLD,
        uncrushableDiff
    ))
    ui.frame:Show()
end

local setStatsPage
local ensureStatsPagerButtons

local function ensureCharacterTankStatsUI()
    local ui = characterStatsUI
    if ui.frame then
        return true
    end

    local parent = PaperDollFrame or PaperDollItemsFrame or CharacterFrame
    if not parent then
        return false
    end

    local container = CreateFrame("Frame", "AltankCharacterTankStats", parent)
    container:SetSize(195, 446)

    container:SetPoint("LEFT", parent, "RIGHT", -30, 30)

    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(container)
    bg:SetColorTexture(0, 0, 0, 0.8)

    if not ui.closeButton then
        local close = CreateFrame("Button", nil, container, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", container, "TOPRIGHT", 4, 4)
        close:SetScript("OnClick", function()
            ui.userClosed = true
            ui.ecsUserClosed = true
            container:Hide()
            if ui.ecsFrame then
                ui.ecsFrame:Hide()
            end
        end)
        ui.closeButton = close
    end

    local defenseTitle = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    defenseTitle:SetPoint("TOP", container, "TOP", 0, -57)
    defenseTitle:SetWidth(195)
    defenseTitle:SetJustifyH("CENTER")

    local defenseInfo = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    defenseInfo:SetPoint("TOP", defenseTitle, "BOTTOM", 0, -1)
    defenseInfo:SetWidth(195)
    defenseInfo:SetJustifyH("CENTER")

    local critTitle = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    critTitle:SetPoint("TOP", defenseInfo, "BOTTOM", 0, -2)
    critTitle:SetWidth(195)
    critTitle:SetJustifyH("CENTER")

    local critInfo = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    critInfo:SetPoint("TOP", critTitle, "BOTTOM", 0, -1)
    critInfo:SetWidth(195)
    critInfo:SetJustifyH("CENTER")

    local crushTitle = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    crushTitle:SetPoint("TOP", critInfo, "BOTTOM", 0, -2)
    crushTitle:SetWidth(195)
    crushTitle:SetJustifyH("CENTER")

    local crushInfo = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    crushInfo:SetPoint("TOP", crushTitle, "BOTTOM", 0, -1)
    crushInfo:SetWidth(195)
    crushInfo:SetJustifyH("CENTER")

    local hitTitle = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hitTitle:SetPoint("TOP", crushInfo, "BOTTOM", 0, -2)
    hitTitle:SetWidth(195)
    hitTitle:SetJustifyH("CENTER")

    local hitInfo = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hitInfo:SetPoint("TOP", hitTitle, "BOTTOM", 0, -1)
    hitInfo:SetWidth(195)
    hitInfo:SetJustifyH("CENTER")

    local armorTitle = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    armorTitle:SetPoint("TOP", hitInfo, "BOTTOM", 0, -2)
    armorTitle:SetWidth(195)
    armorTitle:SetJustifyH("CENTER")

    local armorInfo = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    armorInfo:SetPoint("TOP", armorTitle, "BOTTOM", 0, -1)
    armorInfo:SetWidth(195)
    armorInfo:SetJustifyH("CENTER")

    local meleeHitTitle = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    meleeHitTitle:SetPoint("TOP", armorInfo, "BOTTOM", 0, -2)
    meleeHitTitle:SetWidth(195)
    meleeHitTitle:SetJustifyH("CENTER")

    local meleeHitInfo = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    meleeHitInfo:SetPoint("TOP", meleeHitTitle, "BOTTOM", 0, -1)
    meleeHitInfo:SetWidth(195)
    meleeHitInfo:SetJustifyH("CENTER")

    local hitNoteTitle = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hitNoteTitle:SetPoint("TOP", meleeHitInfo, "BOTTOM", 0, -2)
    hitNoteTitle:SetWidth(195)
    hitNoteTitle:SetJustifyH("CENTER")

    local hitNoteInfo = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hitNoteInfo:SetPoint("TOP", hitNoteTitle, "BOTTOM", 0, -1)
    hitNoteInfo:SetWidth(195)
    hitNoteInfo:SetJustifyH("CENTER")

    ui.frame = container
    ui.defenseTitle = defenseTitle
    ui.defenseInfo = defenseInfo
    ui.critTitle = critTitle
    ui.critInfo = critInfo
    ui.hitTitle = hitTitle
    ui.hitInfo = hitInfo
    ui.meleeHitTitle = meleeHitTitle
    ui.meleeHitInfo = meleeHitInfo
    ui.hitNoteTitle = hitNoteTitle
    ui.hitNoteInfo = hitNoteInfo
    ui.crushTitle = crushTitle
    ui.crushInfo = crushInfo
    ui.armorTitle = armorTitle
    ui.armorInfo = armorInfo
    ui.altankElements = {
        bg,
        defenseTitle, defenseInfo,
        critTitle, critInfo,
        crushTitle, crushInfo,
        hitTitle, hitInfo,
        armorTitle, armorInfo,
        meleeHitTitle, meleeHitInfo,
        hitNoteTitle, hitNoteInfo,
    }

    if not ui.hooksInstalled then
        parent:HookScript("OnShow", function()
            ui.userClosed = false
            ui.ecsUserClosed = false
            ui.currentPage = 1
            ensureStatsPagerButtons()
            setStatsPage(1)
            updateCharacterTankStats()
        end)
        parent:HookScript("OnHide", function()
            if ui.frame then
                ui.frame:Hide()
            end
            ui.userClosed = false
            ui.ecsUserClosed = false
        end)
        ui.hooksInstalled = true
    end

    ensureStatsPagerButtons()
    setStatsPage(ui.currentPage or 1)
    updateCharacterTankStats()
    return true
end

setStatsPage = function(page)
    local ui = characterStatsUI
    if ui.userClosed then
        if ui.ecsFrame then
            ui.ecsFrame:Hide()
        end
        if ui.frame then
            ui.frame:Hide()
        end
        return
    end
    ui.currentPage = page
    local showAltank = page == 1
    if ui.altankElements then
        for _, element in ipairs(ui.altankElements) do
            if element and element.SetShown then
                element:SetShown(showAltank)
            end
        end
    end
    if ui.ecsFrame then
        ui.ecsFrame:SetShown(page == 2)
    end
    if ui.closeButton then
        ui.closeButton:SetShown(showAltank)
    end
end

ensureStatsPagerButtons = function()
    local ui = characterStatsUI
    if ui.pageButtons or not ui.frame then
        return
    end

    local button1 = CreateFrame("Button", nil, ui.frame, "GameMenuButtonTemplate")
    button1:SetSize(42, 18)
    button1:SetPoint("TOPRIGHT", ui.frame, "TOPRIGHT", -6, -29)
    button1:SetText("Altank")
    button1:SetScript("OnClick", function()
        setStatsPage(1)
    end)

    local button2 = CreateFrame("Button", nil, ui.frame, "GameMenuButtonTemplate")
    button2:SetSize(42, 18)
    button2:SetPoint("RIGHT", button1, "LEFT", -4, 0)
    button2:SetText("ECS")
    button2:SetScript("OnClick", function()
        setStatsPage(2)
    end)

    ui.pageButtons = {button1, button2}
    setStatsPage(1)
end

local function trySetupEcsIntegration()
    local ui = characterStatsUI
    if not ui.frame then
        return false
    end
    local ecsFrame = _G["ECS_StatsFrame"]
    if not ecsFrame then
        return false
    end

    if ecsFrame.configButton then
        ecsFrame.configButton:Hide()
    end
    local toggleButton = _G["ECS_ToggleButton"]
    if toggleButton then
        toggleButton:Hide()
    end
    if not ecsFrame.altankBg then
        local ecsBg = ecsFrame:CreateTexture(nil, "BACKGROUND")
        ecsBg:SetAllPoints(ecsFrame)
        ecsBg:SetColorTexture(0, 0, 0, 0.8)
        ecsFrame.altankBg = ecsBg
    end

    local point, relTo, relPoint, xOfs, yOfs = ecsFrame:GetPoint(1)
    if point and relTo and relPoint then
        ui.frame:ClearAllPoints()
        ui.frame:SetPoint(point, relTo, relPoint, xOfs or 0, yOfs or 0)
        ui.frame:SetSize(ecsFrame:GetSize())
    end

    ui.ecsFrame = ecsFrame
    ecsFrame:SetParent(ui.frame:GetParent())
    ecsFrame:ClearAllPoints()
    ecsFrame:SetPoint(ui.frame:GetPoint(1))
    ecsFrame:SetSize(ui.frame:GetSize())
    ecsFrame:Hide()
    if ui.userClosed then
        return true
    end

    if not ecsFrame.altankHooksInstalled then
        local ecsClose = ecsFrame.CloseButton or _G["ECS_StatsFrameCloseButton"]
        if ecsClose and ecsClose.HookScript then
            ecsClose:HookScript("OnClick", function()
                ui.ecsUserClosed = true
                ui.userClosed = true
                ecsFrame:Hide()
                if ui.frame then
                    ui.frame:Hide()
                end
            end)
        end

        local toggleButton = _G["ECS_ToggleButton"]
        if toggleButton and toggleButton.HookScript then
            toggleButton:HookScript("OnClick", function()
                ui.ecsUserClosed = false
                ui.userClosed = false
                ui.currentPage = 2
                setStatsPage(2)
            end)
        end

        ecsFrame.altankHooksInstalled = true
    end

    ensureStatsPagerButtons()
    setStatsPage(ui.currentPage or 1)
    return true
end

printChat = function(message)
    if type(message) ~= "string" then
        message = tostring(message)
    end
    message = CHAT_PREFIX .. message
    if ChatFrame_ReplaceIconAndGroupExpressions then
        message = ChatFrame_ReplaceIconAndGroupExpressions(message)
    end
    DEFAULT_CHAT_FRAME:AddMessage(message)
end

local function handleSlashCommand(message)
    local msg = (type(message) == "string" and message or "")
    msg = string.lower(strtrim(msg))
    if msg == "whisper" or string.match(msg, "^whisper%s") then
        whisperEnabled = not whisperEnabled
        if AltankDB then
            AltankDB.whisperEnabled = whisperEnabled
        end
        local state = whisperEnabled and "on" or "off"
        printChat("Whisper to pet owners is now " .. state .. ".")
        return
    end
    printChat("Commands: /altank whisper (toggle pet owner whispers)")
end

local function registerSlashCommands()
    SLASH_ALTANK1 = "/altank"
    SlashCmdList.ALTANK = handleSlashCommand
end

local function runVersionCheck()
    local tocVersion
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        tocVersion = C_AddOns.GetAddOnMetadata(addonName, "Version")
    elseif GetAddOnMetadata then
        tocVersion = GetAddOnMetadata(addonName, "Version")
    end
    if tocVersion ~= ADDON_VERSION then
        printChat(string.format("|cffff4444version mismatch: TOC=%s, Lua=%s|r - %s", tostring(tocVersion), ADDON_VERSION, AUTHOR_TAG))
    else
        printChat(string.format("v%s loaded - %s", ADDON_VERSION, AUTHOR_TAG))
    end
    currentAddonVersion = tostring(tocVersion or ADDON_VERSION or "0")
end

local function parseVersionParts(version)
    local parts = {}
    for num in tostring(version or "0"):gmatch("%d+") do
        parts[#parts + 1] = tonumber(num) or 0
    end
    if #parts == 0 then
        parts[1] = 0
    end
    return parts
end

local function isRemoteVersionNewer(remoteVersion, localVersion)
    local remoteParts = parseVersionParts(remoteVersion)
    local localParts = parseVersionParts(localVersion)
    local length = math.max(#remoteParts, #localParts)
    for i = 1, length do
        local remotePart = remoteParts[i] or 0
        local localPart = localParts[i] or 0
        if remotePart ~= localPart then
            return remotePart > localPart
        end
    end
    return false
end

local function handleRemoteVersion(sender, remoteVersion)
    local shortSender = sender and Ambiguate(sender, "short") or "someone"
    local key = tostring(shortSender) .. ":" .. tostring(remoteVersion)
    if versionAlerted[key] then
        return
    end
    if isRemoteVersionNewer(remoteVersion, currentAddonVersion) then
        versionAlerted[key] = true
        printChat(string.format("New version available: v%s. Update your addon.", tostring(remoteVersion)))
    end
end

local function sendVersionBroadcast()
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        return
    end
    local now = GetTime()
    if lastVersionBroadcastAt and (now - lastVersionBroadcastAt) < 10 then
        return
    end
    lastVersionBroadcastAt = now

    local payload = "V\t" .. tostring(currentAddonVersion or ADDON_VERSION or "0")
    local channel = getCommChannel and getCommChannel() or nil
    if channel then
        C_ChatInfo.SendAddonMessage(VERSION_PREFIX, payload, channel)
    end
    if IsInGuild and IsInGuild() then
        C_ChatInfo.SendAddonMessage(VERSION_PREFIX, payload, "GUILD")
    end
end

local function getCommChannel()
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

local function sendCCToPartyChat(message)
    if type(message) ~= "string" or message == "" then
        return
    end
    if not SendChatMessage then
        return
    end

    local channel = getCommChannel()
    if channel then
        SendChatMessage(PARTY_PREFIX .. message, channel)
    end
end

local function formatCCMessage(effectName, duration)
    local name = (type(effectName) == "string" and effectName ~= "") and effectName or "cc"
    if type(duration) == "number" and duration > 0 then
        return string.format("i can't do anything for %ds. %s", math.floor(duration + 0.5), name)
    end
    return string.format("i can't do anything. %s", name)
end

sendSync = function(eventId, message)
    if type(eventId) == "string" and eventId ~= "" then
        shouldPrint(GetTime(), eventId)
    end
    local channel = getCommChannel()
    if not channel or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        return
    end
    C_ChatInfo.SendAddonMessage(COMM_PREFIX, eventId .. "\t" .. message, channel)
end

local function roleIcon(role)
    if role == "TANK" then
        return "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:0:19:22:41|t "
    end
    if role == "HEALER" then
        return "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:20:39:1:20|t "
    end
    if role == "DAMAGER" then
        return "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:20:39:22:41|t "
    end
    return ""
end

local function isRole(unit, role)
    return UnitGroupRolesAssigned(unit) == role
end

local function setRoleAndRefresh(unit, role)
    UnitSetRole(unit, role)
    if UnitIsUnit(unit, "player") then
        updateRighteousFuryWarning()
        updateRangeWarning()
        C_Timer.After(0, function()
            updateRighteousFuryWarning()
            updateRangeWarning()
        end)
    end
end

local function canEditRole(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
        return false
    end
    if not IsInGroup() and not IsInRaid() then
        return false
    end
    if UnitIsUnit(unit, "player") then
        return true
    end
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

local function installModernRoleMenuHooks()
    if not Menu or not Menu.ModifyMenu or not MenuUtil or not MenuUtil.CreateButton or not UnitSetRole then
        return false
    end

    local function setupRoleMenu(rootDescription, contextData)
        if not rootDescription or not contextData or not contextData.unit then
            return
        end
        if LFGParentFrame and LFGParentFrame.IsShown and LFGParentFrame:IsShown() then
            return
        end
        if rootDescription.EnumerateElementDescriptions then
            for _, elementData in rootDescription:EnumerateElementDescriptions() do
                if elementData and elementData.isAltankRoleMenu then
                    return
                end
            end
        end

        local unit = contextData.unit
        if not UnitExists(unit) or not UnitIsPlayer(unit) then
            return
        end

        local roleMenu = MenuUtil.CreateButton("Altank: Select Role")
        roleMenu.isAltankRoleMenu = true
        rootDescription:Insert(roleMenu, 2)
        roleMenu:SetEnabled(canEditRole(unit))

        roleMenu:CreateRadio(
            roleIcon("TANK") .. "Tank",
            function() return isRole(unit, "TANK") end,
            function() setRoleAndRefresh(unit, "TANK") end
        )

        roleMenu:CreateRadio(
            roleIcon("HEALER") .. "Healer",
            function() return isRole(unit, "HEALER") end,
            function() setRoleAndRefresh(unit, "HEALER") end
        )

        roleMenu:CreateRadio(
            roleIcon("DAMAGER") .. "Damage",
            function() return isRole(unit, "DAMAGER") end,
            function() setRoleAndRefresh(unit, "DAMAGER") end
        )

        roleMenu:CreateRadio(
            "No Role",
            function() return isRole(unit, "NONE") end,
            function() setRoleAndRefresh(unit, "NONE") end
        )
    end

    local menuTypes = {
        "MENU_UNIT_SELF",
        "MENU_UNIT_PARTY",
        "MENU_UNIT_RAID",
        "MENU_UNIT_PLAYER",
    }
    local installedAny = false
    for i = 1, #menuTypes do
        local menuType = menuTypes[i]
        local ok = pcall(Menu.ModifyMenu, menuType, function(_, rootDescription, contextData)
            setupRoleMenu(rootDescription, contextData)
        end)
        if ok then
            installedAny = true
        end
    end
    return installedAny
end

local legacyPopupState = {
    hooked = false,
    unitByDropdown = setmetatable({}, { __mode = "k" }),
}

local function insertLegacyPopupButton(menuName, buttonName)
    local menu = UnitPopupMenus and UnitPopupMenus[menuName]
    if type(menu) ~= "table" then
        return
    end
    for i = 1, #menu do
        if menu[i] == buttonName then
            return
        end
    end
    table.insert(menu, buttonName)
end

local function installLegacyRoleMenuHooks()
    if not UnitPopupButtons or not UnitPopupMenus or not UnitSetRole then
        return false
    end

    UnitPopupButtons.ALTANK_ROLE_HEADER = {
        text = "Altank: Select Role",
        dist = 0,
        isTitle = 1,
        notCheckable = 1,
    }
    UnitPopupButtons.ALTANK_ROLE_TANK = { text = roleIcon("TANK") .. "Tank", dist = 0, notCheckable = 1 }
    UnitPopupButtons.ALTANK_ROLE_HEALER = { text = roleIcon("HEALER") .. "Healer", dist = 0, notCheckable = 1 }
    UnitPopupButtons.ALTANK_ROLE_DAMAGE = { text = roleIcon("DAMAGER") .. "Damage", dist = 0, notCheckable = 1 }
    UnitPopupButtons.ALTANK_ROLE_NONE = { text = "No Role", dist = 0, notCheckable = 1 }

    local menus = {
        "SELF",
        "PARTY",
        "PLAYER",
        "RAID_PLAYER",
        "RAID",
    }
    for i = 1, #menus do
        local menuName = menus[i]
        insertLegacyPopupButton(menuName, "ALTANK_ROLE_HEADER")
        insertLegacyPopupButton(menuName, "ALTANK_ROLE_TANK")
        insertLegacyPopupButton(menuName, "ALTANK_ROLE_HEALER")
        insertLegacyPopupButton(menuName, "ALTANK_ROLE_DAMAGE")
        insertLegacyPopupButton(menuName, "ALTANK_ROLE_NONE")
    end

    if not legacyPopupState.hooked then
        if UnitPopup_ShowMenu then
            hooksecurefunc("UnitPopup_ShowMenu", function(dropdownMenu, _, unit)
                if dropdownMenu then
                    legacyPopupState.unitByDropdown[dropdownMenu] = unit
                end
            end)
        end
        if UnitPopup_OnClick then
            hooksecurefunc("UnitPopup_OnClick", function(buttonFrame)
                local value = buttonFrame and buttonFrame.value
                if value ~= "ALTANK_ROLE_TANK"
                    and value ~= "ALTANK_ROLE_HEALER"
                    and value ~= "ALTANK_ROLE_DAMAGE"
                    and value ~= "ALTANK_ROLE_NONE" then
                    return
                end

                local dropdown = UIDROPDOWNMENU_INIT_MENU
                local unit = dropdown and (legacyPopupState.unitByDropdown[dropdown] or dropdown.unit)
                if not canEditRole(unit) then
                    return
                end

                if value == "ALTANK_ROLE_TANK" then
                    setRoleAndRefresh(unit, "TANK")
                elseif value == "ALTANK_ROLE_HEALER" then
                    setRoleAndRefresh(unit, "HEALER")
                elseif value == "ALTANK_ROLE_DAMAGE" then
                    setRoleAndRefresh(unit, "DAMAGER")
                else
                    setRoleAndRefresh(unit, "NONE")
                end
            end)
        end
        legacyPopupState.hooked = true
    end

    return true
end

local function installRoleMenuHooks()
    if not ENABLE_ROLE_MENU_HOOKS or roleMenuHooksInstalled then
        return
    end
    local modernInstalled = installModernRoleMenuHooks()
    local legacyInstalled = installLegacyRoleMenuHooks()
    roleMenuHooksInstalled = modernInstalled or legacyInstalled
end

local function isSelfSender(sender)
    if not sender then
        return true
    end
    return Ambiguate(sender, "short") == Ambiguate(UnitName("player") or "", "short")
end

local function classColorName(name, sourceGUID, sourceFlags)
    if bit.band(sourceFlags or 0, COMBATLOG_OBJECT_TYPE_PET) > 0 then
        return "|c" .. NAME_COLORS.HUNTER_PET .. name .. "|r"
    end

    local _, classToken = GetPlayerInfoByGUID(sourceGUID or "")
    if classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
        local color = RAID_CLASS_COLORS[classToken].colorStr
        if color then
            return "|c" .. color .. name .. "|r"
        end
    end

    return name
end

local function isRelevantEvent(subEvent)
    return subEvent == "SPELL_AURA_APPLIED"
        or subEvent == "SPELL_MISSED"
        or subEvent == "SPELL_CAST_SUCCESS"
end

local function isGroupSource(flags)
    return bit.band(flags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0
        or bit.band(flags, COMBATLOG_OBJECT_AFFILIATION_PARTY) > 0
        or bit.band(flags, COMBATLOG_OBJECT_AFFILIATION_RAID) > 0
end

shouldPrint = function(now, key)
    local last = recent[key]
    if last and (now - last) < RECENT_WINDOW then
        return false
    end
    recent[key] = now
    return true
end

local function getLossOfControlInfoByIndex(index)
    if not index then
        return nil
    end

    if C_LossOfControl and C_LossOfControl.GetEventInfo then
        local locType, spellID, text, _, _, _, duration = C_LossOfControl.GetEventInfo(index)
        if locType ~= nil then
            return locType, spellID, text, duration
        end
    end

    if C_LossOfControl and C_LossOfControl.GetActiveLossOfControlData then
        local tab = C_LossOfControl.GetActiveLossOfControlData(index)
        if tab ~= nil then
            return tab.locType or tab.type, tab.spellID or tab.spellId, tab.displayText or tab.text, tab.duration or tab.timeRemaining, tab.startTime
        end
    end

    if GetLossOfControlInfo then
        local locType, spellID, text, displayText, _, startTime, _, duration = GetLossOfControlInfo(index)
        return locType, spellID, displayText or text, duration, startTime
    end

    return nil
end

local function incapDedupeKey(spellID, fallbackText)
    if type(spellID) == "number" and spellID > 0 then
        return "INCAP:" .. tostring(spellID)
    end
    local text = (type(fallbackText) == "string" and fallbackText ~= "") and string.lower(fallbackText) or "unknown"
    return "INCAPTXT:" .. text
end

local function reportIncapacitation(index)
    local locType, spellID, locText, duration = getLossOfControlInfoByIndex(index)
    if not isIncapLocType(locType) then
        return
    end
    locType = string.upper(tostring(locType))

    local effectName = (type(locText) == "string" and locText ~= "") and locText or (spellID and GetSpellInfo(spellID)) or locType:lower()
    local now = GetTime()
    local key = table.concat({"CC", tostring(spellID or 0), locType}, ":")
    local spellKey = incapDedupeKey(spellID, effectName)
    if not shouldPrint(now, key) or not shouldPrint(now, spellKey) then
        return
    end

    activeIncapEvents[table.concat({tostring(spellID or 0), locType}, ":")] = true
    local msg = formatCCMessage(effectName, duration)
    printChat(msg)
    sendCCToPartyChat(msg)
    sendSync("CC:" .. key, msg)
end

local function scanIncapacitations()
    if not GetNumLossOfControlEvents then
        return
    end

    local count = GetNumLossOfControlEvents() or 0
    if count <= 0 then
        activeIncapEvents = {}
        return
    end

    local seen = {}
    for i = 1, count do
        local locType, spellID, locText, duration = getLossOfControlInfoByIndex(i)
        local upperLocType = type(locType) == "string" and string.upper(locType) or nil
        if upperLocType and isIncapLocType(upperLocType) then
            local eventKey = table.concat({tostring(spellID or 0), upperLocType}, ":")
            seen[eventKey] = true

            if not activeIncapEvents[eventKey] then
                local effectName = (type(locText) == "string" and locText ~= "") and locText or (spellID and GetSpellInfo(spellID)) or upperLocType:lower()
                local spellKey = incapDedupeKey(spellID, effectName)
                if shouldPrint(GetTime(), spellKey) then
                    local msg = formatCCMessage(effectName, duration)
                    printChat(msg)
                    sendCCToPartyChat(msg)
                    sendSync("CC:SCAN:" .. eventKey, msg)
                end
                activeIncapEvents[eventKey] = true
            end
        end
    end

    for key in pairs(activeIncapEvents) do
        if not seen[key] then
            activeIncapEvents[key] = nil
        end
    end
end

local function isPetGrowl(spellName, sourceFlags)
    if not PET_GROWL_NAME or spellName ~= PET_GROWL_NAME then
        return false
    end
    return bit.band(sourceFlags or 0, COMBATLOG_OBJECT_TYPE_PET) > 0
end

local PET_TAUNT_NAME_PATTERNS = {
    "growl",
    "torment",
    "anguish",
    "suffering",
}

local function isPetTauntSpell(spellID, spellName, sourceFlags)
    if bit.band(sourceFlags or 0, COMBATLOG_OBJECT_TYPE_PET) == 0 then
        return false
    end
    if TAUNT_SPELLS[spellID] or isPetGrowl(spellName, sourceFlags) then
        return true
    end
    if type(spellName) ~= "string" or spellName == "" then
        return false
    end
    local lowerName = string.lower(spellName)
    for i = 1, #PET_TAUNT_NAME_PATTERNS do
        if string.find(lowerName, PET_TAUNT_NAME_PATTERNS[i], 1, true) then
            return true
        end
    end
    return false
end

local function colorName(name, spellID, spellName, sourceFlags)
    local classKey = CLASS_BY_SPELL[spellID]
    if not classKey and isPetGrowl(spellName, sourceFlags) then
        classKey = "HUNTER_PET"
    end

    local color = classKey and NAME_COLORS[classKey]
    if not color then
        return name
    end
    return "|c" .. color .. name .. "|r"
end

local function markerTokenFromRaidFlags(destRaidFlags)
    if not destRaidFlags or destRaidFlags == 0 then
        return ""
    end

    for i = 1, #MARKER_TOKENS do
        local marker = MARKER_TOKENS[i]
        if bit.band(destRaidFlags, marker.flag) > 0 then
            return " " .. marker.token
        end
    end

    return ""
end

local function markerTokenForDest(destGUID, destRaidFlags)
    local fromCombatLog = markerTokenFromRaidFlags(destRaidFlags)
    if fromCombatLog ~= "" then
        return fromCombatLog
    end

    if destGUID and UnitExists("target") and UnitGUID("target") == destGUID then
        local index = GetRaidTargetIndex("target")
        if index and MARKER_TOKEN_BY_INDEX[index] then
            return MARKER_TOKEN_BY_INDEX[index]
        end
    end

    return ""
end

local function markerTokenForUnit(unit)
    if not unit or not UnitExists(unit) then
        return ""
    end
    local index = GetRaidTargetIndex(unit)
    if index and MARKER_TOKEN_BY_INDEX[index] then
        return MARKER_TOKEN_BY_INDEX[index]
    end
    return ""
end

local function isHostileNonPlayer(flags)
    if not flags then
        return false
    end
    local hostile = bit.band(flags, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0
    local player = bit.band(flags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
    return hostile and not player
end

local INCAP_NAME_PATTERNS = {
    "stun",
    "fear",
    "horror",
    "charm",
    "disorient",
    "incapacitate",
    "sap",
    "polymorph",
    "hammer of justice",
    "cheap shot",
    "kidney shot",
    "bash",
    "war stomp",
    "concussion blow",
    "shadowfury",
    "intimidation",
    "talon of justice",
}

local function isLikelyIncapSpellName(spellName)
    if type(spellName) ~= "string" or spellName == "" then
        return false
    end
    local lowerName = string.lower(spellName)
    for i = 1, #INCAP_NAME_PATTERNS do
        if string.find(lowerName, INCAP_NAME_PATTERNS[i], 1, true) then
            return true
        end
    end
    return false
end

local function getActivePlayerDebuffDuration(spellID, spellName)
    if not UnitDebuff then
        return nil
    end

    for i = 1, 40 do
        local r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, r16 = UnitDebuff("player", i)
        local name = r1
        if not name then
            break
        end

        local matched = false
        local auraSpellID = (type(r11) == "number" and r11) or (type(r10) == "number" and r10) or (type(r12) == "number" and r12)
        if spellID and auraSpellID and spellID == auraSpellID then
            matched = true
        elseif spellName and name == spellName then
            matched = true
        end

        if matched then
            local duration
            local expirationTime
            -- API layouts differ by client version:
            -- newer layout: 5=debuffType, 6=duration, 7=expiration
            -- older layout: 5=duration, 6=expiration
            if type(r6) == "number" and type(r7) == "number" then
                duration = r6
                expirationTime = r7
            elseif type(r5) == "number" and type(r6) == "number" then
                duration = r5
                expirationTime = r6
            elseif type(r6) == "number" then
                duration = r6
            elseif type(r5) == "number" then
                duration = r5
            end

            if type(expirationTime) == "number" and expirationTime > 0 and GetTime then
                local remaining = expirationTime - GetTime()
                if remaining > 0 and remaining <= 600 then
                    return remaining
                end
            end

            if type(duration) == "number" and duration > 0 and duration <= 600 then
                return duration
            end
        end
    end

    return nil
end

local function classColorNameByUnit(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end

    local name = UnitName(unit)
    if not name then
        return nil
    end
    name = Ambiguate(name, "short")

    if string.find(unit, "pet", 1, true) then
        return "|c" .. NAME_COLORS.HUNTER_PET .. name .. "|r"
    end

    local _, classToken = UnitClass(unit)
    if classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
        local color = RAID_CLASS_COLORS[classToken].colorStr
        if color then
            return "|c" .. color .. name .. "|r"
        end
    end

    return name
end

local function forEachGroupUnit(callback)
    callback("player")
    callback("pet")

    if IsInRaid() then
        local count = GetNumGroupMembers()
        for i = 1, count do
            callback("raid" .. i)
            callback("raidpet" .. i)
        end
    elseif IsInGroup() then
        local count = GetNumSubgroupMembers()
        for i = 1, count do
            callback("party" .. i)
            callback("partypet" .. i)
        end
    end
end

local function ownerUnitForPetUnit(petUnit)
    if petUnit == "pet" then
        return "player"
    end
    local idx = string.match(petUnit or "", "^partypet(%d+)$")
    if idx then
        return "party" .. idx
    end
    idx = string.match(petUnit or "", "^raidpet(%d+)$")
    if idx then
        return "raid" .. idx
    end
    return nil
end

local function findPetOwnerInfoByGUID(petGUID)
    if not petGUID or petGUID == "" then
        return nil
    end

    local ownerName
    local ownerClass
    forEachGroupUnit(function(unit)
        if ownerName or not unit or not UnitExists(unit) then
            return
        end
        if string.find(unit, "pet", 1, true) then
            local guid = UnitGUID(unit)
            if guid and guid == petGUID then
                local ownerUnit = ownerUnitForPetUnit(unit)
                if ownerUnit and UnitExists(ownerUnit) then
                    ownerName = GetUnitName(ownerUnit, true) or UnitName(ownerUnit)
                    local _, classToken = UnitClass(ownerUnit)
                    ownerClass = classToken
                end
            end
        end
    end)
    if not ownerName then
        return nil
    end
    return ownerName, ownerClass
end

local function isGroupUnitToken(unit)
    if not unit or not UnitExists(unit) then
        return false
    end

    local inGroup = false
    forEachGroupUnit(function(groupUnit)
        if not inGroup and UnitExists(groupUnit) and UnitIsUnit(unit, groupUnit) then
            inGroup = true
        end
    end)
    return inGroup
end

local function findHighestThreatSource(targetUnit)
    local bestUnit
    local bestThreat = 0

    forEachGroupUnit(function(groupUnit)
        if UnitExists(groupUnit) then
            local _, _, _, _, threatValue = UnitDetailedThreatSituation(groupUnit, targetUnit)
            if threatValue and threatValue > bestThreat then
                bestThreat = threatValue
                bestUnit = groupUnit
            end
        end
    end)

    return bestUnit, bestThreat
end

local function detectBodyPullOnUnit(unit)
    if not unit or not UnitExists(unit) or not UnitCanAttack("player", unit) or UnitIsDead(unit) then
        return nil, nil, nil
    end

    local sourceUnit, threat = findHighestThreatSource(unit)
    if sourceUnit and threat and threat > 0 then
        return sourceUnit, threat, "THREAT"
    end

    local targetUnit = unit .. "target"
    if UnitExists(targetUnit) and isGroupUnitToken(targetUnit) and UnitAffectingCombat(unit) then
        return targetUnit, 0, "TARGET"
    end

    return nil, nil, nil
end

local function checkBodyPullFromThreat(hintUnit)
    if announcedPullThisCombat then
        return
    end

    local candidates = {}
    local candidateSeen = {}
    local function addCandidate(unit)
        if unit and UnitExists(unit) and not candidateSeen[unit] then
            candidateSeen[unit] = true
            candidates[#candidates + 1] = unit
        end
    end

    addCandidate(hintUnit)
    addCandidate("target")
    addCandidate("focus")
    addCandidate("mouseover")

    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates()
        for i = 1, #plates do
            local plate = plates[i]
            addCandidate(plate and (plate.namePlateUnitToken or plate.unitToken or (plate.UnitFrame and plate.UnitFrame.unit)))
        end
    end

    for i = 1, #candidates do
        local unit = candidates[i]
        local sourceUnit = nil
        local pullType = nil
        sourceUnit, _, pullType = detectBodyPullOnUnit(unit)
        if sourceUnit then
            local pullerName = classColorNameByUnit(sourceUnit)
            local targetName = Ambiguate(UnitName(unit) or "Unknown", "short") .. markerTokenForUnit(unit)
            if pullerName and targetName then
                announcedPullThisCombat = true
                local msg = string.format("%s body pulled %s.", pullerName, targetName)
                local eventId = "BP:" .. pullType .. ":" .. (UnitGUID(sourceUnit) or sourceUnit) .. ":" .. (UnitGUID(unit) or unit)
                if shouldPrint(GetTime(), eventId) then
                    printChat(msg)
                    sendSync(eventId, msg)
                end
                return
            end
        end
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UNIT_TARGET")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("COMBAT_RATING_UPDATE")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
frame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UNIT_HEALTH_FREQUENT")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("CHARACTER_POINTS_CHANGED")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_UNGHOST")
frame:RegisterEvent("PLAYER_CONTROL_LOST")
frame:RegisterEvent("PLAYER_CONTROL_GAINED")
frame:RegisterEvent("LOSS_OF_CONTROL_ADDED")
frame:RegisterEvent("LOSS_OF_CONTROL_UPDATE")
frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
frame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
frame:RegisterEvent("ACTIONBAR_UPDATE_STATE")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local arg1 = ...
        if arg1 == addonName then
            if type(AltankDB) ~= "table" then
                AltankDB = {}
            end
            if AltankDB.whisperEnabled == nil then
                AltankDB.whisperEnabled = true
            end
            whisperEnabled = AltankDB.whisperEnabled and true or false
            if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
                C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
                C_ChatInfo.RegisterAddonMessagePrefix(VERSION_PREFIX)
            end
            registerSlashCommands()
            installRoleMenuHooks()
            runVersionCheck()
            C_Timer.After(2, function()
                sendVersionBroadcast()
            end)
            ensureCharacterTankStatsUI()
            ensureRighteousFuryWarningUI()
            ensureDefensiveStanceWarningUI()
            ensureRangeWarningUI()
            ensureDebuffTrackerUI()
            updateDebuffTrackerRosterCache()
            startDebuffTrackerTicker()
            updateDebuffTrackerDisplay()
            updateRighteousFuryWarning()
            updateDefensiveStanceWarning()
            updateRangeWarning()
            C_Timer.After(0, function()
                ensureCharacterTankStatsUI()
                trySetupEcsIntegration()
                updateCharacterTankStats()
                updateRighteousFuryWarning()
                updateDefensiveStanceWarning()
                updateRangeWarning()
                updateDebuffTrackerRosterCache()
                updateDebuffTrackerDisplay()
            end)
        end
        if arg1 == "ExtendedCharacterStats" then
            C_Timer.After(0, function()
                trySetupEcsIntegration()
            end)
        end
        return
    end
    if Altank_HandleRaidEncounterFeatures and Altank_HandleRaidEncounterFeatures(event, ...) then
        return
    end
    if event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT" then
        return
    end
    if event == "ACTIONBAR_SLOT_CHANGED" then
        warriorRangeActionSlot = nil
        return
    end
    if event == "ACTIONBAR_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_STATE" then
        return
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "COMBAT_RATING_UPDATE" or event == "SKILL_LINES_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "CHARACTER_POINTS_CHANGED" or event == "PLAYER_LEVEL_UP" or event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" or event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" or event == "PLAYER_CONTROL_LOST" or event == "PLAYER_CONTROL_GAINED" or event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_LOGIN" then
            sendVersionBroadcast()
            updateDebuffTrackerRosterCache()
            updateDebuffTrackerDisplay()
        elseif event == "PLAYER_ROLES_ASSIGNED" then
            updateDebuffTrackerRosterCache()
            updateDebuffTrackerDisplay()
        end
        if ensureCharacterTankStatsUI() then
            trySetupEcsIntegration()
            updateCharacterTankStats()
        end
        if event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS" then
            warriorRangeActionSlot = nil
        end
        if event == "PLAYER_REGEN_ENABLED" then
            announcedPullThisCombat = false
        end
        updateRighteousFuryWarning()
        updateDefensiveStanceWarning()
        updateRangeWarning()
        return
    end
    if event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" and ensureCharacterTankStatsUI() then
            updateCharacterTankStats()
        end
        if unit == "player" then
            scanIncapacitations()
            updateRighteousFuryWarning()
        end
        if unit == "target" then
            updateDebuffTrackerDisplay()
        end
        return
    end
    if event == "LOSS_OF_CONTROL_ADDED" then
        local unitToken, eventIndex = ...
        if eventIndex == nil then
            eventIndex = unitToken
        end
        reportIncapacitation(eventIndex)
        scanIncapacitations()
        return
    end
    if event == "LOSS_OF_CONTROL_UPDATE" then
        scanIncapacitations()
        return
    end
    if event == "CHAT_MSG_ADDON" then
        local prefix, payload, _, sender = ...
        if prefix == VERSION_PREFIX then
            if payload and not isSelfSender(sender) then
                local kind, remoteVersion = strsplit("\t", payload, 2)
                if kind == "V" and remoteVersion and remoteVersion ~= "" then
                    handleRemoteVersion(sender, remoteVersion)
                end
            end
            return
        end
        if prefix ~= COMM_PREFIX or not payload or isSelfSender(sender) then
            return
        end
        local eventId, remoteMsg = strsplit("\t", payload, 2)
        if not eventId or not remoteMsg or remoteMsg == "" then
            return
        end
        if shouldPrint(GetTime(), eventId) then
            printChat(remoteMsg)
        end
        return
    end

    if event == "UNIT_THREAT_LIST_UPDATE" or event == "NAME_PLATE_UNIT_ADDED" or event == "PLAYER_TARGET_CHANGED" then
        local unit = ...
        if event == "PLAYER_TARGET_CHANGED" then
            updateDebuffTrackerDisplay()
        end
        checkBodyPullFromThreat(unit)
        return
    end
    if event == "UNIT_TARGET" then
        local unit = ...
        if unit and (string.find(unit, "nameplate", 1, true) == 1 or unit == "target" or unit == "focus" or unit == "mouseover") then
            checkBodyPullFromThreat(unit)
        end
        return
    end

    local _, subEvent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, _, arg15, arg16 = CombatLogGetCurrentEventInfo()

    local isTaunt = (TAUNT_SPELLS[spellID] or isPetTauntSpell(spellID, spellName, sourceFlags)) and isRelevantEvent(subEvent)
    local isPetTaunt = isPetTauntSpell(spellID, spellName, sourceFlags)
    local isMisdirection = (spellID == MISDIRECTION_SPELL_ID and subEvent == "SPELL_CAST_SUCCESS")
    local isPull = (not announcedPullThisCombat) and PULL_EVENTS[subEvent] and isHostileNonPlayer(destFlags)
    local isInterrupt = (subEvent == "SPELL_INTERRUPT")
    local isIncapOnMe = (subEvent == "SPELL_AURA_APPLIED" and destGUID == UnitGUID("player") and arg15 == "DEBUFF" and isLikelyIncapSpellName(spellName))

    if not isTaunt and not isMisdirection and not isPull and not isInterrupt and not isIncapOnMe then
        return
    end
    if not sourceName or not destName then
        return
    end
    if not isIncapOnMe and not isGroupSource(sourceFlags) then
        return
    end

    local now = GetTime()
    local playerName = colorName(Ambiguate(sourceName, "short"), spellID, spellName, sourceFlags)
    local classPlayerName = classColorName(Ambiguate(sourceName, "short"), sourceGUID, sourceFlags)
    local targetName = Ambiguate(destName, "short") .. markerTokenForDest(destGUID, destRaidFlags)

    if isIncapOnMe then
        local incapKey = table.concat({"CCLOG", tostring(spellID or 0), sourceGUID or "", destGUID or ""}, ":")
        local incapEventId = "CC:" .. incapKey
        local spellKey = incapDedupeKey(spellID, spellName)
        if shouldPrint(now, incapEventId) and shouldPrint(now, spellKey) then
            local sourceDisplay = classColorName(Ambiguate(sourceName, "short"), sourceGUID, sourceFlags)
            local debuffDuration = getActivePlayerDebuffDuration(spellID, spellName)
            local msg = formatCCMessage(spellName or "incapacitate", debuffDuration)
            printChat(msg)
            sendCCToPartyChat(msg)
            sendSync(incapEventId, msg)
        end
        return
    end

    if isPull then
        announcedPullThisCombat = true
        local pullAbility
        if subEvent == "SWING_DAMAGE" then
            pullAbility = "Auto Attack"
        elseif subEvent == "RANGE_DAMAGE" or subEvent == "RANGE_MISSED" then
            if type(spellName) == "string" and spellName ~= "" then
                pullAbility = spellName
            else
                pullAbility = "Ranged Attack"
            end
        elseif type(spellName) == "string" and spellName ~= "" then
            pullAbility = spellName
            else
                pullAbility = "Spell"
            end
        local pullMsg = string.format("%s pulled %s using %s.", classPlayerName, targetName, pullAbility)
        local pullEventId = "P:" .. (sourceGUID or "") .. ":" .. (destGUID or "") .. ":" .. tostring(spellID or 0)
        if shouldPrint(now, pullEventId) then
            printChat(pullMsg)
            sendSync(pullEventId, pullMsg)
        end
    end

    if isInterrupt then
        local interruptedSpell = (type(arg16) == "string" and arg16 ~= "") and arg16 or "a spell"
        local interruptAbility = (type(spellName) == "string" and spellName ~= "") and spellName or "an interrupt"
        local interruptKey = table.concat({"INT", sourceGUID or "", tostring(spellID or ""), destGUID or "", interruptedSpell}, ":")
        if shouldPrint(now, interruptKey) then
            local interruptMsg = string.format("%s interrupted %s on %s using %s.", classPlayerName, interruptedSpell, targetName, interruptAbility)
            printChat(interruptMsg)
            sendSync(interruptKey, interruptMsg)
        end
    end

    if not isTaunt and not isMisdirection then
        return
    end
    if not spellName then
        return
    end

    local dedupeKey = table.concat({sourceGUID or "", tostring(spellID or ""), destGUID or ""}, ":")

    if isTaunt and subEvent == "SPELL_MISSED" then
        local tauntMissEventId = "T:" .. dedupeKey .. ":M"
        if not shouldPrint(now, tauntMissEventId) then
            return
        end
        local missType = (type(arg15) == "string" and arg15 ~= "") and string.lower(arg15) or "missed"
        local failedMsg = string.format("%s used %s on %s (%s).", playerName, spellName, targetName, missType)
        printChat(failedMsg)
        sendSync(tauntMissEventId, failedMsg)
        if isPetTaunt then
            local ownerName, ownerClass = findPetOwnerInfoByGUID(sourceGUID)
            if whisperEnabled and ownerName and SendChatMessage and shouldPrint(now, "W:" .. dedupeKey .. ":M") and shouldSendWhisper(now, ownerName) then
                local who = "huntard"
                local petType = "pet"
                if ownerClass == "WARLOCK" then
                    who = "locktard"
                    petType = "demon"
                end
                SendChatMessage(PARTY_PREFIX .. who .. ". turn off taunt on your " .. petType .. ".", "WHISPER", nil, ownerName)
            end
        end
        return
    end

    local tauntEventId = "T:" .. dedupeKey
    if not shouldPrint(now, tauntEventId) then
        return
    end
    local tauntMsg = string.format("%s used %s on %s.", playerName, spellName, targetName)
    if isMisdirection then
        tauntMsg = "|cff3399ff" .. tauntMsg .. "|r"
    end
    printChat(tauntMsg)
    sendSync(tauntEventId, tauntMsg)
    if isPetTaunt then
        local ownerName, ownerClass = findPetOwnerInfoByGUID(sourceGUID)
        if whisperEnabled and ownerName and SendChatMessage and shouldPrint(now, "W:" .. dedupeKey) and shouldSendWhisper(now, ownerName) then
            local who = "huntard"
            local petType = "pet"
            if ownerClass == "WARLOCK" then
                who = "locktard"
                petType = "demon"
            end
            SendChatMessage(PARTY_PREFIX .. who .. ". turn off taunt on your " .. petType .. ".", "WHISPER", nil, ownerName)
        end
    end
end)

local rangeCheckFrame = CreateFrame("Frame")
rangeCheckFrame:SetScript("OnUpdate", function(_, elapsed)
    rangeCheckElapsed = rangeCheckElapsed + elapsed
    defensiveCheckElapsed = defensiveCheckElapsed + elapsed
    if rangeCheckElapsed < RANGE_CHECK_INTERVAL then
        return
    end
    rangeCheckElapsed = 0
    updateRangeWarning()
    if defensiveCheckElapsed >= RANGE_CHECK_INTERVAL then
        defensiveCheckElapsed = 0
        updateDefensiveStanceWarning()
    end
end)
