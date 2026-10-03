-- Offline test of the Errors page and the scrolling menus: builds them against a fake game API (the mock below is the same as the Allemano Ledger smoke test).
-- Run from the AllemanoHub folder:  lua Tests/errors_page_test.lua
-- Smoke test outside the game: loads every TOC file against a fake WoW API with a
-- controllable clock and plays through sessions (login, money, XP, level-up, reload, new
-- login, reset, max level). Run from the addon folder: lua Tests/smoke_test.lua
local unpack = table.unpack or unpack
_G.unpack = unpack

-- Generic fake widget: known getters return sensible values, everything else is a no-op.
local GETTERS = {
    GetStringWidth = 50, GetStringHeight = 12, GetEffectiveScale = 1, GetWidth = 1920, GetHeight = 1080,
    GetLeft = 100, GetTop = 800, GetRight = 400, GetBottom = 100, GetFrameLevel = 1, IsShown = false,
    IsEnabled = true, IsVisible = true,
}
local scripts = {} -- strong: real frames are kept alive by their parent, mocks are not
local function mock(kind)
    local o = { _kind = kind, _shown = kind ~= "Frame" and true or true }
    return setmetatable(o, { __index = function(t, k)
        if type(k) ~= "string" or not k:match("^%u") then return nil end -- fields: nil, like real frames
        if k == "SetScript" then return function(self, name, fn) scripts[self] = scripts[self] or {}; scripts[self][name] = fn end end
        if k == "HookScript" then return function() end end
        if k == "GetScript" then return function(self, name) return scripts[self] and scripts[self][name] end end
        if k == "Show" then return function(self) self._shown = true; local f = scripts[self] and scripts[self].OnShow; if f then f(self) end end end
        if k == "Hide" then return function(self) local was = self._shown; self._shown = false; local f = was and scripts[self] and scripts[self].OnHide; if f then f(self) end end end
        if k == "SetShown" then return function(self, v) if v then self:Show() else self:Hide() end end end
        if k == "IsShown" then return function(self) return self._shown end end
        if k == "SetColorTexture" or k == "SetTextColor" or k == "SetVertexColor" then
            return function(_, r, g, b, a)
                for i, v in ipairs({ r, g, b }) do assert(type(v) == "number", k .. ": component " .. i .. " is " .. type(v)) end
                assert(a == nil or type(a) == "number", k .. ": alpha is " .. type(a))
            end
        end
        if k == "SetFont" then return function() return true end end
        if k == "SetText" then return function(self, v) self._text = v end end
        if k == "GetText" then return function(self) return self._text or "" end end
        if k == "GetFont" then return function() return "Fonts\\FRIZQT__.TTF", 12 end end
        if k == "CreateTexture" or k == "CreateFontString" or k == "CreateLine" then
            return function(self) local m = mock(k); m._parent = self; return m end
        end
        -- Geometry and layers used by W.Round / W.RoundBorder (same as AltBoard's test).
        if k == "GetParent" then return function(self) return self._parent or UIParent end end
        if k == "GetNumPoints" then return function() return 0 end end
        if k == "GetSize" then return function() return 0, 0 end end
        if k == "GetDrawLayer" then return function() return "ARTWORK", 0 end end
        if k == "GetAlpha" then return function() return 1 end end
        if k == "SetTexture" then return function() return true end end
        if GETTERS[k] ~= nil then local v = GETTERS[k]; return function() return v end end
        return function() end
    end })
end

CreateFrame = function(kind, name, parent) local f = mock(kind); f._shown = true; f._parent = parent; if name then _G[name] = f end; return f end
UIParent = mock("Frame")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) print("[chat] " .. m) end }
UISpecialFrames = {}
SlashCmdList = {}
strjoin = function(sep, ...) return table.concat({ ... }, sep) end
tostringall = function(...) local t = { ... } for i = 1, select("#", ...) do t[i] = tostring(t[i]) end return unpack(t, 1, select("#", ...)) end
strsplit = function(sep, s) local t = {} for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do t[#t + 1] = part end return unpack(t) end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
abs = math.abs
strlower, strupper, tinsert, tremove, sort, floor, ceil, min, max, format = string.lower, string.upper, table.insert, table.remove, table.sort, math.floor, math.ceil, math.min, math.max, string.format
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
date = os.date
-- ---- Hub menu test
CreateFrame = function(kind, name, parent) local f = mock(kind); f._shown = true; f._parent = parent; if name then _G[name] = f end; return f end
UIParent = mock("Frame")
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
UISpecialFrames, SlashCmdList = {}, {}
GetPhysicalScreenSize = function() return 2560, 1440 end
C_Timer = { After = function(_, fn) fn() end, NewTicker = function() return { Cancel = function() end } end }
C_AddOns = { GetAddOnMetadata = function() return "test" end, GetAddOnInfo = function() end, GetNumAddOns = function() return 0 end, IsAddOnLoaded = function() return false end }
BreakUpLargeNumbers = tostring
RAID_CLASS_COLORS = {}
UnitClass = function() return "Druid", "DRUID" end
local HUB = {}
function HUB:RegisterEvent() return true end
function HUB:Call(_, fn, ...) return fn(...) end
function HUB:Print() end
function HUB:AddSlashCommand() end
function HUB:OnSettingChanged() end
for _, f in ipairs({ "Core.lua", "Widgets.lua", "Version.lua", "Releases.lua", "Registry.lua", "Capture.lua", "Window.lua", "Report.lua", "Errors.lua" }) do
  local chunk, e = loadfile(f); assert(chunk, e)
  local ok, err = pcall(chunk, "AllemanoHub", HUB)
  if not ok then print("load " .. f .. ": " .. tostring(err)) end
end
HUB.db = { settings = { errorsView = "all" }, log = {
  { sig = "a", t = 100, last = 200, count = 5, folder = "Plater", name = "Plater", where = "Core.lua:1", msg = "boom\nline2", stack = "s1\ns2", locals = "x = 1", v = "1.0", session = 1 },
  { sig = "b", t = 150, last = 250, count = 1, folder = "Hush", name = "Hush", where = "Chat.lua:9", msg = "oops", v = "0.1.35", session = 1 },
}, captured = {} }
HUB.Theme = HUB.Theme or HUB.W and nil
local page = HUB.Window.pages.errors
assert(page and page.Build, "no errors page")
local p = page.Build(mock("Frame"))
p:Refresh()
assert(#HUB.Registry:AllErrors() == 2, "all errors")
assert(HUB.Registry:AllErrors()[1].count == 1 and HUB.Registry:AllErrors()[2].count == 5, "order and counts")
HUB.db.settings.errorsView = "allemano"
p:Refresh()
print("errors page builds and refreshes in both views")
local W = HUB.W
local items = {}
for i = 1, 60 do items[i] = { text = "Sound " .. i, checked = i == 40, onClick = function() end } end
local anchor = mock("Frame")
W.OpenMenu(items, anchor)
W.OpenMenu({ { text = "a" }, { text = "b" } }, anchor)
print("long and short menus open")
print("ALL OK")
