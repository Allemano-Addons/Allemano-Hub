-- Capture: catches Lua errors, including errors outside protected calls (button scripts, timers) and in
-- addons that keep no error list of their own (ALC, the Hush modules).
--
-- Two records are kept:
--  * AllemanoHubDB.captured[folder]: the errors of Allemano addons (the Errors page's default view).
--    Errors an addon already recorded itself are not repeated.
--  * AllemanoHubDB.log: every error of every addon, grouped (the same error again only counts up) with
--    the stack, newest first, at most LOG_KEEP kinds of error. This is the Errors page's "All addons" view.
-- The first line of the message or stack that is not a bundled library decides whose error it is.
local _, HUB = ...

local Registry = HUB.Registry

local KEEP = 20
local LOG_KEEP = 150
local MSG_MAX, STACK_MAX, LOCALS_MAX = 600, 1200, 800
local STORM_LIMIT = 25 -- new kinds of error stored per second; above that only the counts go up
local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

HUB.Capture = {}
local Capture = HUB.Capture

local pending = {} -- caught before the saved data was loaded
local announced = {}
local busy = false

local function entryByFolder(folder)
    local lower = strlower(folder)
    for _, k in ipairs(Registry.known) do
        if strlower(k.folder) == lower then return k end
    end
end

-- Is this path (inside an addon folder) a bundled library? An error that goes through a library such as
-- AceAddon is usually the fault of whoever called it, and several addons share one copy of the library,
-- so the library's folder says nothing about the culprit.
local function isLibrary(path)
    local lower = strlower(path)
    if lower:find("^libs?[\\/]") or lower:find("[\\/]libs?[\\/]") or lower:find("^libraries[\\/]")
        or lower:find("[\\/]libraries[\\/]") or lower:find("^embeds?[\\/]") then
        return true
    end
    local file = lower:match("([^\\/]*)$") or lower
    return (file:find("^ace%w*%-") or file:find("^libstub") or file:find("^callbackhandler")
        or file:find("^chatthrottlelib")) ~= nil
end

local PATH = "[Aa][Dd][Dd][Oo][Nn][Ss][\\/]+([^\\/:]+)[\\/]+([^\n]*)"

-- folder, rest-of-line for the addon that really raised the error (any addon, not only ours), or nil
-- when there is no addon path at all. The first path that is not a library, in the message and then in
-- the stack, is the culprit. When only library paths are there, the addon whose copy of the library it
-- was gets the blame (third value true).
local function culprit(text, stack)
    local fallback
    for _, source in ipairs({ text, stack or "" }) do
        for folder, rest in tostring(source):gmatch(PATH) do
            local path = rest:match("^([^:\n]*)") or rest
            if isLibrary(path) then
                fallback = fallback or { folder = folder, rest = rest }
            else
                return folder, rest
            end
        end
    end
    if fallback then return fallback.folder, fallback.rest, true end
end

local function whereOf(rest)
    local where = rest:match("^(.-:%d+)") or rest:match("^([^\n]*)")
    return where and where:gsub("^.*[\\/]", ""):sub(1, 80) or "?"
end

-- ---------------------------------------------------------------------------
-- A sound when an error is caught (Errors page: on/off and which one). The game's own
-- sounds, and the ones other addons registered with LibSharedMedia (the list BugSack uses).
-- Sound files inside addon folders are not loaded on WoW Forever.
-- ---------------------------------------------------------------------------

Capture.SOUNDS = {
    { key = "failed", label = "Quest failed", name = "IG_QUEST_FAILED", id = 847 },
    { key = "raid", label = "Raid warning", name = "RAID_WARNING", id = 8959 },
    { key = "ready", label = "Ready check", name = "READY_CHECK", id = 8960 },
    { key = "whisper", label = "Whisper", name = "TELL_MESSAGE", id = 3081 },
    { key = "alarm", label = "Alarm clock", name = "ALARM_CLOCK_WARNING_3", id = 12867 },
}

-- Sounds other addons registered with LibSharedMedia: the choices are stored as "lsm:<name>".
local function sharedMedia() return LibStub and LibStub("LibSharedMedia-3.0", true) end

-- { { key, label }, ... }: the game's own sounds first, then the shared ones by name.
function Capture.SoundList()
    local out = {}
    for _, s in ipairs(Capture.SOUNDS) do out[#out + 1] = { key = s.key, label = s.label } end
    local lsm = sharedMedia()
    if lsm and lsm.List then
        local names = {}
        for _, name in ipairs(lsm:List("sound") or {}) do
            if name ~= "None" then names[#names + 1] = name end
        end
        sort(names)
        for _, name in ipairs(names) do out[#out + 1] = { key = "lsm:" .. name, label = name } end
    end
    return out
end

function Capture.PlaySound(key)
    key = tostring(key or "")
    local name = key:match("^lsm:(.+)$")
    if name then
        local lsm = sharedMedia()
        local path = lsm and lsm.Fetch and lsm:Fetch("sound", name, true)
        if path and PlaySoundFile then return pcall(PlaySoundFile, path, "Master") end
        key = "" -- the addon that registered it is gone: the default sound
    end
    local choice = Capture.SOUNDS[1]
    for _, s in ipairs(Capture.SOUNDS) do if s.key == key then choice = s end end
    local id = (type(SOUNDKIT) == "table" and SOUNDKIT[choice.name]) or choice.id
    if PlaySound then return pcall(PlaySound, id, "Master") end
end

local lastSound, lastHead = -1000, nil
local function clock() return GetTime and GetTime() or time() end

-- At most one sound every three seconds, and the same error does not ring again for a minute.
function Capture.Alert(text)
    local settings = HUB.db and HUB.db.settings
    if settings and settings.errorSound == false then return end
    local now = clock()
    local head = tostring(text or ""):sub(1, 120)
    if now - lastSound < 3 or (head == lastHead and now - lastSound < 60) then return end
    lastSound, lastHead = now, head
    Capture.PlaySound(settings and settings.errorSoundKit)
end

-- ---------------------------------------------------------------------------
-- The Allemano record
-- ---------------------------------------------------------------------------

local function alreadyHas(list, msg, now)
    if type(list) ~= "table" then return false end
    local head = msg:sub(1, 200)
    for i = #list, 1, -1 do
        local e = list[i]
        if type(e) == "table" and (tonumber(e.t) or 0) >= now - 5 and tostring(e.msg or ""):sub(1, 200) == head then
            return true
        end
    end
    return false
end

local function store(entry, where, msg, now)
    local db = HUB.db
    db.captured = db.captured or {}
    local list = db.captured[entry.folder]
    if not list then list = {} db.captured[entry.folder] = list end
    if alreadyHas(list, msg, now) then return end
    -- The addon may have recorded this error itself a moment ago.
    local own = entry.sv and _G[entry.sv]
    if type(own) == "table" and alreadyHas(own.errors, msg, now) then return end
    list[#list + 1] = {
        t = now, where = where, msg = msg:sub(1, 400),
        v = getMeta and getMeta(entry.folder, "Version") or nil,
    }
    while #list > KEEP do tremove(list, 1) end
    if not announced[entry.folder] then
        announced[entry.folder] = true
        HUB:Print("|cffe8a33d" .. (entry.name or entry.folder) .. " hit an error|r (" .. where .. "). Allemano Hub > Errors shows it.")
    end
end

-- ---------------------------------------------------------------------------
-- The record of every error
-- ---------------------------------------------------------------------------

local stormSecond, stormCount = 0, 0

local function titleOf(folder)
    local title = getMeta and folder and getMeta(folder, "Title")
    if type(title) == "string" and title ~= "" then
        return (title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
end

-- Stores one kind of error once; the same again (same addon, place and message) only counts up.
local function log(folder, entry, where, text, stack, locals, now)
    local db = HUB.db
    db.log = db.log or {}
    local list = db.log
    local sig = (folder or "?") .. "|" .. where .. "|" .. text:sub(1, 200)
    for i = #list, 1, -1 do
        local e = list[i]
        if e.sig == sig then
            e.count, e.last = (e.count or 1) + 1, now
            return
        end
    end
    if now == stormSecond then stormCount = stormCount + 1 else stormSecond, stormCount = now, 1 end
    if stormCount > STORM_LIMIT then return end -- an error storm: do not fill the memory
    list[#list + 1] = {
        sig = sig, t = now, last = now, count = 1, folder = folder,
        name = entry and (entry.name or entry.folder) or titleOf(folder) or folder or "Game or unknown",
        where = where, msg = text:sub(1, MSG_MAX),
        stack = stack and tostring(stack):sub(1, STACK_MAX) or nil,
        locals = locals and tostring(locals):sub(1, LOCALS_MAX) or nil,
        v = folder and getMeta and getMeta(folder, "Version") or nil,
        session = HUB.session,
    }
    while #list > LOG_KEEP do
        local oldest = 1
        for i = 2, #list do if (list[i].last or 0) < (list[oldest].last or 0) then oldest = i end end
        tremove(list, oldest)
    end
end

local function process(text, stack, locals, now, live)
    local folder, rest = culprit(text, stack)
    local entry = folder and entryByFolder(folder)
    local where = rest and whereOf(rest) or text:match("^[^\n]*"):sub(1, 60)
    log(folder, entry, where, text, stack, locals, now)
    if entry then store(entry, where, text, now) end
    if live and (entry or (HUB.db.settings and HUB.db.settings.errorsView == "all")) then Capture.Alert(text) end
end

local function catch(text, stack, locals)
    if busy then return end
    busy = true
    local ok = pcall(function()
        text = tostring(text or "")
        if HUB.db then
            process(text, stack, locals, time(), true)
        elseif #pending < 50 then
            pending[#pending + 1] = { text = text, stack = stack, locals = locals, t = time() }
        end
    end)
    busy = false
    -- Any error may have changed the list (also the addons' own records), so an open window follows along.
    if C_Timer and C_Timer.After and HUB.Window then
        C_Timer.After(0, function()
            pcall(HUB.Window.Refresh, HUB.Window)
            if HUB.UpdateLauncher then pcall(HUB.UpdateLauncher) end
        end)
    end
    return ok
end
Capture.Catch = catch

HUB:RegisterEvent("ADDON_LOADED", function(_, name)
    if name ~= HUB.name then return end
    HUB.db.sessions = (HUB.db.sessions or 0) + 1
    HUB.session = HUB.db.sessions
    for _, p in ipairs(pending) do process(p.text, p.stack, p.locals, p.t, false) end
    wipe(pending)
end)

-- ---------------------------------------------------------------------------
-- Hooking in. BugGrabber (BugSack) tells us about every error when it is installed; otherwise
-- the error handler is wrapped and put back in place if another addon replaces it.
-- ---------------------------------------------------------------------------

local previous
local function handler(msg)
    local okStack, stack = pcall(function() return debugstack and debugstack(2) end)
    local okLocals, locals = pcall(function() return debuglocals and debuglocals(2) end)
    catch(msg, okStack and stack or nil, okLocals and locals or nil)
    if previous then return previous(msg) end
end

local function wrap()
    local current = geterrorhandler and geterrorhandler()
    if current == handler then return end
    previous = current
    seterrorhandler(handler)
end

-- BugGrabber takes over seterrorhandler (it becomes a no-op), so wrapping does not work next to it.
-- It announces every error on EventRegistry with the error's id; GetErrorByID turns that into the error.
local bugGrabber = _G.BugGrabber
if type(bugGrabber) == "table" and type(bugGrabber.GetErrorByID) == "function"
    and EventRegistry and type(EventRegistry.RegisterCallback) == "function" then
    local owner = {}
    local ok = pcall(EventRegistry.RegisterCallback, EventRegistry, "BugGrabber.BugGrabbed", function(_, tableID)
        local okGet, errorObject = pcall(bugGrabber.GetErrorByID, bugGrabber, tableID)
        if okGet and type(errorObject) == "table" then
            catch(errorObject.message, errorObject.stack, errorObject.locals)
        end
    end, owner)
    if ok then Capture.mode = "BugGrabber" end
end

if not Capture.mode then
    Capture.mode = "handler"
    HUB:RegisterEvent("PLAYER_LOGIN", function()
        wrap()
        if C_Timer and C_Timer.After then C_Timer.After(5, wrap) end
    end)
    HUB:RegisterEvent("PLAYER_ENTERING_WORLD", wrap)
end
