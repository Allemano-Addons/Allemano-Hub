-- Guild: which guild members run which Allemano addons (and which version), shared with small addon
-- messages between Hubs (prefix "AllemanoHub"). Only addon names and versions are sent, only to your
-- own guild, and it can be turned off.
--
--   V|hubVersion|i|n|id:version,id:version,...   my addons (chunk i of n), GUILD at login or WHISPER as an answer
--   Q                                            "tell me yours" (GUILD)
--
-- Received: AllemanoHubDB.guild[fullName] = { t = time, hub = version, addons = { id = version } }
local _, HUB = ...

local Registry, Version = HUB.Registry, HUB.Version

local Guild = {}
HUB.Guild = Guild

local PREFIX = "AllemanoHub"
local MAX_BYTES = 240
local ASK_COOLDOWN = 60
local MAX_AGE = 60 * 60 * 24 * 60 -- members not heard from for 60 days are dropped

local me
local roster = {} -- full name -> { online, class, rank }

local function settings() return HUB.db.settings end
local function sharing() return settings().shareAddons ~= false end

-- ---------------------------------------------------------------------------
-- Roster
-- ---------------------------------------------------------------------------

function Guild:RefreshRoster()
    wipe(roster)
    if not IsInGuild() or not GetNumGuildMembers then return end
    for i = 1, (GetNumGuildMembers()) do
        local name, rank, _, _, _, _, _, _, online, _, classFile = GetGuildRosterInfo(i)
        if name then roster[name] = { online = online and true or false, class = classFile, rank = rank } end
    end
end

function Guild:RosterInfo(name) return roster[name] end

local function normalize(sender)
    if type(Ambiguate) == "function" then
        local ok, name = pcall(Ambiguate, sender, "none")
        if ok and name then return name end
    end
    return sender
end

local rosterAt = 0
local function inGuild(name)
    if time() - rosterAt > 30 then
        rosterAt = time()
        Guild:RefreshRoster()
    end
    return roster[name] ~= nil
end

-- ---------------------------------------------------------------------------
-- What I send
-- ---------------------------------------------------------------------------

local function myAddons()
    local list = {}
    for _, e in ipairs(Registry:List()) do
        if e.installed and e.version then list[#list + 1] = e.id .. ":" .. e.version end
    end
    return list
end

-- Messages for my addon list (usually one).
function Guild.BuildMessages()
    local items = myAddons()
    local head = "V|" .. tostring(HUB.version) .. "|"
    local chunks, current, size = {}, {}, 0
    for _, item in ipairs(items) do
        if size + #item + 1 > MAX_BYTES - #head - 8 and #current > 0 then
            chunks[#chunks + 1] = table.concat(current, ",")
            current, size = {}, 0
        end
        current[#current + 1] = item
        size = size + #item + 1
    end
    chunks[#chunks + 1] = table.concat(current, ",")
    local out = {}
    for i, chunk in ipairs(chunks) do out[#out + 1] = ("%s%d|%d|%s"):format(head, i, #chunks, chunk) end
    return out
end

local function send(channel, target, text)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, channel, target)
    end
end

local function announce(channel, target)
    if not sharing() then return end
    for i, text in ipairs(Guild.BuildMessages()) do
        C_Timer.After((i - 1) * 0.4, function() send(channel, target, text) end)
    end
end

-- Ask the guild (and tell it what I have). force skips the cooldown.
function Guild.Ask(force)
    if not IsInGuild() then return false end
    local now = time()
    if not force and Guild.lastAsk and now - Guild.lastAsk < ASK_COOLDOWN then return false end
    Guild.lastAsk = now
    announce("GUILD")
    send("GUILD", nil, "Q")
    return true
end

-- ---------------------------------------------------------------------------
-- What I receive
-- ---------------------------------------------------------------------------

local pending = {} -- sender -> { hub, n, got, parts }

local function commit(sender, hub, parts)
    local addons = {}
    for _, part in ipairs(parts) do
        for id, version in part:gmatch("([%w%-]+):([%w%.%-]+)") do
            if #id <= 24 and #version <= 24 then addons[id] = version end
        end
    end
    HUB.db.guild[sender] = { t = time(), hub = hub, addons = addons }
    if HUB.Window and HUB.Window.Refresh then HUB.Window:Refresh() end
end

local handlers = {}

function handlers.V(sender, _, hub, i, n, list)
    i, n = tonumber(i), tonumber(n)
    if not (i and n and n >= 1 and n <= 10 and i >= 1 and i <= n) then return end
    hub = tostring(hub or ""):sub(1, 24)
    local p = pending[sender]
    if not p or p.n ~= n then
        p = { n = n, got = 0, parts = {} }
        pending[sender] = p
    end
    if not p.parts[i] then
        p.parts[i] = list or ""
        p.got = p.got + 1
    end
    if p.got >= p.n then
        pending[sender] = nil
        commit(sender, hub, p.parts)
    end
end

function handlers.Q(sender)
    if not sharing() then return end
    C_Timer.After(0.5 + math.random() * 5, function() announce("WHISPER", sender) end)
end

function Guild.Receive(text, channel, sender, allowAny)
    if type(text) ~= "string" or #text > 255 then return end
    sender = normalize(sender or "")
    if sender == "" or (sender == me and not allowAny) then return end
    if not allowAny and not inGuild(sender) then return end
    local fields = { strsplit("|", text) }
    local handler = handlers[fields[1]]
    if handler then handler(sender, channel, unpack(fields, 2)) end
end

HUB:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, text, channel, sender)
    if prefix ~= PREFIX or not HUB.db then return end
    Guild.Receive(text, channel, sender)
end)

-- ---------------------------------------------------------------------------
-- Reading it
-- ---------------------------------------------------------------------------

-- The rows of the Guild page: me first, then members sorted online first, then by name.
function Guild:Members()
    self:RefreshRoster()
    local out = {}
    local mine = {}
    for _, e in ipairs(Registry:List()) do if e.installed and e.version then mine[e.id] = e.version end end
    out[1] = { name = me or "You", me = true, online = true, addons = mine, hub = HUB.version,
        class = select(2, UnitClass("player")), t = time() }
    for name, rec in pairs(HUB.db.guild) do
        if name ~= me then
            local info = roster[name]
            out[#out + 1] = { name = name, online = info and info.online or false, class = info and info.class,
                rank = info and info.rank, addons = rec.addons or {}, hub = rec.hub, t = rec.t or 0, left = not info }
        end
    end
    table.sort(out, function(a, b)
        if a.me ~= b.me then return a.me end
        if a.online ~= b.online then return a.online end
        return a.name < b.name
    end)
    return out
end

-- The newest version of an addon seen on a guild member (nil if nobody has it).
function Guild:Newest(id)
    local best
    for name, rec in pairs(HUB.db.guild or {}) do
        local v = name ~= me and rec.addons and rec.addons[id]
        if v and (not best or Version.Compare(best, v) < 0) then best = v end
    end
    return best
end

function Guild:Count()
    local members, online = 0, 0
    self:RefreshRoster()
    for name in pairs(HUB.db.guild) do
        if name ~= me then
            members = members + 1
            if roster[name] and roster[name].online then online = online + 1 end
        end
    end
    return members, online
end

-- ---------------------------------------------------------------------------
-- Session
-- ---------------------------------------------------------------------------

local function checkGuild()
    local name = GetGuildInfo and GetGuildInfo("player")
    if not name then return end
    if HUB.db.guildName and HUB.db.guildName ~= name then
        wipe(HUB.db.guild)
        HUB:Print("New guild: cleared the addon lists collected from the old one.")
    end
    HUB.db.guildName = name
    -- forget members nobody has heard from in a long time
    local now = time()
    for member, rec in pairs(HUB.db.guild) do
        if now - (rec.t or 0) > MAX_AGE then HUB.db.guild[member] = nil end
    end
end

HUB:RegisterEvent("PLAYER_LOGIN", function()
    me = HUB:PlayerFullName()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end
    C_Timer.After(15, function() -- the guild roster and the other addons are ready by now
        HUB:Call("guild hello", function()
            checkGuild()
            Guild.Ask(true)
        end)
    end)
end)

HUB:AddSlashCommand("sync", function()
    if Guild.Ask(true) then HUB:Print("Asked the guild which Allemano addons they have.") else HUB:Print("You are not in a guild.") end
end, "ask the guild which Allemano addons they have")

-- /allemano selftest: run a fake member through the message code, as if "Test Peer" had sent it.
HUB:AddSlashCommand("selftest", function(arg)
    if strlower(arg or "") == "clear" then
        HUB.db.guild["Test Peer"] = nil
        HUB:Print("Test Peer removed.")
        return
    end
    for _, text in ipairs(Guild.BuildMessages()) do Guild.Receive(text, "WHISPER", "Test Peer", true) end
    local rec = HUB.db.guild["Test Peer"]
    if rec then
        rec.addons["craftboard"] = "9.9.9" -- something newer than anyone has
        HUB:Print("Test Peer added with your addon list (CraftBoard 9.9.9). /allemano selftest clear removes it.")
    end
    if HUB.Window and HUB.Window.Refresh then HUB.Window:Refresh() end
end, "add a fake guild member built from your own addon list")
