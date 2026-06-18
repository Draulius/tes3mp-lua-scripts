-- =====================================================
-- Retroactive Health - TES3MP 0.8.1
-- Made by Lindran originally for Mahkan Server, now released for public use
-- Use or edit the script as you see fit, I just request you give me credit
-- =====================================================
-- Note: Staff characters are not corrected on login
-- ====================== CONFIG =======================
local allowHealthDecrease = false    -- If true, allows HP to be corrected downwards (less safe for boosted characters)
local applyLadyBonus      = false    -- If true, The Lady birthsign gives +25 Endurance to all health gains. Keep false for default TES3MP 0.8.1 behavior
-- =====================================================
--Do not edit below unless you know what you are doing

local startingStats = {
    ["argonian"]  = { str = { [0] = 40, [1] = 40 }, endu = { [0] = 30, [1] = 30 } },
    ["breton"]    = { str = { [0] = 40, [1] = 30 }, endu = { [0] = 30, [1] = 30 } },
    ["dark elf"]  = { str = { [0] = 40, [1] = 40 }, endu = { [0] = 40, [1] = 30 } },
    ["high elf"]  = { str = { [0] = 30, [1] = 30 }, endu = { [0] = 40, [1] = 30 } },
    ["imperial"]  = { str = { [0] = 40, [1] = 40 }, endu = { [0] = 40, [1] = 40 } },
    ["khajiit"]   = { str = { [0] = 40, [1] = 30 }, endu = { [0] = 30, [1] = 40 } },
    ["nord"]      = { str = { [0] = 50, [1] = 50 }, endu = { [0] = 50, [1] = 40 } },
    ["orc"]       = { str = { [0] = 45, [1] = 45 }, endu = { [0] = 50, [1] = 50 } },
    ["redguard"]  = { str = { [0] = 50, [1] = 40 }, endu = { [0] = 50, [1] = 50 } },
    ["wood elf"]  = { str = { [0] = 30, [1] = 30 }, endu = { [0] = 30, [1] = 30 } },
}

local vanillaClassFavored = {
    ["acrobat"]      = {"Agility", "Endurance"},
    ["agent"]        = {"Personality", "Speed"},
    ["archer"]       = {"Agility", "Strength"},
    ["assassin"]     = {"Agility", "Intelligence"},
    ["barbarian"]    = {"Strength", "Speed"},
    ["bard"]         = {"Personality", "Intelligence"},
    ["battlemage"]   = {"Intelligence", "Strength"},
    ["crusader"]     = {"Willpower", "Strength"},
    ["healer"]       = {"Willpower", "Personality"},
    ["knight"]       = {"Strength", "Personality"},
    ["mage"]         = {"Intelligence", "Willpower"},
    ["monk"]         = {"Agility", "Willpower"},
    ["nightblade"]   = {"Willpower", "Speed"},
    ["pilgrim"]      = {"Personality", "Endurance"},
    ["rogue"]        = {"Speed", "Personality"},
    ["scout"]        = {"Endurance", "Speed"},
    ["sorcerer"]     = {"Intelligence", "Endurance"},
    ["spellsword"]   = {"Willpower", "Endurance"},
    ["thief"]        = {"Speed", "Agility"},
    ["warrior"]      = {"Strength", "Endurance"},
    ["witchhunter"]  = {"Intelligence", "Agility"},
}

local function getAttributeId(name)
    local id = tes3mp.GetAttributeId(name)
    return (id == -1) and (name == "Strength" and 0 or 5) or id
end

local STRENGTH_ID = getAttributeId("Strength")
local ENDURANCE_ID = getAttributeId("Endurance")

local function CalculateVanillaMaxHealth(pid)
    local player = Players[pid]
    if not player or not player.data then return false end

    local level = tonumber(tes3mp.GetLevel(pid)) or 1
    if level < 1 then level = 1 end

    local currentEnd = tes3mp.GetAttributeBase(pid, ENDURANCE_ID)
    local currentStr = tes3mp.GetAttributeBase(pid, STRENGTH_ID)

    local character = player.data.character or {}
    local race = string.lower(character.race or "nord")
    local gender = tonumber(character.gender) or 0
    local birthsign = string.lower(character.birthsign or "")

    local stats = startingStats[race] or startingStats["nord"]
    local startStr = (stats.str and stats.str[gender]) or 40
    local startEnd = (stats.endu and stats.endu[gender]) or 40

    -- Favored attributes
    local favored = {}

    if player.data.customClass and player.data.customClass.majorAttributes then
        local majorAttrs = tostring(player.data.customClass.majorAttributes)
        if majorAttrs:lower():find("strength") then favored["Strength"] = true end
        if majorAttrs:lower():find("endurance") then favored["Endurance"] = true end
    else
        local defaultClassId = tes3mp.GetDefaultClass(pid)
        if defaultClassId and defaultClassId ~= "" then
            className = string.lower(defaultClassId)
        end
        local classFavored = vanillaClassFavored[className]
        if classFavored then
            for _, attr in ipairs(classFavored) do
                favored[attr] = true
            end
        end
    end

    if favored["Strength"] then startStr = startStr + 10 end
    if favored["Endurance"] then startEnd = startEnd + 10 end

    -- Lady bonus
    local ladyBonus = 0
    if applyLadyBonus and birthsign:find("lady") then
        ladyBonus = 25
    end

    -- Calculate expected health
    local hp = (startStr + startEnd) / 2
    local currentEndAtLevel = startEnd

    for lvl = 2, level do
        if currentEndAtLevel < currentEnd then
            currentEndAtLevel = currentEndAtLevel + 5
            if currentEndAtLevel > currentEnd then
                currentEndAtLevel = currentEnd
            end
        end
        hp = hp + ((currentEndAtLevel + ladyBonus) / 10)
    end

    local oldMax = tes3mp.GetHealthBase(pid)

    -- Only proceed if health is actually wrong
    if math.abs(hp - oldMax) < 0.5 then
        return false
    end

    local current = tes3mp.GetHealthCurrent(pid)
    local changed = false

    if hp > oldMax then
        tes3mp.SetHealthCurrent(pid, current + (hp - oldMax))
        tes3mp.SetHealthBase(pid, hp)
        changed = true
    elseif hp < oldMax and allowHealthDecrease then
        tes3mp.SetHealthBase(pid, hp)
        if current > hp then
            tes3mp.SetHealthCurrent(pid, hp)
        end
        changed = true
    end

    if changed then
        tes3mp.SendStatsDynamic(pid)
    end

    return changed
end

-- Event handlers
customEventHooks.registerHandler("OnPlayerAuthentified", function(eventStatus, pid)
    local player = Players[pid]
    if player and player:IsServerStaff() then return end

    if tes3mp.GetLevel(pid) <= 1 then return end   -- Safety guard for new characters

    CalculateVanillaMaxHealth(pid)
end)

customEventHooks.registerHandler("OnPlayerLevel", function(eventStatus, pid)
    CalculateVanillaMaxHealth(pid)
end)

customEventHooks.registerHandler("OnPlayerEndCharGen", function(eventStatus, pid)
    CalculateVanillaMaxHealth(pid)
end)
