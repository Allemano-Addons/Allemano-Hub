-- Allemano Hub: core namespace, event dispatcher, SavedVariables and slash command.
-- Optional: every Allemano addon works without it. The Hub only looks at what is installed.
local addonName, HUB = ...

HUB.name = addonName
HUB.SCHEMA = 1
HUB.COLOR = "ECEDEF" -- the plain Allemano white (the brand mark)

function HUB:Print(...)
    local msg = strjoin(" ", tostringall(...))
    DEFAULT_CHAT_FRAME:AddMessage("|cffecedefAllemano Hub|r " .. msg)
end

-- ---------------------------------------------------------------------------
-- Errors: WoW Forever does not show Lua errors, so they are kept (last 10, also in
-- AllemanoHubDB.errors), announced once per session and listed by /allemano errors.
-- ---------------------------------------------------------------------------

HUB.errors = {}
local announced = false

function HUB:RecordError(where, err)
    local list = self.errors
    list[#list + 1] = { t = time(), where = tostring(where), msg = tostring(err):sub(1, 400), v = self.version }
    while #list > 10 do tremove(list, 1) end
    if not announced then
        announced = true
        self:Print("|cffe8a33dhit an error|r (" .. tostring(where) .. "). /allemano errors shows it.")
    end
    geterrorhandler()(err)
end

-- Full character name: on WoW Forever UnitName returns the first name and the surname separately.
function HUB:PlayerFullName()
    local first, second = UnitName("player")
    if second and second ~= "" then return first .. (CHARACTER_SURNAME_SEPARATOR or " ") .. second end
    return first or "Unknown"
end

-- Run fn protected; errors are recorded instead of lost.
function HUB:Call(where, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then self:RecordError(where, err) end
    return ok
end

-- ---------------------------------------------------------------------------
-- Game events: several handlers per event, one shared frame. Each handler runs
-- protected so one failing part never stops the others.
-- ---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

-- Returns false if the client does not know the event.
function HUB:RegisterEvent(event, handler)
    local list = eventHandlers[event]
    if not list then
        if not pcall(eventFrame.RegisterEvent, eventFrame, event) then return false end
        list = {}
        eventHandlers[event] = list
    end
    list[#list + 1] = handler
    return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = eventHandlers[event]
    if not list then return end
    local snapshot = { unpack(list, 1, #list) }
    for i = 1, #snapshot do
        local ok, err = pcall(snapshot[i], event, ...)
        if not ok then HUB:RecordError(event, err) end
    end
end)

-- ---------------------------------------------------------------------------
-- SavedVariables: read at ADDON_LOADED, never at file load (WoW Forever quirk).
-- ---------------------------------------------------------------------------

HUB.DEFAULTS = {
    font = "Auto", textSize = "M", accentMode = "own", accent = "ECEDEF",
    scale = 1, bgAlpha = 0.97, launcher = true, launcherLocked = false, shareAddons = true,
}

-- Settings changes apply at once: listeners get (key, value).
local settingListeners = {}

function HUB:OnSettingChanged(fn) settingListeners[#settingListeners + 1] = fn end

function HUB:SetSetting(key, value)
    self.db.settings[key] = value
    for _, fn in ipairs(settingListeners) do self:Call("setting " .. key, fn, key, value) end
end

local function initDB()
    if type(AllemanoHubDB) ~= "table" then AllemanoHubDB = {} end
    local db = AllemanoHubDB
    db.schema = db.schema or HUB.SCHEMA
    db.settings = db.settings or {}
    for k, v in pairs(HUB.DEFAULTS) do
        if db.settings[k] == nil then db.settings[k] = v end
    end
    db.guild = db.guild or {}
    -- Errors from before the saved data was loaded are kept too.
    db.errors = db.errors or {}
    for _, e in ipairs(HUB.errors) do tinsert(db.errors, e) end
    while #db.errors > 10 do tremove(db.errors, 1) end
    HUB.errors = db.errors
    HUB.db = db
end

local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

HUB:RegisterEvent("ADDON_LOADED", function(_, name)
    if name ~= addonName then return end
    initDB()
    HUB.version = getMetadata and getMetadata(addonName, "Version") or "?"
end)

HUB:RegisterEvent("PLAYER_LOGIN", function()
    HUB.guid = UnitGUID("player")
    HUB.ready = true
end)

-- ---------------------------------------------------------------------------
-- Slash command: other files add subcommands with HUB:AddSlashCommand.
-- ---------------------------------------------------------------------------

local slashCommands, slashOrder = {}, {}

function HUB:AddSlashCommand(name, fn, help)
    if not slashCommands[name] then slashOrder[#slashOrder + 1] = name end
    slashCommands[name] = { fn = fn, help = help }
end

HUB:AddSlashCommand("version", function() HUB:Print("v" .. tostring(HUB.version)) end, "show version")

HUB:AddSlashCommand("errors", function(arg)
    if strlower(arg or "") == "clear" then
        wipe(HUB.errors)
        HUB:Print("Error list cleared.")
        return
    end
    if #HUB.errors == 0 then HUB:Print("No errors recorded.") return end
    for _, e in ipairs(HUB.errors) do
        HUB:Print(("[%s] %s (v%s): %s"):format(date("%d/%m %H:%M", e.t), e.where, tostring(e.v), e.msg))
    end
end, "show recent errors (/allemano errors clear empties the list)")

SLASH_ALLEMANOHUB1 = "/allemano"
SLASH_ALLEMANOHUB2 = "/ah"
SlashCmdList.ALLEMANOHUB = function(msg)
    msg = strtrim(msg or "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = strlower(cmd or "")
    if cmd == "" and slashCommands.open then cmd = "open" end
    local c = slashCommands[cmd]
    if c then
        local ok, err = pcall(c.fn, rest)
        if not ok then HUB:RecordError("/allemano " .. cmd, err) end
    else
        HUB:Print("Allemano Hub v" .. tostring(HUB.version) .. " (/allemano opens it)")
        for _, name in ipairs(slashOrder) do
            HUB:Print(("/allemano %s - %s"):format(name, slashCommands[name].help or ""))
        end
    end
end
