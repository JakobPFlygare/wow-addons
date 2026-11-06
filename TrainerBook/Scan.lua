-- Records what an open trainer window offers: cost, level/skill requirement, spell id,
-- and which entries this character already knows. Bundled data has no costs; this fills them.
local _, ns = ...

local FILTERS = { "available", "unavailable", "used" }
local scanning = false

local function trim(s)
    return (s or ""):match("^%s*(.-)%s*$")
end

local function serviceSpellId(i)
    if C_TooltipInfo and C_TooltipInfo.GetTrainerService then
        local ok, data = pcall(C_TooltipInfo.GetTrainerService, i)
        if ok and data and data.id and data.id > 0 then return data.id end
    end
end

-- Which profession does this trainer teach? First skill requirement wins.
local function trainerProfession(n)
    for i = 1, n do
        local skill = GetTrainerServiceSkillReq and GetTrainerServiceSkillReq(i)
        if skill and skill ~= "" then return skill end
    end
end

function ns.ScanTrainer(verbose)
    if scanning or not ns.db or not GetNumTrainerServices then return end
    scanning = true

    -- Show every service (incl. future ranks), remember the player's filter to restore it.
    local saved = {}
    if GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter then
        for _, f in ipairs(FILTERS) do
            saved[f] = GetTrainerServiceTypeFilter(f)
            if not saved[f] then SetTrainerServiceTypeFilter(f, 1) end
        end
    end

    local n = GetNumTrainerServices() or 0
    local isProf = IsTradeskillTrainer and IsTradeskillTrainer()
    local bucket, known, label
    if isProf then
        label = trainerProfession(n)
        if label then
            ns.db.scans.prof[label] = ns.db.scans.prof[label] or {}
            bucket = ns.db.scans.prof[label]
            local ck = ns.CharKey()
            ns.db.known[ck] = ns.db.known[ck] or {}
            ns.db.known[ck][label] = ns.db.known[ck][label] or {}
            known = ns.db.known[ck][label]
        end
    else
        label = select(2, UnitClass("player"))
        ns.db.scans.class[label] = ns.db.scans.class[label] or {}
        bucket = ns.db.scans.class[label]
        local ck = ns.CharKey()
        ns.db.known[ck] = ns.db.known[ck] or {}
        ns.db.known[ck].CLASS = ns.db.known[ck].CLASS or {}
        known = ns.db.known[ck].CLASS
    end

    local count = 0
    if bucket then
        for i = 1, n do
            local name, rank, category = GetTrainerServiceInfo(i)
            if name and category ~= "header" then
                rank = trim(rank)
                local key = isProf and name or (name .. "|" .. rank)
                local _, skillLevel = nil, nil
                if GetTrainerServiceSkillReq then _, skillLevel = GetTrainerServiceSkillReq(i) end
                bucket[key] = {
                    cost = GetTrainerServiceCost and GetTrainerServiceCost(i) or nil,
                    level = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or nil,
                    skill = skillLevel,
                    spellId = serviceSpellId(i),
                    icon = GetTrainerServiceIcon and GetTrainerServiceIcon(i) or nil,
                    t = time(),
                }
                if category == "used" then known[key] = true end
                count = count + 1
            end
        end
    end

    for f, v in pairs(saved) do
        if not v then SetTrainerServiceTypeFilter(f, 0) end
    end
    scanning = false

    if count > 0 then
        ns.Invalidate()
        if verbose or not ns._announced then
            ns.Print(("recorded %d trainer entries for %s."):format(count, label or "?"))
            ns._announced = true
        end
    elseif verbose then
        ns.Print("no trainer window open (or nothing to record).")
    end
end

ns.On("TRAINER_SHOW", function()
    ns._announced = false
    C_Timer.After(0.2, function() ns.ScanTrainer(false) end)
end)

-- Learning something flips it to "used": rescan quietly. Our own filter toggles also fire
-- TRAINER_UPDATE, so ignore updates right after a scan and coalesce the rest.
local lastScanEnd, pending = 0, false
hooksecurefunc(ns, "ScanTrainer", function() lastScanEnd = GetTime() end)
ns.On("TRAINER_UPDATE", function()
    if scanning or pending or not ns._announced or GetTime() - lastScanEnd < 1 then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        ns.ScanTrainer(false)
    end)
end)

function ns.PrintStats()
    local c, p = 0, 0
    for _, t in pairs(ns.db.scans.class) do for _ in pairs(t) do c = c + 1 end end
    for _, t in pairs(ns.db.scans.prof) do for _ in pairs(t) do p = p + 1 end end
    ns.Print(("recorded costs: %d class spells, %d recipes."):format(c, p))
end
