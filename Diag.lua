-- Diag: /allemano fonttest - which fonts does this client accept? WoW Forever refuses font files from
-- most addon folders (only the game's own fonts and a few addons' work), so the Hub offers the fonts that
-- do work: the game's own and those other addons register with LibSharedMedia (EllesmereUI's Expressway ...).
-- This lists them, with the result of SetFont, so a font that does not show up can be understood.
local _, HUB = ...

local FALLBACK = "Fonts\\FRIZQT__.TTF"

local function normalize(p) return p and strlower((tostring(p):gsub("/", "\\"))) or "" end

local function try(path)
    local fs = UIParent:CreateFontString(nil, "BACKGROUND")
    fs:SetFont(FALLBACK, 12, "")
    local ok, err = pcall(fs.SetFont, fs, path, 12, "")
    local applied = normalize(fs:GetFont()) == normalize(path)
    fs:SetText("The quick brown fox jumps over the lazy dog")
    return ok and err, applied, fs:GetStringWidth()
end

HUB:AddSlashCommand("fonttest", function()
    HUB:Print("Fonts this client accepts (SetFont / text width):")
    local list = HUB.Theme:AvailableFonts()
    for _, f in ipairs(list) do
        local returned, _, width = try(f.path)
        HUB:Print(("%s: SetFont=%s width=%.0f"):format(f.name, tostring(returned), width or 0))
    end
    HUB:Print(("%d fonts. Font files in addon folders are refused by the client unless the addon is one of the few it allows."):format(#list))
end, "list the fonts this client accepts")
