local _, ns = ...
local W = ns.W

local STATUS_TEXT = {
    new = "|cff33ff99New|r", changed = "|cffffcc33Changed|r", scanned = "|cff88aaffRecorded|r",
}
local SOURCES = { "Trainer", "Recipe", "Favor" }

local COLUMNS = {
    { key = "icon", width = 18, icon = true },
    { key = "name", label = "Recipe", width = 220 },
    { key = "skill", label = "Skill", width = 38, justify = "RIGHT" },
    { key = "category", label = "Category", width = 150 },
    { key = "source", label = "Source", width = 70 },
    { key = "cost", label = "Cost", width = 110, justify = "RIGHT" },
    { key = "status", label = "Forever", width = 60 },
}

local GETTERS = {
    skill = ns.SkillOf,
    status = function(r) return r.status or "" end,
}

local function showTooltip(row, d)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if IsShiftKeyDown() and d.item then
        GameTooltip:SetItemByID(d.item)
    elseif d.id then
        GameTooltip:SetSpellByID(d.id)
    else
        GameTooltip:SetText(d.name)
    end
    GameTooltip:AddLine(" ")
    ns.TooltipAddPair("Learn at skill", d.learn and tostring(d.learn) or "?" .. (d.yellow and (" (yellow at %d)"):format(d.yellow) or ""))
    if d.yellow then
        GameTooltip:AddDoubleLine("Colours", ("|cffff8040%d|r  |cffffff00%d|r  |cff40c040%d|r  |cff808080%d|r")
            :format(d.learn or d.yellow, d.yellow, d.green or 0, d.grey or 0), 0.7, 0.7, 0.7)
    end
    ns.TooltipAddPair("Source", d.source)
    if d.favor then ns.TooltipAddPair("Merchant's Favor", d.favor, 1, 0.82, 0) end
    if d.source == "Trainer" then
        ns.TooltipAddPair("Trainer cost", d.cost and ns.Money(d.cost) or "visit a trainer to record")
    end
    ns.TooltipAddPair("Category", d.category)
    if d.status == "new" then GameTooltip:AddLine("New in Forever", 0.2, 1, 0.6) end
    if d.status == "changed" then GameTooltip:AddLine("Changed from Classic", 1, 0.8, 0.2) end
    if d.known then GameTooltip:AddLine("Known", 0.5, 0.5, 0.5) end
    if d.item and not IsShiftKeyDown() then GameTooltip:AddLine("Hold Shift for the crafted item", 0.5, 0.5, 0.5) end
    GameTooltip:Show()
end

function ns.CreateProfTab(f)
    local page = ns.CreatePage(f)
    local ui = ns.db.ui
    ui.profSort = ui.profSort or { key = "skill", asc = true }
    local mySkills = ns.PlayerProfessionSkills()
    if not ui.prof or not ns.ProfessionData[ui.prof] then
        ui.prof = next(mySkills) or "Alchemy"
    end
    local filter = {
        search = "", cats = {}, source = nil, status = nil,
        learnable = false, hideGrey = false, hideKnown = false,
        skill = mySkills[ui.prof] or 300, minSkill = 1, maxSkill = 300,
    }

    local c = page.controls
    local skillBox -- forward

    local function setProfession(name)
        ui.prof = name
        wipe(filter.cats)
        filter.skill = ns.PlayerProfessionSkills()[name] or 300
        if skillBox then skillBox:SetText(tostring(filter.skill)) end
        page:Refresh()
    end

    local profDD = W.Dropdown(c, 175, function(_, root)
        local mine = ns.PlayerProfessionSkills()
        for _, name in ipairs(ns.ProfessionNames()) do
            local label = mine[name] and ("%s |cff40ff40(%d)|r"):format(name, mine[name]) or name
            root:CreateRadio(label, function() return ui.prof == name end, function() setProfession(name) end)
        end
    end)
    profDD:SetPoint("LEFT", 0, 0)

    local search = W.Search(c, 120, function(text) filter.search = text; page:Refresh() end)
    search:SetPoint("LEFT", profDD, "RIGHT", 14, 0)

    local catDD = W.Dropdown(c, 140, function(_, root)
        root:CreateButton("All categories", function() wipe(filter.cats); page:Refresh() end)
        local cats, seen = {}, {}
        for _, r in ipairs(ns.ProfessionRows(ui.prof)) do
            if not seen[r.category] then seen[r.category] = true; cats[#cats + 1] = r.category end
        end
        table.sort(cats)
        for _, cat in ipairs(cats) do
            root:CreateCheckbox(cat, function() return filter.cats[cat] end,
                function() filter.cats[cat] = not filter.cats[cat] or nil; page:Refresh() end)
        end
    end)
    catDD:SetPoint("LEFT", search, "RIGHT", 8, 0)

    local filterDD = W.Dropdown(c, 90, function(_, root)
        root:CreateTitle("Source")
        root:CreateRadio("Any", function() return filter.source == nil end, function() filter.source = nil; page:Refresh() end)
        for _, s in ipairs(SOURCES) do
            local label = s == "Favor" and "Merchant's Favor" or s == "Recipe" and "Recipe item" or s
            root:CreateRadio(label, function() return filter.source == s end, function() filter.source = s; page:Refresh() end)
        end
        root:CreateDivider()
        root:CreateTitle("Forever")
        root:CreateRadio("Any", function() return filter.status == nil end, function() filter.status = nil; page:Refresh() end)
        root:CreateRadio("New in Forever", function() return filter.status == "new" end, function() filter.status = "new"; page:Refresh() end)
        root:CreateRadio("Changed", function() return filter.status == "changed" end, function() filter.status = "changed"; page:Refresh() end)
        root:CreateRadio("Same as Classic", function() return filter.status == "unchanged" end, function() filter.status = "unchanged"; page:Refresh() end)
        root:CreateDivider()
        root:CreateTitle("At my skill")
        root:CreateCheckbox("Only learnable now", function() return filter.learnable end, function() filter.learnable = not filter.learnable; page:Refresh() end)
        root:CreateCheckbox("Hide grey", function() return filter.hideGrey end, function() filter.hideGrey = not filter.hideGrey; page:Refresh() end)
        root:CreateCheckbox("Hide known", function() return filter.hideKnown end, function() filter.hideKnown = not filter.hideKnown; page:Refresh() end)
    end)
    filterDD:SetPoint("LEFT", catDD, "RIGHT", 8, 0)

    local skillLabel = W.Label(c, "My skill")
    skillLabel:SetPoint("LEFT", filterDD, "RIGHT", 12, 0)
    skillBox = W.NumberBox(c, 32, filter.skill, function(v) filter.skill = v or 0; page:Refresh() end)
    skillBox:SetPoint("LEFT", skillLabel, "RIGHT", 8, 0)

    local rangeLabel = W.Label(c, "Range")
    rangeLabel:SetPoint("LEFT", skillBox, "RIGHT", 10, 0)
    local minBox = W.NumberBox(c, 32, 1, function(v) filter.minSkill = v or 1; page:Refresh() end)
    minBox:SetPoint("LEFT", rangeLabel, "RIGHT", 8, 0)
    local dash = W.Label(c, "-")
    dash:SetPoint("LEFT", minBox, "RIGHT", 4, 0)
    local maxBox = W.NumberBox(c, 32, 300, function(v) filter.maxSkill = v or 300; page:Refresh() end)
    maxBox:SetPoint("LEFT", dash, "RIGHT", 8, 0)

    local tbl
    tbl = W.Table(page, COLUMNS, {
        rowHeight = 20,
        render = function(row, d)
            local cells = row.cells
            cells.icon:SetTexture(d.icon)
            cells.icon:SetDesaturated(d.known)
            local r, g, b = ns.DifficultyColor(d, filter.skill)
            cells.name:SetText((d.known and W.KNOWN_ICON or "") .. d.name)
            cells.name:SetTextColor(r, g, b)
            local s = ns.SkillOf(d)
            cells.skill:SetText(d.learnGuess and ("|cff808080~%d|r"):format(s) or s)
            cells.category:SetText(d.category)
            cells.source:SetText(d.favor and ("|cffffd100Favor %d|r"):format(d.favor) or d.source)
            cells.cost:SetText(d.source == "Trainer" and ns.Money(d.cost) or "")
            cells.status:SetText(STATUS_TEXT[d.status] or "")
        end,
        onEnter = showTooltip,
        onClick = function(_, d)
            if IsModifiedClick("CHATLINK") and d.id and C_Spell and C_Spell.GetSpellLink then
                ChatEdit_InsertLink(C_Spell.GetSpellLink(d.id))
            end
        end,
        onSort = function(key)
            if ui.profSort.key == key then
                ui.profSort.asc = not ui.profSort.asc
            else
                ui.profSort.key, ui.profSort.asc = key, true
            end
            page:Refresh()
        end,
    })
    tbl:SetPoint("TOPLEFT", c, "BOTTOMLEFT", 0, -4)
    tbl:SetPoint("BOTTOMRIGHT", 0, 4)

    function page:Refresh()
        if not self:IsShown() then return end
        profDD:GenerateMenu()
        catDD:GenerateMenu()
        filterDD:GenerateMenu()
        local nCats = 0
        for _ in pairs(filter.cats) do nCats = nCats + 1 end
        W.SetDropdownText(catDD, nCats == 0 and "All categories" or ("%d categor%s"):format(nCats, nCats == 1 and "y" or "ies"))
        local active = (filter.source and 1 or 0) + (filter.status and 1 or 0) + (filter.learnable and 1 or 0)
            + (filter.hideGrey and 1 or 0) + (filter.hideKnown and 1 or 0)
        W.SetDropdownText(filterDD, active > 0 and ("Filter (%d)"):format(active) or "Filter")

        local rows = {}
        for _, r in ipairs(ns.ProfessionRows(ui.prof)) do
            local s = ns.SkillOf(r)
            if s >= filter.minSkill and s <= filter.maxSkill
                and (nCats == 0 or filter.cats[r.category])
                and (not filter.source or r.source == filter.source)
                and (not filter.status or r.status == filter.status)
                and not (filter.learnable and r.learn and r.learn > filter.skill)
                and not (filter.learnable and not r.learn and s > filter.skill)
                and not (filter.hideGrey and r.grey and filter.skill >= r.grey)
                and not (filter.hideKnown and r.known)
                and (filter.search == "" or r.text:find(filter.search, 1, true)) then
                rows[#rows + 1] = r
            end
        end
        local sort = ui.profSort
        W.SortRows(rows, sort.key, sort.asc, GETTERS, { "skill", "category", "name" })
        tbl:SetSortIndicator(sort.key, sort.asc)

        -- Grouped by category when sorted by category.
        local list, group, trainerCost, missing, recorded = {}, nil, 0, 0, 0
        for _, r in ipairs(rows) do
            if sort.key == "category" and (not group or group.cat ~= r.category) then
                group = { isGroup = true, cat = r.category, n = 0 }
                list[#list + 1] = group
            end
            if group then group.n = group.n + 1 end
            if r.source == "Trainer" and not r.known then
                if r.cost then
                    trainerCost, recorded = trainerCost + r.cost, recorded + 1
                else
                    missing = missing + 1
                end
            end
            list[#list + 1] = r
        end
        for _, g in ipairs(list) do
            if g.isGroup then g.title, g.right = g.cat, ("%d"):format(g.n) end
        end
        tbl:SetRows(list)

        f.status:SetText(("%s: %d recipes shown. Trainer cost of the unlearned ones: %s%s"):format(
            ui.prof, #rows, ns.MoneyTotal(trainerCost, recorded),
            missing > 0 and ("  |cff808080(%d without a recorded cost - open a %s trainer)|r"):format(missing, ui.prof) or ""))
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)
    return page
end
