-- Merges bundled data (Data/*.lua) with what the player's trainer visits recorded.
local _, ns = ...

local cache = {}

function ns.Invalidate()
    wipe(cache)
    if ns.frame and ns.frame:IsShown() and ns.frame.Refresh then ns.frame:Refresh() end
end

ns.CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

local function knownSet(section)
    local k = ns.db.known[ns.CharKey()]
    return k and k[section] or {}
end

-- One row per spell rank: { name, rank, level, school, icon, status, cost, known, ... }
function ns.ClassRows(token)
    if cache["c:" .. token] then return cache["c:" .. token] end
    local rows, seen = {}, {}
    local scans = ns.db.scans.class[token] or {}
    local known = token == select(2, UnitClass("player")) and knownSet("CLASS") or {}

    for _, sp in ipairs(ns.ClassData[token] or {}) do
        for _, rk in ipairs(sp.ranks) do
            local key = sp.n .. "|" .. rk.r
            local scan = scans[key] or (rk.r == "Rank 1" and scans[sp.n .. "|"]) or nil
            seen[key] = true
            rows[#rows + 1] = {
                name = sp.n, rank = rk.r, level = rk.l, school = sp.school,
                icon = "Interface\\Icons\\" .. sp.icon, status = sp.status,
                passive = sp.passive, talent = sp.talent, note = sp.note,
                meta = rk.m, req = rk.q, desc = rk.d,
                cost = scan and scan.cost, spellId = scan and scan.spellId,
                known = known[key] or false,
            }
        end
    end
    -- Trainer entries the bundled data doesn't have (patches, data gaps).
    for key, scan in pairs(scans) do
        if not seen[key] then
            local name, rank = key:match("^(.*)|(.*)$")
            if not (rank == "" and seen[name .. "|Rank 1"]) then
                rows[#rows + 1] = {
                    name = name, rank = rank, level = scan.level or 0, school = "Recorded",
                    icon = scan.icon or "Interface\\Icons\\INV_Misc_QuestionMark", status = "scanned",
                    cost = scan.cost, spellId = scan.spellId, known = known[key] or false,
                }
            end
        end
    end
    cache["c:" .. token] = rows
    return rows
end

function ns.ProfessionNames()
    local names = {}
    for name in pairs(ns.ProfessionData) do names[#names + 1] = name end
    for name in pairs(ns.db.scans.prof) do
        if not ns.ProfessionData[name] then names[#names + 1] = name end
    end
    table.sort(names)
    return names
end

local SOURCE_LABEL = { trainer = "Trainer", item = "Recipe" }

function ns.ProfessionRows(prof)
    if cache["p:" .. prof] then return cache["p:" .. prof] end
    local rows, seen = {}, {}
    local scans = ns.db.scans.prof[prof] or {}
    local known = knownSet(prof)
    local data = ns.ProfessionData[prof]

    for _, r in ipairs(data and data.recipes or {}) do
        local scan = scans[r.n]
        seen[r.n] = true
        local source = r.favor and "Favor" or SOURCE_LABEL[r.src] or r.src
        rows[#rows + 1] = {
            id = r.id, name = r.n, icon = "Interface\\Icons\\" .. r.icon, item = r.item,
            category = r.cat, source = source, favor = r.favor, status = r.status,
            -- trainer recipes often have no learn skill in the client; the scan knows it
            learn = (scan and scan.skill) or r.learn, learnGuess = not (scan and scan.skill) and not r.learn,
            yellow = r.y, green = r.g, grey = r.gr,
            cost = scan and scan.cost, text = r.text or r.n:lower(),
            known = known[r.n] or false,
        }
    end
    for name, scan in pairs(scans) do
        if not seen[name] then
            rows[#rows + 1] = {
                id = scan.spellId, name = name, icon = scan.icon or "Interface\\Icons\\INV_Misc_QuestionMark",
                category = "Recorded", source = "Trainer", status = "scanned",
                learn = scan.skill, cost = scan.cost, text = name:lower(), known = known[name] or false,
            }
        end
    end
    cache["p:" .. prof] = rows
    return rows
end

-- Sorting key for "skill": learn requirement, else the yellow threshold.
function ns.SkillOf(row)
    return row.learn or row.yellow or 0
end

-- { [professionName] = currentSkill } for this character; works with either skill API.
function ns.PlayerProfessionSkills()
    local out = {}
    if GetProfessions and GetProfessionInfo then
        for _, idx in pairs({ GetProfessions() }) do
            if idx then
                local name, _, skill = GetProfessionInfo(idx)
                if name then out[name] = skill end
            end
        end
    end
    if next(out) == nil and GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank = GetSkillLineInfo(i)
            if name and not isHeader and ns.ProfessionData[name] then out[name] = rank end
        end
    end
    return out
end

-- Recipe colour at a given skill, like the trade-skill window.
function ns.DifficultyColor(row, skill)
    if row.learn and skill < row.learn then return 0.9, 0.2, 0.2 end     -- can't learn yet
    if not row.yellow then return 1, 1, 1 end
    if skill < row.yellow then return 1, 0.5, 0.25 end      -- orange
    if skill < (row.green or 999) then return 1, 1, 0 end   -- yellow
    if skill < (row.grey or 999) then return 0.25, 0.75, 0.25 end -- green
    return 0.5, 0.5, 0.5                                    -- grey
end

-- Sum of costs where some may be unrecorded: "?" when nothing is recorded, never a fake "free".
function ns.MoneyTotal(sum, recorded)
    if recorded == 0 then return "|cff808080?|r" end
    return ns.Money(sum)
end

function ns.Money(copper)
    if not copper then return "|cff808080?|r" end
    if copper == 0 then return "free" end
    if GetMoneyString then return GetMoneyString(copper, true) end
    return ("%dg %ds %dc"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end
