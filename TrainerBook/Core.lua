local ADDON, ns = ...

ns.name = ADDON
ns.events = CreateFrame("Frame")
ns.handlers = {}

-- ns.On("EVENT", fn): several modules can listen to the same event.
function ns.On(event, fn)
    if not ns.handlers[event] then
        ns.handlers[event] = {}
        ns.events:RegisterEvent(event)
    end
    table.insert(ns.handlers[event], fn)
end

ns.events:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(ns.handlers[event] or {}) do
        fn(...)
    end
end)

function ns.Print(...)
    print("|cff66bbffTrainerBook|r:", ...)
end

local DEFAULTS = {
    scans = { class = {}, prof = {} }, -- recorded trainer services (see Scan.lua)
    known = {},                        -- [charKey] = { ["Name|Rank"] = true }
    ui = { tab = 1 },
}

local function applyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            applyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function ns.CharKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

ns.On("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    TrainerBookDB = TrainerBookDB or {}
    applyDefaults(TrainerBookDB, DEFAULTS)
    ns.db = TrainerBookDB
end)

function ns.Toggle()
    if not ns.frame then ns.CreateMainFrame() end
    ns.frame:SetShown(not ns.frame:IsShown())
end

function TrainerBook_OnAddonCompartmentClick()
    ns.Toggle()
end

SLASH_TRAINERBOOK1 = "/tb"
SLASH_TRAINERBOOK2 = "/trainerbook"
SlashCmdList.TRAINERBOOK = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "scan" then
        ns.ScanTrainer(true)
    elseif msg == "stats" then
        ns.PrintStats()
    elseif msg == "reset" then
        TrainerBookDB = nil
        ns.Print("Saved data cleared; /reload to finish.")
    else
        ns.Toggle()
    end
end
