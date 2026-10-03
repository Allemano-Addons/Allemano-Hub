-- Registry: which Allemano addons exist, which are installed, and how to open them.
-- No cooperation from the other addons is needed: installed state and version come from the
-- game's addon list, and "open" runs the addon's own slash command. An addon that declares
-- `## X-Allemano-Id` in its TOC is picked up too, even if it is not in the built-in list.
local _, HUB = ...

local Registry = {}
HUB.Registry = Registry

Registry.URL = {
    discord = "https://discord.gg/BvFrTKUAst",
    site = "https://allemano.org",
    curseforge = "https://www.curseforge.com/projects/",
}

-- id, folder, name, label (the small caps line), color, main slash command, how to open its settings
-- (arg to the slash command), CurseForge project id, mark (file in Media/marks), SavedVariables name of
-- the addon's error list, one line about it. `main` = shown in the sidebar and on the overview;
-- the other Hush modules (`module = "hush"`) get their own place on Hush's page later.
Registry.known = {
    { id = "hush", key = "HUSH", folder = "Hush", name = "Hush", label = "COMMUNICATION", color = "3FD0E0", mark = "hush", main = true,
      slash = "/hush", settings = "settings", cf = 1719062, sv = "HushDB",
      blurb = "Whisper messenger with popups, saved messages and alt chats" },
    { id = "altboard", key = "ALTBOARD", folder = "AltBoard", name = "AltBoard", label = "CHARACTERS", color = "5B8CFF", mark = "altboard", main = true,
      slash = "/ab", settings = "settings", cf = 1719158, sv = "AltBoardDB",
      blurb = "All your characters on one board" },
    { id = "art", key = "ALLEMANORAIDTOOLS", folder = "AllemanoRaidTools", name = "ART", fullName = "Allemano Raid Tools", label = "RAID TOOLS", color = "E5484D", mark = "art", main = true,
      slash = "/art", cf = 1719141, sv = "AllemanoRaidToolsDB",
      blurb = "Notes, raid check, invites, marks and timers for raids" },
    { id = "session-tracker", key = "ALLEMANOLEDGER", folder = "AllemanoLedger", name = "Ledger", fullName = "Allemano Ledger", label = "UTILITY", color = "E8A93B", mark = "session", main = true,
      slash = "/ledger", settings = "settings", cf = 1719167, sv = "AllemanoLedgerDB",
      blurb = "Gold by source, history, lifetime totals, XP and level times" },
    { id = "craftboard", key = "CRAFTBOARD", folder = "CraftBoard", name = "CraftBoard", label = "PROFESSIONS", color = "F0763A", mark = "craftboard", main = true,
      slash = "/cb", settings = "settings", cf = 1719025, sv = "CraftBoardDB",
      blurb = "Who in your guild can craft what" },
    { id = "alc", key = "ALC", folder = "ArbiterLootCouncil", name = "ALC", fullName = "Arbiter Loot Council", label = "LOOT COUNCIL", color = "45C97E", mark = "alc", main = true,
      slash = "/alc", settings = "settings", cf = 1719135,
      blurb = "Loot council: responses, voting and awards" },
    { id = "asr", key = "ASR", folder = "ArbiterSoftReserve", name = "ASR", fullName = "Arbiter Soft Reserve", label = "SOFT RESERVE", color = "9B7BFF", mark = "asr", main = true,
      slash = "/asr", openArg = "results", cf = 1721476, sv = "ASR_DB",
      blurb = "Soft reserve for Arbiter Loot Council: import your list, roll once, hand out everything" },
    { id = "skins", key = "ALLEMANOSKINS", folder = "AllemanoSkins", name = "Skins", label = "SKINS", color = "E55D9E", mark = "skins", main = true, soon = true,
      slash = "/askins",
      blurb = "Gives other addons the Allemano look" },
    { id = "hush-feed", key = "HUSHFEED", folder = "Hush_Feed", name = "Hush Feed", label = "COMMUNICATION", color = "3FD0E0", mark = "hush", module = "hush",
      slash = "/feed", settings = "options", cf = 1719071,
      blurb = "Trade, General and LFG chat sorted into feeds" },
    { id = "hush-lfg", key = "HUSHLFG", folder = "Hush_LFG", name = "Hush LFG", label = "COMMUNICATION", color = "3FD0E0", mark = "hush", module = "hush",
      slash = "/hlfg", settings = "options", cf = 1719074,
      blurb = "Groups and players from chat and the Group Finder" },
    { id = "hush-recruit", key = "HUSHRECRUIT", folder = "Hush_Recruit", name = "Hush Recruit", label = "COMMUNICATION", color = "3FD0E0", mark = "hush", module = "hush",
      slash = "/hr", settings = "options", cf = 1719076,
      blurb = "Guild recruitment ads, apply link and candidates" },
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

-- Fills in installed / loaded / version / update for one entry.
local function inspect(entry)
    local name = safe(getInfo, entry.folder)
    entry.installed = name ~= nil and name ~= ""
    entry.loaded = entry.installed and safe(isLoaded, entry.folder) and true or false
    entry.version = entry.installed and safe(getMeta, entry.folder, "Version") or nil
    local release = HUB.releases and HUB.releases[entry.id]
    entry.latest = release and release.version
    local seen = HUB.Guild and HUB.Guild:Newest(entry.id)
    if seen and (not entry.latest or HUB.Version.Compare(entry.latest, seen) < 0) then
        entry.latest, entry.latestFromGuild = seen, true
    end
    entry.update = entry.installed and entry.version and entry.latest
        and HUB.Version.Compare(entry.version, entry.latest) < 0 or false
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
                id = safe(getMeta, folder, "X-Allemano-Id"), folder = folder, main = true,
                name = safe(getMeta, folder, "Title") or folder, label = "ADDON", mark = nil,
                color = safe(getMeta, folder, "X-Allemano-Color") or "B57EDC",
                slash = safe(getMeta, folder, "X-Allemano-Slash"),
                blurb = safe(getMeta, folder, "Notes") or "",
            })
        end
    end
    return list
end

function Registry:Main()
    local out = {}
    for _, e in ipairs(self:List()) do if e.main then out[#out + 1] = e end end
    return out
end

-- Addons (modules included) with a newer version in the release list than the one installed.
function Registry:Updates()
    local out = {}
    for _, e in ipairs(self:List()) do if e.update then out[#out + 1] = e end end
    return out
end

-- How many errors the addons have recorded (each keeps its last ten in its SavedVariables).
function Registry:ErrorCount()
    local n = 0
    for _, k in ipairs(self.known) do
        local db = k.sv and _G[k.sv]
        if type(db) == "table" and type(db.errors) == "table" then n = n + #db.errors end
    end
    if HUB.errors then n = n + #HUB.errors end
    for _, list in pairs(HUB.db and HUB.db.captured or {}) do n = n + #list end
    return n
end

-- Every recorded error of every addon (each keeps its last ten in its SavedVariables), newest first:
-- { addon = <registry entry>, t, where, msg, v }.
local HUB_ENTRY = { id = "hub", name = "Allemano Hub", color = "ECEDEF" }

function Registry:Errors()
    local out = {}
    local function add(addon, list)
        for _, e in ipairs(list) do
            out[#out + 1] = { addon = addon, t = tonumber(e.t) or 0, where = tostring(e.where or "?"), msg = tostring(e.msg or ""), v = e.v }
        end
    end
    for _, k in ipairs(self.known) do
        local db = k.sv and _G[k.sv]
        if type(db) == "table" and type(db.errors) == "table" then add(k, db.errors) end
        local caught = HUB.db and HUB.db.captured and HUB.db.captured[k.folder]
        if caught then add(k, caught) end
    end
    if HUB.errors then add(HUB_ENTRY, HUB.errors) end
    table.sort(out, function(a, b) return a.t > b.t end)
    return out
end

-- Every error of every addon (the "All addons" view), newest first. Same errors are grouped with a count:
-- { addon = { id, name, color }, t (last time), first, count, where, msg, stack, locals, v, session, key }.
function Registry:AllErrors()
    local out = {}
    for _, e in ipairs(HUB.db and HUB.db.log or {}) do
        local addon
        for _, k in ipairs(self.known) do
            if e.folder and strlower(k.folder) == strlower(e.folder) then addon = k end
        end
        addon = addon or { id = "x:" .. tostring(e.folder or "game"), name = e.name or e.folder or "Game or unknown", color = "9098A1" }
        out[#out + 1] = {
            addon = addon, t = tonumber(e.last) or 0, first = tonumber(e.t) or 0, count = e.count or 1,
            where = tostring(e.where or "?"), msg = tostring(e.msg or ""), stack = e.stack, locals = e.locals,
            v = e.v, session = e.session, key = e.sig,
        }
    end
    table.sort(out, function(a, b) return a.t > b.t end)
    return out
end

-- Errors that came in since the Errors page was last looked at (the number on the launcher button).
function Registry:UnseenErrors()
    local seen = HUB.db and tonumber(HUB.db.errorsSeen) or 0
    local n = 0
    for _, e in ipairs(self:Errors()) do
        if e.t > seen then n = n + 1 end
    end
    return n
end

function Registry:MarkErrorsSeen()
    if HUB.db then HUB.db.errorsSeen = time() end
end

-- Empties every addon's error list (they hold the same table, so wiping it clears them all).
function Registry:ClearErrors()
    for _, k in ipairs(self.known) do
        local db = k.sv and _G[k.sv]
        if type(db) == "table" and type(db.errors) == "table" then wipe(db.errors) end
    end
    if HUB.errors then wipe(HUB.errors) end
    if HUB.db and HUB.db.captured then wipe(HUB.db.captured) end
    if HUB.db and HUB.db.log then wipe(HUB.db.log) end
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

-- Runs an addon's own slash command: its SlashCmdList entry by name, else whichever entry owns the slash text.
function Registry:Run(entry, arg)
    local fn = entry.key and SlashCmdList[entry.key]
    if type(fn) ~= "function" then fn = entry.slash and slashHandler(entry.slash) end
    if type(fn) ~= "function" then
        HUB:Print((entry.name or "That addon") .. " did not answer " .. tostring(entry.slash) .. ".")
        return false
    end
    HUB:Call("run " .. tostring(entry.slash), fn, arg or "")
    return true
end

function Registry:Open(entry) return self:Run(entry, entry.openArg or "") end
function Registry:OpenSettings(entry) return entry.settings and self:Run(entry, entry.settings) end

function Registry:CurseForgeURL(entry) return entry.cf and (self.URL.curseforge .. entry.cf) or nil end
