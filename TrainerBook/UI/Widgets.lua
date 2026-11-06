-- Small wrappers around Blizzard's own templates (ScrollBox, Menu dropdowns, search box).
local _, ns = ...
local W = {}
ns.W = W

W.KNOWN_ICON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t "

function W.Label(parent, text, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
    fs:SetText(text)
    return fs
end

-- generator(dropdown, rootDescription) builds the menu; call dd:GenerateMenu() after outside changes.
function W.Dropdown(parent, width, generator)
    local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dd:SetWidth(width)
    dd:SetupMenu(generator)
    return dd
end

function W.SetDropdownText(dd, text)
    if dd.OverrideText then
        dd:OverrideText(text)
    elseif dd.Text then
        dd.Text:SetText(text)
    end
end

function W.Search(parent, width, onChange)
    local box = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:HookScript("OnTextChanged", function(self)
        onChange((self:GetText() or ""):lower())
    end)
    return box
end

function W.NumberBox(parent, width, value, onChange)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(3)
    box:SetJustifyH("CENTER")
    box:SetText(tostring(value))
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:HookScript("OnTextChanged", function(self, user)
        if user then onChange(tonumber(self:GetText())) end
    end)
    return box
end

function W.Check(parent, label, checked, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetChecked(checked and true or false)
    local fs = cb.Text or cb.text
    if not fs then
        fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", cb, "RIGHT", 0, 1)
    end
    fs:SetFontObject("GameFontHighlightSmall")
    fs:SetText(label)
    cb:SetScript("OnClick", function(self) onClick(self:GetChecked()) end)
    return cb
end

--[[ Sortable table on a ScrollBox.
columns = { { key=, label=, width=, icon=bool, justify= }, ... }
opts = { rowHeight, render(rowFrame, data), onEnter(rowFrame, data), onClick(rowFrame, data, button), onSort(key) }
Rows with data.isGroup = true are drawn as group headers (data.title, data.right).
]]
function W.Table(parent, columns, opts)
    local h = opts.rowHeight or 20
    local t = CreateFrame("Frame", nil, parent)

    local header = CreateFrame("Frame", nil, t)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT", -18, 0)
    header:SetHeight(18)

    local x = 4
    for _, col in ipairs(columns) do
        col.x = x
        if col.label then
            local b = CreateFrame("Button", nil, header)
            b:SetPoint("LEFT", x, 0)
            b:SetSize(col.width, 18)
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            b.text:SetPoint(col.justify == "RIGHT" and "RIGHT" or "LEFT")
            b.text:SetText(col.label)
            b:SetHighlightTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight", "ADD")
            b.arrow = b:CreateTexture(nil, "OVERLAY")
            b.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
            b.arrow:SetSize(9, 8)
            if col.justify == "RIGHT" then
                b.arrow:SetPoint("RIGHT", b.text, "LEFT", -2, 0)
            else
                b.arrow:SetPoint("LEFT", b.text, "RIGHT", 2, 0)
            end
            b.arrow:Hide()
            if opts.onSort and col.sortable ~= false then
                b:SetScript("OnClick", function() opts.onSort(col.key) end)
            end
            col.header = b
        end
        x = x + col.width + 6
    end

    function t:SetSortIndicator(key, asc)
        for _, col in ipairs(columns) do
            if col.header then
                col.header.arrow:SetShown(col.key == key)
                if asc then
                    col.header.arrow:SetTexCoord(0, 0.5625, 1, 0)
                else
                    col.header.arrow:SetTexCoord(0, 0.5625, 0, 1)
                end
            end
        end
    end

    local box = CreateFrame("Frame", nil, t, "WowScrollBoxList")
    box:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    box:SetPoint("BOTTOMRIGHT", -18, 0)
    local bar = CreateFrame("EventFrame", nil, t, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, 0)
    bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 6, 0)

    local function initRow(row, data)
        if not row.cells then
            row.cells = {}
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            for _, col in ipairs(columns) do
                if col.icon then
                    local tex = row:CreateTexture(nil, "ARTWORK")
                    tex:SetSize(h - 2, h - 2)
                    tex:SetPoint("LEFT", col.x, 0)
                    row.cells[col.key] = tex
                else
                    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    fs:SetPoint("LEFT", col.x, 0)
                    fs:SetWidth(col.width)
                    fs:SetJustifyH(col.justify or "LEFT")
                    fs:SetWordWrap(false)
                    row.cells[col.key] = fs
                end
            end
            row:RegisterForClicks("LeftButtonUp")
            row:SetScript("OnEnter", function(self)
                if opts.onEnter then opts.onEnter(self, self.data) end
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row:SetScript("OnClick", function(self, button)
                if opts.onClick then opts.onClick(self, self.data, button) end
            end)
        end
        row.data = data
        opts.render(row, data)
    end

    local function initGroup(frame, data)
        if not frame.title then
            frame.bg = frame:CreateTexture(nil, "BACKGROUND")
            frame.bg:SetAllPoints()
            frame.bg:SetColorTexture(1, 0.82, 0, 0.10)
            frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            frame.title:SetPoint("LEFT", 6, 0)
            frame.right = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            frame.right:SetPoint("RIGHT", -6, 0)
        end
        frame.title:SetText(data.title or "")
        frame.right:SetText(data.right or "")
    end

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(h)
    view:SetElementFactory(function(factory, data)
        if data.isGroup then
            factory("Frame", initGroup)
        else
            factory("Button", initRow)
        end
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)

    function t:SetRows(list)
        box:SetDataProvider(CreateDataProvider(list), ScrollBoxConstants.RetainScrollPosition)
    end

    t.columns = columns
    return t
end

-- Shared sort: rows by key, ties broken by the given fallbacks.
function W.SortRows(rows, key, asc, getters, tiebreak)
    local get = getters[key] or function(r) return r[key] end
    table.sort(rows, function(a, b)
        local va, vb = get(a), get(b)
        if va == nil then va = asc and math.huge or -math.huge end
        if vb == nil then vb = asc and math.huge or -math.huge end
        if type(va) ~= type(vb) then va, vb = tostring(va), tostring(vb) end
        if va ~= vb then
            if asc then return va < vb else return va > vb end
        end
        for _, k in ipairs(tiebreak) do
            local g = getters[k] or function(r) return r[k] end
            local ta, tb = g(a), g(b)
            if ta == nil then ta = "" end
            if tb == nil then tb = "" end
            if type(ta) ~= type(tb) then ta, tb = tostring(ta), tostring(tb) end
            if ta ~= tb then return ta < tb end
        end
        return false
    end)
end
