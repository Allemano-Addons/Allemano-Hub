-- Capture: catches Lua errors raised in any Allemano addon, including addons that keep no error list
-- of their own (ALC, the Hush modules) and errors outside their protected calls (button scripts, timers).
-- The folder named in the error's file path decides which addon it belongs to. Errors an addon already
-- recorded itself are not repeated. Kept in AllemanoHubDB.captured[folder], shown on the Errors page.
local _, HUB = ...

local Registry = HUB.Registry

local KEEP = 20
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

-- { folder entry, "File.lua:123" } for the first Allemano addon path in the text, or nil.
local function locate(text)
    for folder, rest in text:gmatch("[Aa][Dd][Dd][Oo][Nn][Ss][\\/]+([^\\/:]+)[\\/]+([^\n]*)") do
        local entry = entryByFolder(folder)
        if entry then
            local where = rest:match("^(.-:%d+)") or rest:match("^([^\n]*)")
            return entry, where and where:gsub("^.*[\\/]", ""):sub(1, 80) or "?"
        end
    end
end

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

local function catch(text, stack)
    if busy then return end
    busy = true
    local ok = pcall(function()
        text = tostring(text or "")
        local entry, where = locate(text)
        if not entry and stack then entry, where = locate(tostring(stack)) end
        if not entry then return end
        if HUB.db then
            store(entry, where, text, time())
        elseif #pending < 50 then
            pending[#pending + 1] = { entry = entry, where = where, msg = text, t = time() }
        end
    end)
    busy = false
    -- Any error may have changed the list (also the addons' own records), so an open window follows along.
    if C_Timer and C_Timer.After and HUB.Window then
        C_Timer.After(0, function() pcall(HUB.Window.Refresh, HUB.Window) end)
    end
    return ok
end
Capture.Catch = catch

HUB:RegisterEvent("ADDON_LOADED", function(_, name)
    if name ~= HUB.name then return end
    for _, p in ipairs(pending) do store(p.entry, p.where, p.msg, p.t) end
    wipe(pending)
end)

-- ---------------------------------------------------------------------------
-- Hooking in. BugGrabber (BugSack) tells us about every error when it is installed; otherwise
-- the error handler is wrapped and put back in place if another addon replaces it.
-- ---------------------------------------------------------------------------

local previous
local function handler(msg)
    catch(msg)
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
            catch(errorObject.message, errorObject.stack)
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
