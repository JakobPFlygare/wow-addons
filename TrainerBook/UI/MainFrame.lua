local _, ns = ...

local TABS = {
    { label = "Class", create = function(p) return ns.CreateClassTab(p) end },
    { label = "Professions", create = function(p) return ns.CreateProfTab(p) end },
}

function ns.CreateMainFrame()
    local f = CreateFrame("Frame", "TrainerBookFrame", UIParent, "ButtonFrameTemplate")
    ns.frame = f
    f:SetSize(820, 580)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "TrainerBookFrame") -- Escape closes it

    if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(f) end
    if f.SetTitle then
        f:SetTitle("TrainerBook")
    elseif f.TitleText then
        f.TitleText:SetText("TrainerBook")
    end
    if f.Inset then
        f.Inset:ClearAllPoints()
        f.Inset:SetPoint("TOPLEFT", 6, -62)
        f.Inset:SetPoint("BOTTOMRIGHT", -6, 28)
    end

    -- footer line for totals
    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.status:SetPoint("BOTTOMLEFT", 14, 9)
    f.status:SetPoint("BOTTOMRIGHT", -14, 9)
    f.status:SetJustifyH("LEFT")

    f.pages, f.Tabs = {}, {}
    for i, def in ipairs(TABS) do
        local tab = CreateFrame("Button", "TrainerBookFrameTab" .. i, f, "PanelTabButtonTemplate")
        tab:SetID(i)
        tab:SetText(def.label)
        if i == 1 then
            tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 12, 2)
        else
            tab:SetPoint("LEFT", f.Tabs[i - 1], "RIGHT", 4, 0)
        end
        tab:SetScript("OnClick", function() f:SelectTab(i) end)
        if PanelTemplates_TabResize then PanelTemplates_TabResize(tab, 0) end
        f.Tabs[i] = tab
    end
    PanelTemplates_SetNumTabs(f, #TABS)

    function f:SelectTab(i)
        ns.db.ui.tab = i
        PanelTemplates_SetTab(self, i)
        for j, def in ipairs(TABS) do
            if j == i and not self.pages[j] then
                self.pages[j] = def.create(self)
            end
            if self.pages[j] then self.pages[j]:SetShown(j == i) end
        end
        self:Refresh()
    end

    function f:Refresh()
        local page = self.pages[ns.db.ui.tab]
        if page and page.Refresh then page:Refresh() end
    end

    f:SetScript("OnShow", function(self) self:Refresh() end)
    f:Hide()
    f:SelectTab(ns.db.ui.tab or 1)
    return f
end

-- Content area for a tab: controls go in the top band (y 0..-34 below title), table in the inset.
function ns.CreatePage(f)
    local page = CreateFrame("Frame", nil, f)
    page:SetPoint("TOPLEFT", 10, -26)
    page:SetPoint("BOTTOMRIGHT", -10, 30)
    page.controls = CreateFrame("Frame", nil, page)
    page.controls:SetPoint("TOPLEFT")
    page.controls:SetPoint("TOPRIGHT")
    page.controls:SetHeight(34)
    return page
end

-- Spell/recipe tooltip helpers shared by both tabs.
function ns.TooltipAddPair(left, right, r, g, b)
    GameTooltip:AddDoubleLine(left, right, 0.7, 0.7, 0.7, r or 1, g or 1, b or 1)
end
