-- Registry: which Allemano addons exist, which are installed, and how to open them.
-- No cooperation from the other addons is needed: installed state and version come from the
-- game's addon list, and "open" runs the addon's own slash command. An addon that declares
-- `## X-Allemano-Id` in its TOC is picked up too, even if it is not in the built-in list.
local _, HUB = ...

local Registry = {}
HUB.Registry = Registry

Registry.URL = {
    discord = "https://discord.gg/BvFrTKUAst",
    site = "https://allemano-site.pages.dev",
    curseforge = "https://www.curseforge.com/projects/",
}

-- id, folder, name, color, main slash command, how to open its settings (arg to the slash command),
-- CurseForge project id, one line about it.
Registry.known = {
    { id = "hush", folder = "Hush", name = "Hush", color = "3FD0E0", slash = "/hush", settings = "settings", cf = 1719062,
      blurb = "Whisper messenger with popups, saved messages and alt chats" },
    { id = "hush-feed", folder = "Hush_Feed", name = "Hush Feed", color = "3FD0E0", slash = "/feed", settings = "options", cf = 1719071,
      blurb = "Trade, General and LFG chat sorted into feeds", needs = { "Hush" } },
    { id = "hush-lfg", folder = "Hush_LFG", name = "Hush LFG", color = "3FD0E0", slash = "/hlfg", settings = "options", cf = 1719074,
      blurb = "Groups and players from chat and the Group Finder", needs = { "Hush", "Hush_Feed" } },
    { id = "hush-recruit", folder = "Hush_Recruit", name = "Hush Recruit", color = "3FD0E0", slash = "/hr", settings = "options", cf = 1719076,
      blurb = "Guild recruitment ads, apply link and candidates", needs = { "Hush" } },
    { id = "altboard", folder = "AltBoard", name = "AltBoard", color = "5B8CFF", slash = "/ab", settings = "settings", cf = 1719158,
      blurb = "All your characters on one board" },
    { id = "craftboard", folder = "CraftBoard", name = "CraftBoard", color = "F0763A", slash = "/cb", settings = "settings", cf = 1719025,
      blurb = "Who in your guild can craft what" },
    { id = "art", folder = "AllemanoRaidTools", name = "Allemano Raid Tools", color = "E5484D", slash = "/art", cf = 1719141,
      blurb = "Notes, raid check, invites, marks and timers for raids" },
    { id = "alc", folder = "ArbiterLootCouncil", name = "Arbiter Loot Council", color = "45C97E", slash = "/alc", settings = "settings", cf = 1719135,
      blurb = "Loot council: responses, voting and awards" },
    { id = "session-tracker", folder = "SessionTracker", name = "Session Tracker", color = "E8A93B", slash = "/session", settings = "settings", cf = 1719167,
      blurb = "Gold, XP and time for this session, and level times" },
}

local api = C_AddOns or {}
local getInfo = api.GetAddOnInfo or GetAddOnInfo
local getMeta = api.GetAddOnMetadata or GetAddOnMetadata
local isLoaded = api.IsAddOnLoaded or IsAddOnLoaded
local numAddOns = api.GetNumAddOns or GetNumAddOns

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

-- Fills in installed / loaded / version for one entry.
local function inspect(entry)
    local name = safe(getInfo, entry.folder)
    entry.installed = name ~= nil and name ~= ""
    entry.loaded = entry.installed and safe(isLoaded, entry.folder) and true or false
    entry.version = entry.installed and safe(getMeta, entry.folder, "Version") or nil
    return entry
end

-- All Allemano addons: the built-in ones first (in list order), then any others that declare
-- `## X-Allemano-Id`. Returns fresh tables each time, so state is always current.
function Registry:List()
    local list, seen = {}, {}
    for _, k in ipairs(self.known) do
        local e = {}
        for key, v in pairs(k) do e[key] = v end
        list[#list + 1] = inspect(e)
        seen[k.folder] = true
    end
    for i = 1, (safe(numAddOns) or 0) do
        local folder = safe(getInfo, i)
        if folder and not seen[folder] and safe(getMeta, folder, "X-Allemano-Id") then
            list[#list + 1] = inspect({
                id = safe(getMeta, folder, "X-Allemano-Id"), folder = folder,
                name = safe(getMeta, folder, "Title") or folder,
                color = safe(getMeta, folder, "X-Allemano-Color") or "B57EDC",
                slash = safe(getMeta, folder, "X-Allemano-Slash"),
                blurb = safe(getMeta, folder, "Notes") or "",
            })
        end
    end
    return list
end

-- Runs a slash command by looking up which SlashCmdList entry owns it (no need to know its name).
local function slashHandler(slash)
    for k, v in pairs(_G) do
        if type(k) == "string" and v == slash and k:match("^SLASH_.+%d+$") then
            local key = k:gsub("^SLASH_", ""):gsub("%d+$", "")
            if type(SlashCmdList[key]) == "function" then return SlashCmdList[key] end
        end
    end
end

function Registry:Run(slash, arg)
    local fn = slash and slashHandler(slash)
    if not fn then return false end
    HUB:Call("run " .. slash, fn, arg or "")
    return true
end

function Registry:Open(entry) return self:Run(entry.slash, "") end
function Registry:OpenSettings(entry) return entry.settings and self:Run(entry.slash, entry.settings) end

function Registry:CurseForgeURL(entry) return entry.cf and (self.URL.curseforge .. entry.cf) or nil end
