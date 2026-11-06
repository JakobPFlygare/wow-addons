local _, ns = ...
local W = ns.W

local STATUS_TEXT = {
    new = "|cff33ff99New|r", changed = "|cffffcc33Changed|r", scanned = "|cff88aaffRecorded|r",
}

local COLUMNS = {
    { key = "icon", width = 18, icon = true },
    { key = "name", label = "Spell", width = 230 },
    { key = "rank", label = "Rank", width = 60 },
    { key = "level", label = "Level", width = 40, justify = "RIGHT" },
    { key = "school", label = "School", width = 110 },
    { key = "cost", label = "Cost", width = 120, justify = "RIGHT" },
    { key = "status", label = "Forever", width = 70 },
}

local GETTERS = {
    rank = function(r) return tonumber(r.rank:match("%d+")) or 0 end,
    status = function(r) return r.status or "" end,
}

local function classLabel(token)
    local loc = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]
    return loc or (token:sub(1, 1) .. token:sub(2):lower())
end

local function classColor(token)
    local c = (RAID_CLASS_COLORS or {})[token]
    return c and c.colorStr and ("|c" .. c.colorStr) or "|cffffffff"
end

local function showTooltip(row, d)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if d.spellId then
        GameTooltip:SetSpellByID(d.spellId)
    else
        GameTooltip:AddDoubleLine(d.name, d.rank, 1, 1, 1, 0.6, 0.6, 0.6)
        if d.meta and d.meta ~= "" then GameTooltip:AddLine(d.meta:gsub(" · ", "   "), 1, 1, 1) end
        if d.req and d.req ~= "" then GameTooltip:AddLine(d.req, 1, 1, 1, true) end
        if d.desc and d.desc ~= "" then GameTooltip:AddLine(d.desc, 1, 0.82, 0, true) end
    end
    GameTooltip:AddLine(" ")
    ns.TooltipAddPair("Trainer level", d.level)
    ns.TooltipAddPair("Cost", d.cost and ns.Money(d.cost) or "visit your trainer to record")
    if d.passive then ns.TooltipAddPair("Type", "Passive") end
    if d.talent then ns.TooltipAddPair("Needs", d.talent .. " (talent)", 1, 0.5, 0.25) end
    if d.note then GameTooltip:AddLine(d.note, 0.6, 0.8, 1, true) end
    if d.status == "changed" then GameTooltip:AddLine("Changed from Classic", 1, 0.8, 0.2) end
    if d.status == "new" then GameTooltip:AddLine("New in Forever", 0.2, 1, 0.6) end
    if d.known then GameTooltip:AddLine("Known", 0.5, 0.5, 0.5) end
    GameTooltip:Show()
end

function ns.CreateClassTab(f)
    local page = ns.CreatePage(f)
    local ui = ns.db.ui
    ui.class = ui.class or select(2, UnitClass("player"))
    ui.classSort = ui.classSort or { key = "level", asc = true }
    local filter = { search = "", school = nil, minLevel = 1, maxLevel = 60, hideKnown = false }

    local c = page.controls
    local classDD = W.Dropdown(c, 130, function(_, root)
        for _, token in ipairs(ns.CLASS_ORDER) do
            root:CreateRadio(classColor(token) .. classLabel(token) .. "|r",
                function() return ui.class == token end,
                function() ui.class = token; filter.school = nil; page:Refresh() end)
        end
    end)
    classDD:SetPoint("LEFT", 0, 0)

    local schoolDD = W.Dropdown(c, 120, function(_, root)
        root:CreateRadio("All schools", function() return filter.school == nil end,
            function() filter.school = nil; page:Refresh() end)
        local seen = {}
        for _, r in ipairs(ns.ClassRows(ui.class)) do
            if not seen[r.school] then
                seen[r.school] = true
                local s = r.school
                root:CreateRadio(s, function() return filter.school == s end,
                    function() filter.school = s; page:Refresh() end)
            end
        end
    end)
    schoolDD:SetPoint("LEFT", classDD, "RIGHT", 8, 0)

    local search = W.Search(c, 150, function(text) filter.search = text; page:Refresh() end)
    search:SetPoint("LEFT", schoolDD, "RIGHT", 14, 0)

    local lvlLabel = W.Label(c, "Level")
    lvlLabel:SetPoint("LEFT", search, "RIGHT", 14, 0)
    local minBox = W.NumberBox(c, 28, 1, function(v) filter.minLevel = v or 1; page:Refresh() end)
    minBox:SetPoint("LEFT", lvlLabel, "RIGHT", 8, 0)
    local dash = W.Label(c, "-")
    dash:SetPoint("LEFT", minBox, "RIGHT", 4, 0)
    local maxBox = W.NumberBox(c, 28, 60, function(v) filter.maxLevel = v or 60; page:Refresh() end)
    maxBox:SetPoint("LEFT", dash, "RIGHT", 8, 0)

    local mine = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    mine:SetSize(70, 20)
    mine:SetText("From me")
    mine:SetPoint("LEFT", maxBox, "RIGHT", 6, 0)
    mine:SetScript("OnClick", function()
        filter.minLevel = UnitLevel("player")
        minBox:SetText(tostring(filter.minLevel))
        page:Refresh()
    end)
    mine:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Show from your current level up")
        GameTooltip:Show()
    end)
    mine:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local hideKnown = W.Check(c, "Hide known", false, function(v) filter.hideKnown = v; page:Refresh() end)
    hideKnown:SetPoint("LEFT", mine, "RIGHT", 6, 0)

    local tbl
    tbl = W.Table(page, COLUMNS, {
        rowHeight = 20,
        render = function(row, d)
            local myLevel = UnitLevel("player")
            local cells = row.cells
            cells.icon:SetTexture(d.icon)
            cells.icon:SetDesaturated(d.known)
            local color = d.known and "|cff808080" or (ui.class == select(2, UnitClass("player")) and d.level <= myLevel and "|cff40ff40") or "|cffffffff"
            cells.name:SetText((d.known and W.KNOWN_ICON or "") .. color .. d.name .. "|r" .. (d.passive and " |cff808080(passive)|r" or "") .. (d.talent and " |cffff8040(talent)|r" or ""))
            cells.rank:SetText(d.rank ~= "" and d.rank:gsub("Rank ", "R") or "")
            cells.level:SetText(d.level)
            cells.school:SetText(d.school)
            cells.cost:SetText(ns.Money(d.cost))
            cells.status:SetText(STATUS_TEXT[d.status] or "")
        end,
        onEnter = showTooltip,
        onClick = function(_, d)
            if IsModifiedClick("CHATLINK") and d.spellId and C_Spell and C_Spell.GetSpellLink then
                ChatEdit_InsertLink(C_Spell.GetSpellLink(d.spellId))
            end
        end,
        onSort = function(key)
            if ui.classSort.key == key then
                ui.classSort.asc = not ui.classSort.asc
            else
                ui.classSort.key, ui.classSort.asc = key, true
            end
            page:Refresh()
        end,
    })
    tbl:SetPoint("TOPLEFT", c, "BOTTOMLEFT", 0, -4)
    tbl:SetPoint("BOTTOMRIGHT", 0, 4)

    function page:Refresh()
        if not self:IsShown() then return end
        classDD:GenerateMenu()
        schoolDD:GenerateMenu()
        W.SetDropdownText(schoolDD, filter.school or "All schools")

        local rows = {}
        for _, r in ipairs(ns.ClassRows(ui.class)) do
            if r.level >= filter.minLevel and r.level <= filter.maxLevel
                and (not filter.school or r.school == filter.school)
                and not (filter.hideKnown and r.known)
                and (filter.search == "" or (r.name .. " " .. (r.desc or "")):lower():find(filter.search, 1, true)) then
                rows[#rows + 1] = r
            end
        end
        local sort = ui.classSort
        W.SortRows(rows, sort.key, sort.asc, GETTERS, { "level", "name", "rank" })
        tbl:SetSortIndicator(sort.key, sort.asc)

        -- Grouped by level when sorted by level: header per level with its total cost.
        local list, total, missing = {}, 0, 0
        local group
        local myLevel = UnitLevel("player")
        for _, r in ipairs(rows) do
            if sort.key == "level" and (not group or group.level ~= r.level) then
                group = { isGroup = true, level = r.level, cost = 0, n = 0, missing = 0 }
                list[#list + 1] = group
            end
            if group then
                group.n = group.n + 1
                if r.cost then group.cost = group.cost + r.cost else group.missing = group.missing + 1 end
            end
            if r.cost then total = total + r.cost else missing = missing + 1 end
            list[#list + 1] = r
        end
        for _, g in ipairs(list) do
            if g.isGroup then
                g.title = ("Level %d%s"):format(g.level, g.level == myLevel and "  |cff40ff40(you)|r" or "")
                g.right = ("%d spell%s   %s%s"):format(g.n, g.n == 1 and "" or "s", ns.MoneyTotal(g.cost, g.n - g.missing),
                    g.missing > 0 and ("  |cff808080+%d unrecorded|r"):format(g.missing) or "")
            end
        end
        tbl:SetRows(list)

        f.status:SetText(("%s%s|r: %d ranks shown, total %s%s"):format(
            classColor(ui.class), classLabel(ui.class), #rows, ns.MoneyTotal(total, #rows - missing),
            missing > 0 and ("  |cff808080(%d without a recorded cost - open your class trainer to fill them)|r"):format(missing) or ""))
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)
    return page
end
